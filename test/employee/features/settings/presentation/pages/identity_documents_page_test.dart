import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/models/identity_document_error.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_documents_page.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_photo_tile.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/employee/features/settings/services/identity_photo_picker.dart';
import 'package:koala/product/constants/app_info.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_document_fixtures.dart';
import '../../../../../support/keyboard.dart';

final CurrentUser _user = CurrentUser.fromJson(const {
  'id': 'user-1',
  'firstName': 'Çağrı',
  'lastName': 'Kaya',
  'email': 'cagri@ornek.com',
  'birthDate': '1998-04-07',
  'isEmployer': false,
});

/// Kamera ve galeri yerine diskteki hazır dosyaları veren seçici.
class _FakePicker extends IdentityPhotoPicker {
  _FakePicker(this.photos);

  final Map<IdentityPhotoSlot, IdentityPhotoCandidate?> photos;
  final List<(IdentityPhotoSlot, IdentityPhotoSource)> calls = [];

  @override
  Future<IdentityPhotoCandidate?> pick(
    IdentityPhotoSlot slot,
    IdentityPhotoSource source,
  ) async {
    calls.add((slot, source));
    return photos[slot];
  }
}

class _Harness {
  _Harness({
    required this.api,
    required this.router,
    required this.picker,
    required this.reviews,
    required this.users,
  });

  final FakeApi api;
  final GoRouter router;
  final _FakePicker picker;
  final IdentityReviewProvider reviews;
  final UserProvider users;

  /// Sayfanın `pop` sonucu; kapanmadıysa `null` kalır.
  bool? popped;
  bool didPop = false;
}

void main() {
  /// Sunucu: inceleme ucuna [review], gönderime [submit], `/users/me`'ye
  /// kullanıcı. [review] `null` ise henüz belge yok (`404`).
  FakeApi serverWith({
    FakeApiResponse? review,
    FakeApiResponse? submit,
    FakeApiResponse Function()? reviewBuilder,
  }) {
    return FakeApi(
      handler: (options) {
        if (options.path == '/users/me/identity-documents') {
          if (options.method == 'POST') {
            return submit ??
                identityReviewResponse(status: 'PENDING', statusCode: 201);
          }
          return reviewBuilder?.call() ?? review ?? noIdentityReviewResponse;
        }
        if (options.path == '/users/me') {
          return FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': _user.toJson()},
          );
        }
        return const FakeApiResponse(statusCode: 200, body: {'success': true});
      },
    );
  }

  Future<_Harness> pumpPage(
    WidgetTester tester,
    FakeApi api, {
    Brightness brightness = Brightness.light,
    Map<IdentityPhotoSlot, IdentityPhotoCandidate?>? photos,
    CurrentUser? user,
  }) async {
    final picker = _FakePicker(photos ?? writeIdentityPhotoCandidates());
    final reviews = IdentityReviewProvider(
      service: IdentityDocumentService.withClient(api.client),
    );
    final users = UserProvider(userService: UserService.withClient(api.client));

    late final _Harness harness;
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Text('profil ekranı')),
        ),
        GoRoute(
          path: '/identity-documents',
          builder: (context, state) => IdentityDocumentsPage(
            user: user ?? _user,
            service: IdentityDocumentService.withClient(api.client),
            picker: picker,
          ),
        ),
      ],
    );
    harness = _Harness(
      api: api,
      router: router,
      picker: picker,
      reviews: reviews,
      users: users,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<IdentityReviewProvider>.value(value: reviews),
          ChangeNotifierProvider<UserProvider>.value(value: users),
        ],
        child: MaterialApp.router(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          routerConfig: router,
        ),
      ),
    );

    unawaited(
      router.push<bool>('/identity-documents').then((result) {
        harness.popped = result;
        harness.didPop = true;
      }),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  Finder textFieldLabeled(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField("$label")',
  );

  Finder tileOf(IdentityPhotoSlot slot) =>
      find.byKey(ValueKey('identity-photo-${slot.name}'));

  Finder inTile(IdentityPhotoSlot slot, String text) =>
      find.descendant(of: tileOf(slot), matching: find.text(text));

  /// Kareyi seçer: satırdaki "Fotoğraf Ekle" → kaynak sayfası → kaynak.
  Future<void> addPhoto(
    WidgetTester tester,
    IdentityPhotoSlot slot, {
    String source = 'Kamerayla Çek',
  }) async {
    await tester.ensureVisible(inTile(slot, 'Fotoğraf Ekle'));
    await tester.tap(inTile(slot, 'Fotoğraf Ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(source));
    await tester.pumpAndSettle();
  }

  Future<void> fillDeclaration(WidgetTester tester) async {
    await tester.enterText(textFieldLabeled('TC Kimlik No'), '12345678950');
    await tester.enterText(textFieldLabeled('Seri No'), 'A01B23456');
    await tester.pump();
  }

  Future<void> addAllPhotos(WidgetTester tester) async {
    for (final slot in IdentityPhotoSlot.values) {
      await addPhoto(tester, slot);
    }
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('İncelemeye Gönder'));
    await tester.pumpAndSettle();
  }

  RequestOptions submittedRequest(FakeApi api) => api.requests.singleWhere(
    (request) =>
        request.path == '/users/me/identity-documents' &&
        request.method == 'POST',
  );

  group('form', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada dört kare rehberiyle çiziliyor', (
        tester,
      ) async {
        await pumpPage(tester, serverWith(), brightness: brightness);

        expect(tester.takeException(), isNull);
        expect(find.text('Fotoğrafla Doğrulama'), findsOneWidget);
        for (final (index, slot) in IdentityPhotoSlot.values.indexed) {
          expect(
            inTile(slot, '${index + 1}. ${slot.title}'),
            findsOneWidget,
            reason: slot.name,
          );
          expect(inTile(slot, slot.guide), findsOneWidget, reason: slot.name);
          expect(
            inTile(slot, 'Fotoğraf Ekle'),
            findsOneWidget,
            reason: slot.name,
          );
        }
        expect(find.text('Fotoğraflar (0/4)'), findsOneWidget);
      });
    }

    testWidgets('ad, soyad ve doğum tarihi kayıttan dolu geliyor', (
      tester,
    ) async {
      await pumpPage(tester, serverWith());

      expect(
        tester.widget<TextField>(textFieldLabeled('Ad')).controller?.text,
        'Çağrı',
      );
      expect(
        tester.widget<TextField>(textFieldLabeled('Soyad')).controller?.text,
        'Kaya',
      );
      expect(find.text('07.04.1998'), findsOneWidget);
    });

    testWidgets('gönder düğmesi dört kare ve beyan tamamlanana kadar kapalı', (
      tester,
    ) async {
      await pumpPage(tester, serverWith());

      ElevatedButton submitButton() => tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('İncelemeye Gönder'),
          matching: find.byType(ElevatedButton),
        ),
      );

      expect(submitButton().onPressed, isNull);
      await fillDeclaration(tester);
      expect(submitButton().onPressed, isNull, reason: 'kare yok');

      for (final slot in IdentityPhotoSlot.values.take(3)) {
        await addPhoto(tester, slot);
      }
      expect(submitButton().onPressed, isNull, reason: 'üç kare yetmez');

      await addPhoto(tester, IdentityPhotoSlot.together);
      expect(submitButton().onPressed, isNotNull);
      expect(find.text('Fotoğraflar (4/4)'), findsOneWidget);
    });

    testWidgets(
      'seçilen kare önizlemeyle değiştir/kaldır düğmelerine dönüyor',
      (tester) async {
        final harness = await pumpPage(tester, serverWith());

        await addPhoto(tester, IdentityPhotoSlot.front);

        expect(harness.picker.calls, [
          (IdentityPhotoSlot.front, IdentityPhotoSource.camera),
        ]);
        expect(inTile(IdentityPhotoSlot.front, 'Değiştir'), findsOneWidget);
        expect(inTile(IdentityPhotoSlot.front, 'Kaldır'), findsOneWidget);
        expect(inTile(IdentityPhotoSlot.front, 'Fotoğraf Ekle'), findsNothing);
        expect(
          find.descendant(
            of: tileOf(IdentityPhotoSlot.front),
            matching: find.byType(Image),
          ),
          findsOneWidget,
        );

        await tester.tap(inTile(IdentityPhotoSlot.front, 'Kaldır'));
        await tester.pumpAndSettle();
        expect(
          inTile(IdentityPhotoSlot.front, 'Fotoğraf Ekle'),
          findsOneWidget,
        );
      },
    );

    testWidgets('galeri seçeneği seçiciye galeri kaynağını iletiyor', (
      tester,
    ) async {
      final harness = await pumpPage(tester, serverWith());

      await addPhoto(tester, IdentityPhotoSlot.selfie, source: 'Galeriden Seç');

      expect(harness.picker.calls, [
        (IdentityPhotoSlot.selfie, IdentityPhotoSource.gallery),
      ]);
    });

    testWidgets('kaynak sayfası karenin kadraj rehberini yazıyor', (
      tester,
    ) async {
      await pumpPage(tester, serverWith());

      await tester.ensureVisible(
        inTile(IdentityPhotoSlot.front, 'Fotoğraf Ekle'),
      );
      await tester.tap(inTile(IdentityPhotoSlot.front, 'Fotoğraf Ekle'));
      await tester.pumpAndSettle();

      // Rehber hem satırda hem sayfada: satırdaki bir, sayfadaki iki.
      expect(find.text(IdentityPhotoSlot.front.guide), findsNWidgets(2));
      expect(find.text('Kamerayla Çek'), findsOneWidget);
      expect(find.text('Galeriden Seç'), findsOneWidget);
    });

    testWidgets('önizlemeye dokunmak kareyi tam boy açıyor', (tester) async {
      await pumpPage(tester, serverWith());
      await addPhoto(tester, IdentityPhotoSlot.back);

      final preview = find.descendant(
        of: tileOf(IdentityPhotoSlot.back),
        matching: find.byType(Image),
      );
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });

  group('istemci sınırları', () {
    testWidgets('gerçek HEIC baytları kendi uyarısıyla reddediliyor, kare boş '
        'kalıyor', (tester) async {
      final heic = writeIdentityPhotoCandidates(
        extension: 'heic',
        content: heicSignatureBytes,
      );
      await pumpPage(tester, serverWith(), photos: heic);

      await addPhoto(tester, IdentityPhotoSlot.front);

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(IdentityPhotoRejection.heic.message),
        ),
        findsOneWidget,
      );
      expect(inTile(IdentityPhotoSlot.front, 'Fotoğraf Ekle'), findsOneWidget);
      expect(find.text('Fotoğraflar (0/4)'), findsOneWidget);
    });

    testWidgets('.heic adlı JPEG kabul ediliyor ve JPEG olarak gidiyor', (
      tester,
    ) async {
      // Android galerisinden HEIC seçilince seçici JPEG'e çeviriyor ama adı
      // bırakıyor; sunucu uzantıya baktığı için parça adı gerçek içerikten.
      final api = serverWith();
      await pumpPage(
        tester,
        api,
        photos: writeIdentityPhotoCandidates(
          extension: 'heic',
          content: jpegSignatureBytes,
        ),
      );
      await fillDeclaration(tester);
      await addAllPhotos(tester);
      expect(find.text('Fotoğraflar (4/4)'), findsOneWidget);

      await submit(tester);

      final form = submittedRequest(api).data as FormData;
      for (final slot in IdentityPhotoSlot.values) {
        final part = form.files
            .singleWhere((entry) => entry.key == slot.fieldName)
            .value;
        expect(part.filename, '${slot.fieldName}.jpg', reason: slot.name);
        expect(part.contentType?.mimeType, 'image/jpeg', reason: slot.name);
      }
    });

    testWidgets('10 MB üstü kare reddediliyor', (tester) async {
      final photos = writeIdentityPhotoCandidates();
      final big = photos[IdentityPhotoSlot.front]!;
      await pumpPage(
        tester,
        serverWith(),
        photos: {
          ...photos,
          IdentityPhotoSlot.front: IdentityPhotoCandidate(
            slot: big.slot,
            path: big.path,
            bytes: IdentityPhotoPolicy.maxPhotoBytes + 1,
            head: big.head,
          ),
        },
      );

      await addPhoto(tester, IdentityPhotoSlot.front);

      expect(
        find.text(IdentityPhotoRejection.tooLarge.message),
        findsOneWidget,
      );
      expect(inTile(IdentityPhotoSlot.front, 'Fotoğraf Ekle'), findsOneWidget);
    });

    testWidgets('dört tam boy kare toplam sınırının tam üstünde kabul', (
      tester,
    ) async {
      // Dosya başına 10 MiB × dört kare = 40 MiB, toplam sınırın kendisi.
      // Sınır aşımı ancak sabitler ayrışırsa mümkün; aşımın kendisi
      // `IdentityPhotoPolicy.checkTotal` biriminde ölçülüyor.
      final photos = writeIdentityPhotoCandidates();
      await pumpPage(
        tester,
        serverWith(),
        photos: {
          for (final entry in photos.entries)
            entry.key: IdentityPhotoCandidate(
              slot: entry.key,
              path: entry.value.path,
              bytes: IdentityPhotoPolicy.maxPhotoBytes,
              head: entry.value.head,
            ),
        },
      );

      await addAllPhotos(tester);

      expect(find.text('Fotoğraflar (4/4)'), findsOneWidget);
    });

    testWidgets('gif gibi tanınmayan içerik reddediliyor', (tester) async {
      await pumpPage(
        tester,
        serverWith(),
        photos: writeIdentityPhotoCandidates(
          extension: 'jpg',
          content: 'GIF89a'.codeUnits,
        ),
      );

      await addPhoto(tester, IdentityPhotoSlot.selfie);

      expect(
        find.text(IdentityPhotoRejection.unsupportedType.message),
        findsOneWidget,
      );
    });
  });

  group('gönderim', () {
    testWidgets('dört kare ve beyan tek multipart istekte gidiyor, ekran '
        'beklemeye geçiyor', (tester) async {
      final api = serverWith();
      final harness = await pumpPage(tester, api);

      await fillDeclaration(tester);
      await addAllPhotos(tester);
      await submit(tester);

      final request = submittedRequest(api);
      expect(request.contentType, startsWith('multipart/form-data'));
      final form = request.data as FormData;
      final parts = {for (final part in form.files) part.key: part.value};
      expect(
        parts.keys,
        containsAll([
          'identity',
          ...IdentityPhotoSlot.values.map((s) => s.fieldName),
        ]),
      );
      expect(parts, hasLength(5));
      final identityBytes = await parts['identity']!
          .clone()
          .finalize()
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      final identity =
          jsonDecode(utf8.decode(identityBytes)) as Map<String, dynamic>;
      expect(identity['firstName'], 'Çağrı');
      expect(identity['lastName'], 'Kaya');
      expect(identity['birthDate'], '1998-04-07');
      expect(identity['tcIdentityNumber'], '12345678950');
      expect(identity['tcDocumentNumber'], 'A01B23456');
      for (final slot in IdentityPhotoSlot.values) {
        // Fixture PNG: ad ve tip içerikten, dosyanın `.jpg` adından değil.
        expect(parts[slot.fieldName]!.filename, '${slot.fieldName}.png');
        expect(parts[slot.fieldName]!.contentType?.mimeType, 'image/png');
      }

      expect(find.text('Belgelerin inceleniyor'), findsOneWidget);
      expect(find.textContaining('1 iş günü'), findsOneWidget);
      expect(find.text('Durumu Yenile'), findsOneWidget);
      expect(harness.reviews.review?.isPending, isTrue);
      // Kimlik henüz doğrulanmadı: ekran `true` ile kapanmıyor.
      expect(harness.didPop, isFalse);
    });

    testWidgets('gönderim sürerken ilerleme çiziliyor ve düğmeler kapalı', (
      tester,
    ) async {
      final gate = Completer<void>();
      final api = FakeApi(
        handler: (options) async {
          if (options.path == '/users/me/identity-documents' &&
              options.method == 'POST') {
            await gate.future;
            return identityReviewResponse(status: 'PENDING', statusCode: 201);
          }
          return noIdentityReviewResponse;
        },
      );
      await pumpPage(tester, api);
      await fillDeclaration(tester);
      await addAllPhotos(tester);

      await tester.tap(find.text('İncelemeye Gönder'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Fotoğraflar gönderiliyor'), findsOneWidget);
      expect(
        find.text('Gönderiliyor'),
        findsNothing,
        reason: 'yükleme dönüyor',
      );
      final tile = tester.widget<IdentityPhotoTile>(
        tileOf(IdentityPhotoSlot.front),
      );
      expect(tile.enabled, isFalse);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Belgelerin inceleniyor'), findsOneWidget);
    });

    testWidgets('bekleyen görünümden Tamam false ile kapatıyor', (
      tester,
    ) async {
      final harness = await pumpPage(tester, serverWith());
      await fillDeclaration(tester);
      await addAllPhotos(tester);
      await submit(tester);

      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();

      expect(harness.didPop, isTrue);
      expect(harness.popped, isFalse);
      expect(find.text('profil ekranı'), findsOneWidget);
    });
  });

  group('sunucu reddi', () {
    Future<_Harness> submitAgainst(
      WidgetTester tester,
      FakeApiResponse response, {
      FakeApiResponse Function()? reviewBuilder,
    }) async {
      final harness = await pumpPage(
        tester,
        serverWith(submit: response, reviewBuilder: reviewBuilder),
      );
      await fillDeclaration(tester);
      await addAllPhotos(tester);
      await submit(tester);
      return harness;
    }

    testWidgets('413: boyut mesajı formun üstünde, kareler yerinde', (
      tester,
    ) async {
      await submitAgainst(
        tester,
        const FakeApiResponse(
          statusCode: 413,
          body: {
            'success': false,
            'message': 'İstek gövdesi izin verilen boyutu aşıyor.',
            'errorCode': 'REQUEST_BODY_TOO_LARGE',
            'errorCategory': 'REQUEST_MALFORMED',
          },
        ),
      );

      expect(
        find.text(IdentityDocumentError.requestTooLarge.message),
        findsOneWidget,
      );
      expect(find.text('Fotoğraflar (4/4)'), findsOneWidget);
      expect(find.text('İncelemeye Gönder'), findsOneWidget);
    });

    testWidgets(
      '400 bekleyen inceleme: durum yeniden okunup bekleme çiziliyor',
      (tester) async {
        var calls = 0;
        await submitAgainst(
          tester,
          const FakeApiResponse(
            statusCode: 400,
            body: {
              'success': false,
              'message': 'Bekleyen bir TCKK incelemeniz var.',
              'errorCode': 'IDENTITY_DOCUMENTS_ALREADY_PENDING',
              'errorCategory': 'VALIDATION_FAILED',
            },
          ),
          // İlk okuma "yok" (form açılsın), reddin ardından sunucu bekleyen
          // incelemeyi gösteriyor: başka bir cihazdan gönderilmiş.
          reviewBuilder: () => calls++ == 0
              ? noIdentityReviewResponse
              : identityReviewResponse(status: 'PENDING'),
        );

        expect(find.text('Belgelerin inceleniyor'), findsOneWidget);
        expect(
          find.text(IdentityDocumentError.alreadyPending.message),
          findsOneWidget,
        );
      },
    );

    testWidgets('409 kimlik numarası başka hesapta: destek adresiyle', (
      tester,
    ) async {
      await submitAgainst(
        tester,
        const FakeApiResponse(
          statusCode: 409,
          body: {
            'success': false,
            'message': 'Bu kimlik numarası başka bir hesapta kayıtlı.',
            'errorCode': 'TC_IDENTITY_NUMBER_ALREADY_IN_USE',
            'errorCategory': 'DATA_CONFLICT',
          },
        ),
      );

      expect(
        find.text(IdentityDocumentError.numberAlreadyInUse.message),
        findsOneWidget,
      );
      expect(find.textContaining(AppInfo.supportEmail), findsOneWidget);
    });

    testWidgets(
      '400 zaten doğrulanmış: kullanıcı tazelenip true ile kapanıyor',
      (tester) async {
        final harness = await submitAgainst(
          tester,
          const FakeApiResponse(
            statusCode: 400,
            body: {
              'success': false,
              'message': 'Kimliğiniz zaten doğrulanmış.',
              'errorCode': 'USER_ALREADY_IDENTITY_VERIFIED',
              'errorCategory': 'VALIDATION_FAILED',
            },
          ),
        );

        expect(harness.popped, isTrue);
        expect(
          harness.api.requests.where((r) => r.path == '/users/me'),
          isNotEmpty,
        );
      },
    );

    testWidgets('tanınmayan kodda sunucunun metni gösteriliyor', (
      tester,
    ) async {
      await submitAgainst(
        tester,
        const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'sunucunun kendi metni',
            'errorCode': 'SOMETHING_NEW',
            'errorCategory': 'VALIDATION_FAILED',
          },
        ),
      );

      expect(find.text('sunucunun kendi metni'), findsOneWidget);
      expect(find.text('İncelemeye Gönder'), findsOneWidget);
    });
  });

  group('açılıştaki durum', () {
    testWidgets('bekleyen inceleme: form yerine bekleme görünümü', (
      tester,
    ) async {
      await pumpPage(
        tester,
        serverWith(review: identityReviewResponse(status: 'PENDING')),
      );

      expect(find.text('Belgelerin inceleniyor'), findsOneWidget);
      expect(find.textContaining('Gönderim'), findsOneWidget);
      expect(find.text('İncelemeye Gönder'), findsNothing);
      expect(textFieldLabeled('TC Kimlik No'), findsNothing);
    });

    testWidgets('reddedilen inceleme: gerekçe ve yeniden yükleme formu', (
      tester,
    ) async {
      await pumpPage(
        tester,
        serverWith(
          review: identityReviewResponse(
            status: 'REJECTED',
            rejectionReason: 'Arka yüz bulanık',
            rejectedAt: '2026-09-13T12:00:00Z',
          ),
        ),
      );

      expect(find.text('Belgelerin reddedildi'), findsOneWidget);
      expect(find.text('Personel gerekçesi: Arka yüz bulanık'), findsOneWidget);
      expect(find.textContaining('Karar:'), findsOneWidget);
      expect(find.text('İncelemeye Gönder'), findsOneWidget);
      expect(textFieldLabeled('TC Kimlik No'), findsOneWidget);
    });

    testWidgets('gerekçesiz red de yeniden yüklemeye açık', (tester) async {
      await pumpPage(
        tester,
        serverWith(review: identityReviewResponse(status: 'REJECTED')),
      );

      expect(find.text('Belgelerin reddedildi'), findsOneWidget);
      expect(find.textContaining('gerekçe yazmadı'), findsOneWidget);
      expect(find.text('İncelemeye Gönder'), findsOneWidget);
    });

    testWidgets('onaylı inceleme: Profile Dön kullanıcıyı tazeleyip true '
        'ile kapatıyor', (tester) async {
      final harness = await pumpPage(
        tester,
        serverWith(review: identityReviewResponse(status: 'APPROVED')),
      );

      expect(find.text('Kimliğin doğrulandı'), findsOneWidget);
      await tester.tap(find.text('Profile Dön'));
      await tester.pumpAndSettle();

      expect(harness.popped, isTrue);
      expect(
        harness.api.requests.where((r) => r.path == '/users/me'),
        isNotEmpty,
      );
    });

    testWidgets('zaten doğrulanmış kullanıcı incelemeye bakmadan onaylı', (
      tester,
    ) async {
      await pumpPage(
        tester,
        serverWith(),
        user: CurrentUser.fromJson({
          ..._user.toJson(),
          'identityVerified': true,
        }),
      );

      expect(find.text('Kimliğin doğrulandı'), findsOneWidget);
    });

    testWidgets('durum okunamazsa tekrar dene ekranı', (tester) async {
      var fail = true;
      await pumpPage(
        tester,
        serverWith(
          reviewBuilder: () => fail
              ? const FakeApiResponse.connectionError()
              : noIdentityReviewResponse,
        ),
      );

      expect(find.text('İnceleme durumu alınamadı'), findsOneWidget);
      expect(find.text('İncelemeye Gönder'), findsNothing);

      fail = false;
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('İncelemeye Gönder'), findsOneWidget);
    });

    testWidgets('Durumu Yenile onayı görünce onay görünümüne geçiyor', (
      tester,
    ) async {
      var status = 'PENDING';
      await pumpPage(
        tester,
        serverWith(reviewBuilder: () => identityReviewResponse(status: status)),
      );
      expect(find.text('Belgelerin inceleniyor'), findsOneWidget);

      status = 'APPROVED';
      await tester.tap(find.text('Durumu Yenile'));
      await tester.pumpAndSettle();

      expect(find.text('Kimliğin doğrulandı'), findsOneWidget);
    });

    testWidgets('Durumu Yenile reddi görünce formu gerekçeyle açıyor', (
      tester,
    ) async {
      var response = identityReviewResponse(status: 'PENDING');
      await pumpPage(tester, serverWith(reviewBuilder: () => response));

      response = identityReviewResponse(
        status: 'REJECTED',
        rejectionReason: 'Yüz karede değil',
      );
      await tester.tap(find.text('Durumu Yenile'));
      await tester.pumpAndSettle();

      expect(find.text('Personel gerekçesi: Yüz karede değil'), findsOneWidget);
      expect(find.text('İncelemeye Gönder'), findsOneWidget);
    });
  });

  group('durum geçişleri (IdentityStatus)', () {
    testWidgets('gönderimden sonra provider bekliyor diyor', (tester) async {
      final harness = await pumpPage(tester, serverWith());
      expect(
        harness.reviews.statusFor(identityVerified: false),
        IdentityStatus.unverified,
      );

      await fillDeclaration(tester);
      await addAllPhotos(tester);
      await submit(tester);

      expect(
        harness.reviews.statusFor(identityVerified: false),
        IdentityStatus.pending,
      );
    });
  });

  group('klavye (is-koala/koala#190)', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} tema: gönder çubuğu klavyenin üstüne çıkar, boş '
        'alana dokununca odak düşer',
        (tester) async {
          await pumpPage(tester, serverWith(), brightness: brightness);
          await showKeyboard(tester);

          await expectAboveKeyboard(tester, findBottomBarButton());
          await expectTapOutsideDropsFocus(
            tester,
            textFieldLabeled('TC Kimlik No'),
          );
        },
      );
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} tema, iOS: TC Kimlik No alanında Bitti şeridi '
        'çıkar, gönder çubuğu şeridin üstünde kalır',
        (tester) async {
          await pumpPage(tester, serverWith(), brightness: brightness);

          await expectDoneBarLayout(
            tester,
            numericField: textFieldLabeled('TC Kimlik No'),
            cta: findBottomBarButton(),
          );
          await tapDoneBar(tester);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  });
}
