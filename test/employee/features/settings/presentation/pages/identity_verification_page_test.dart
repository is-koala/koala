import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/identity_error.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_chip_page.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_verification_page.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/services/chip_reader.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/chip_fixtures.dart';
import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_document_fixtures.dart';

/// Kayıtta girilen ad-soyad ve doğum tarihi kimliktekiyle **aynı değil**:
/// çip okununca hangisinin gönderildiği buradan ayırt ediliyor. Karttaki
/// doğum tarihi 07.04.1998; kayıttaki başka bir gün, yoksa doğum tarihi
/// ayağı hiçbir şeyi kanıtlamazdı.
final CurrentUser _user = CurrentUser.fromJson(const {
  'id': 'user-1',
  'firstName': 'Cagri',
  'lastName': 'Kaya',
  'email': 'cagri@ornek.com',
  'birthDate': '1990-01-15',
  'isEmployer': false,
});

/// Çipten okunan karta göre ad **ÇAĞRI**; MRZ'de **CAGRI** yazıyor.
IdentityChipResult _chipResult({bool withChipProof = false}) {
  return buildChipResult(
    dg1: encodeDg1(line3: 'KAYA<<CAGRI<<<<<<<<<<<<<<<<<<<'),
    dg11: encodeDg11(nameOfHolder: 'KAYA<<ÇAĞRI'),
    withChipProof: withChipProof,
  );
}

/// NFC donanımı olan bir Android telefon: kimlik ekranı çip formunu çiziyor.
/// Testte yerli eklenti yok, sorulsa "yok" derdi ve ekran doğrudan fotoğraf
/// akışına geçerdi — bu dosyanın ölçtüğü çip formu hiç açılmazdı.
class _AvailableChipReader extends ChipReader {
  @override
  Future<NfcAvailability> availability() async => NfcAvailability.available;
}

/// NFC donanımı olmayan telefon.
class _UnsupportedChipReader extends ChipReader {
  @override
  Future<NfcAvailability> availability() async => NfcAvailability.unsupported;
}

/// Fotoğraf akışının yerine geçen sahne: açılışını kaydediyor ve verilen
/// sonuçla kapanıyor; `null` ise kullanıcı geri dönmüş gibi açık kalıyor.
class _DocumentsStub extends StatefulWidget {
  const _DocumentsStub({required this.result, required this.onOpened});

  final bool? Function() result;
  final VoidCallback onOpened;

  @override
  State<_DocumentsStub> createState() => _DocumentsStubState();
}

class _DocumentsStubState extends State<_DocumentsStub> {
  @override
  void initState() {
    super.initState();
    widget.onOpened();
    final result = widget.result();
    if (result != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('fotoğraf akışı'));
}

/// Çip ekranının yerine geçen sahne: açılır açılmaz verilen sonuçla (ya da
/// vazgeçmiş gibi `null` ile) kapanıyor.
class _ChipStub extends StatefulWidget {
  const _ChipStub({required this.result});

  /// Okunan kanıt, `IdentityChipHandoff.photos` ya da vazgeçme (`null`).
  final Object? result;

  @override
  State<_ChipStub> createState() => _ChipStubState();
}

class _ChipStubState extends State<_ChipStub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(widget.result);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('çip ekranı'));
}

void main() {
  /// Hiç fotoğraf gönderilmemiş: inceleme ucu `404` ile "yok" diyor.
  const noReview = FakeApiResponse(
    statusCode: 404,
    body: {
      'success': false,
      'errorCode': 'IDENTITY_DOCUMENTS_NOT_FOUND',
      'errorCategory': 'RESOURCE_NOT_FOUND',
    },
  );

  FakeApi okApi() {
    return FakeApi(
      handler: (options) {
        if (options.path == '/users/me/identity-documents') return noReview;
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

  /// Kimlik doğrulama isteğini verilen `IDENTITY_*` koduyla reddeden sunucu;
  /// geri kalan her şey (`/users/me` dahil) başarılı.
  FakeApi rejectingApi(String errorCode) {
    return FakeApi(
      handler: (options) {
        if (options.path == '/users/me/identity-documents') return noReview;
        if (options.path == '/users/me/identity-verification') {
          return FakeApiResponse(
            statusCode: 400,
            body: {
              'success': false,
              'message': 'sunucu metni',
              'errorCode': errorCode,
              'errorCategory': 'VALIDATION_FAILED',
            },
          );
        }
        return FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _user.toJson()},
        );
      },
    );
  }

  /// Kimlik ekranının açılışı ve kapanışı.
  final popResults = <bool?>[];
  var documentsOpened = 0;

  Future<GoRouter> pumpPage(
    WidgetTester tester,
    FakeApi api, {
    Brightness brightness = Brightness.light,
    IdentityChipResult? Function()? chipResult,
    Object? Function()? chipExit,
    ChipReader? chipReader,
    bool? Function()? documentsResult,
    CurrentUser? user,
  }) async {
    popResults.clear();
    documentsOpened = 0;
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Text('profil ekranı')),
        ),
        GoRoute(
          path: '/identity-verification',
          builder: (context, state) => IdentityVerificationPage(
            user: user ?? _user,
            userService: UserService.withClient(api.client),
            chipReader: chipReader ?? _AvailableChipReader(),
          ),
        ),
        GoRoute(
          path: '/identity-chip',
          builder: (context, state) => chipExit != null
              ? _ChipStub(result: chipExit())
              : _ChipStub(result: chipResult?.call()),
        ),
        GoRoute(
          path: '/identity-documents',
          builder: (context, state) => _DocumentsStub(
            result: documentsResult ?? () => null,
            onOpened: () => documentsOpened++,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>(
            create: (_) =>
                UserProvider(userService: UserService.withClient(api.client)),
          ),
          ChangeNotifierProvider<IdentityReviewProvider>(
            create: (_) => IdentityReviewProvider(
              service: IdentityDocumentService.withClient(api.client),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          routerConfig: router,
        ),
      ),
    );

    unawaited(router.push<bool>('/identity-verification').then(popResults.add));
    await tester.pumpAndSettle();
    return router;
  }

  Finder textFieldLabeled(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField("$label")',
  );

  Future<void> enterField(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    await tester.enterText(textFieldLabeled(label), value);
    await tester.pump();
  }

  Future<void> readChip(WidgetTester tester) async {
    // Metin girişi formu kaydırmış olabilir; düğme görünür değilse dokunuş
    // boşa gider.
    await tester.ensureVisible(find.text('Kartı Okut'));
    await tester.tap(find.text('Kartı Okut'));
    await tester.pumpAndSettle();
  }

  /// Gönderilen kimlik doğrulama gövdesi.
  Map<String, dynamic> verificationBody(FakeApi api) {
    final request = api.requests.firstWhere(
      (request) => request.path == '/users/me/identity-verification',
    );
    return request.data! as Map<String, dynamic>;
  }

  group('çip okunmadan', () {
    testWidgets('beş alan elle doldurulup kanıtsız gönderiliyor', (
      tester,
    ) async {
      // NFC'si olmayan cihazın yolu: beyan formu eskisi gibi çalışıyor ve
      // gövde fazladan tek bir alan bile taşımıyor.
      final api = okApi();
      await pumpPage(tester, api);

      await enterField(tester, 'Ad', 'Çağrı');
      await enterField(tester, 'TC Kimlik No', '12345678950');
      await enterField(tester, 'Seri No', 'A01B23456');
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      final body = verificationBody(api);
      expect(body['firstName'], 'Çağrı');
      expect(body['lastName'], 'Kaya');
      expect(body['tcIdentityNumber'], '12345678950');
      expect(body['tcDocumentNumber'], 'A01B23456');
      expect(body['birthDate'], '1990-01-15');
      expect(body.keys, {
        'firstName',
        'lastName',
        'birthDate',
        'tcIdentityNumber',
        'tcDocumentNumber',
      });
    });

    testWidgets('çip ekranı kanıtsız kapanınca form olduğu gibi kalıyor', (
      tester,
    ) async {
      // NFC yok, kart okunamadı ya da kullanıcı vazgeçti: hepsi `null` ile
      // dönüyor ve elle düzenleme sürüyor.
      final api = okApi();
      await pumpPage(tester, api, chipResult: () => null);

      await enterField(tester, 'TC Kimlik No', '12345678950');
      await readChip(tester);

      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      final field = tester.widget<TextField>(textFieldLabeled('TC Kimlik No'));
      expect(field.enabled, isTrue);
      expect(field.controller?.text, '12345678950');
      expect(find.text('Okumayı Kaldır'), findsNothing);
    });
  });

  group('çip okunduktan sonra', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada beş alan çipten dolu ve salt '
          'okunur', (tester) async {
        final api = okApi();
        await pumpPage(
          tester,
          api,
          brightness: brightness,
          chipResult: _chipResult,
        );

        await readChip(tester);

        expect(tester.takeException(), isNull);
        // Ad DG11'den ulusal karakterlerle; kayıttaki "Cagri" değil.
        expect(find.text('ÇAĞRI'), findsOneWidget);
        expect(find.text('KAYA'), findsOneWidget);
        expect(find.text('12345678950'), findsOneWidget);
        expect(find.text('A01B23456'), findsOneWidget);
        expect(find.text('07.04.1998'), findsOneWidget);
        // Yazılabilir bir alan kalmıyor: beş değer de kanıtın görünümü.
        for (final label in const ['Ad', 'Soyad', 'TC Kimlik No', 'Seri No']) {
          expect(textFieldLabeled(label), findsNothing, reason: label);
        }
        expect(find.textContaining('okumayı kaldır'), findsWidgets);
      });
    }

    testWidgets('doğum tarihi seçiciye açılmıyor', (tester) async {
      final api = okApi();
      await pumpPage(tester, api, chipResult: _chipResult);
      await readChip(tester);

      await tester.tap(find.text('07.04.1998'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('gönderilen beyan ekrandaki çip değerleriyle birebir aynı', (
      tester,
    ) async {
      // Kabul maddesi: kanıt varken uyuşmaz beyan üretilemez. Okumadan önce
      // elle yazılan taslak ve kayıttaki ad, gövdeye **sızmıyor**.
      final api = okApi();
      final chip = _chipResult(withChipProof: true);
      await pumpPage(tester, api, chipResult: () => chip);

      await enterField(tester, 'Ad', 'Zeynep');
      await enterField(tester, 'TC Kimlik No', '99999999990');
      await readChip(tester);

      // Ekranda görünenler:
      for (final shown in const ['ÇAĞRI', 'KAYA', '12345678950', 'A01B23456']) {
        expect(find.text(shown), findsOneWidget, reason: shown);
      }

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      final body = verificationBody(api);
      expect(body['firstName'], 'ÇAĞRI');
      expect(body['lastName'], 'KAYA');
      expect(body['tcIdentityNumber'], '12345678950');
      expect(body['tcDocumentNumber'], 'A01B23456');
      // Kayıttaki 1990-01-15 değil, karttaki tarih.
      expect(body['birthDate'], '1998-04-07');
      expect(body['sod'], chip.evidence.sod);
      expect(body['dg1'], chip.evidence.dg1);
      expect(body['dg11'], chip.evidence.dg11);
      expect(body['dg15'], chip.evidence.dg15);
      expect(body['challenge'], chip.evidence.challenge);
      expect(
        body['activeAuthenticationSignature'],
        chip.evidence.activeAuthenticationSignature,
      );
      expect(body.values, isNot(contains('Zeynep')));
      expect(body.values, isNot(contains('Cagri')));
      expect(body.values, isNot(contains('99999999990')));
      expect(body.values, isNot(contains('1990-01-15')));
    });

    testWidgets('okumayı kaldırmak kanıtı ve türetilen alanları birlikte '
        'siliyor', (tester) async {
      // Tek durum geçişi: kanıt gitti, kilitli değerler de gitti; form
      // okuma öncesindeki taslağa dönüyor ve gövde kanıtsız gidiyor.
      final api = okApi();
      await pumpPage(tester, api, chipResult: _chipResult);
      await readChip(tester);

      await tester.ensureVisible(find.text('Okumayı Kaldır'));
      await tester.tap(find.text('Okumayı Kaldır'));
      await tester.pumpAndSettle();

      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      expect(find.text('ÇAĞRI'), findsNothing);
      expect(find.text('A01B23456'), findsNothing);
      for (final label in const ['Ad', 'Soyad', 'TC Kimlik No', 'Seri No']) {
        expect(
          tester.widget<TextField>(textFieldLabeled(label)).enabled,
          isTrue,
          reason: label,
        );
      }

      await enterField(tester, 'TC Kimlik No', '12345678950');
      await enterField(tester, 'Seri No', 'B02C34567');
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      final body = verificationBody(api);
      expect(body['firstName'], 'Cagri');
      expect(body['tcDocumentNumber'], 'B02C34567');
      expect(body.containsKey('sod'), isFalse);
      expect(body.containsKey('dg1'), isFalse);
      expect(body.containsKey('dg11'), isFalse);
    });

    testWidgets('yeniden okutmadan vazgeçilirse eldeki kanıt duruyor', (
      tester,
    ) async {
      // Geçerli bir okumayı, ikinci denemeden vazgeçildi diye atmak
      // kullanıcıya kartı boşuna yeniden okutmak olurdu.
      final api = okApi();
      var reads = 0;
      await pumpPage(
        tester,
        api,
        chipResult: () => reads++ == 0 ? _chipResult() : null,
      );
      await readChip(tester);

      await tester.ensureVisible(find.text('Yeniden Oku'));
      await tester.tap(find.text('Yeniden Oku'));
      await tester.pumpAndSettle();

      expect(find.text('ÇAĞRI'), findsOneWidget);
      expect(textFieldLabeled('Ad'), findsNothing);
    });

    testWidgets('sunucu challenge\'ı geçersiz sayınca kanıt bırakılıyor ve '
        'sebebi söyleniyor', (tester) async {
      // Elle düzenlemeye dönüşün kullanıcı eylemi olmayan tek yolu. Süresi
      // dolmuş tek kullanımlık sayıyla imzalanan kanıt bir daha kabul
      // edilmeyecek; kartı "doğrulandı" diye göstermeye devam etmek, sunucunun
      // az önce reddettiği kanıtı ekranda tutmak olurdu. Kanıtla birlikte
      // ondan türeyen beş alan da gidiyor ve kullanıcı neden baştan
      // okutacağını toast'tan öğreniyor.
      final api = rejectingApi(IdentityError.challengeInvalid.code);
      await pumpPage(tester, api, chipResult: () => _chipResult());
      await readChip(tester);

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(IdentityError.challengeInvalid.message),
        ),
        findsOneWidget,
      );
      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      expect(find.text('Okumayı Kaldır'), findsNothing);
      expect(find.text('ÇAĞRI'), findsNothing);
      expect(find.text('A01B23456'), findsNothing);
      // Okuma öncesindeki taslak olduğu gibi geri geliyor.
      final field = tester.widget<TextField>(textFieldLabeled('Ad'));
      expect(field.enabled, isTrue);
      expect(field.controller?.text, 'Cagri');
    });

    testWidgets('challenge dışındaki bir ret kanıtı yerinde bırakıyor', (
      tester,
    ) async {
      // Bozuk imza ya da tanınmayan makam kanıtı geçersiz kılmıyor; kullanıcı
      // metindeki yönlendirmeye göre yeniden okutur ya da desteğe yazar.
      // Kanıtı her hatada atmak, kartı boşuna yeniden okutmak olurdu.
      final api = rejectingApi(IdentityError.signatureInvalid.code);
      await pumpPage(tester, api, chipResult: () => _chipResult());
      await readChip(tester);

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(IdentityError.signatureInvalid.message),
        ),
        findsOneWidget,
      );
      expect(find.text('ÇAĞRI'), findsOneWidget);
      expect(find.text('Okumayı Kaldır'), findsOneWidget);
      expect(textFieldLabeled('Ad'), findsNothing);
    });
  });

  group('giriş kararı', () {
    testWidgets('Android + NFC + inceleme yok: çip formu ve tepede fotoğraf '
        'kartı', (tester) async {
      await pumpPage(tester, okApi());

      expect(find.text('Fotoğrafla doğrula'), findsOneWidget);
      expect(find.text('Fotoğrafla Doğrula'), findsOneWidget);
      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      expect(documentsOpened, 0);
    });

    testWidgets(
      'iOS: doğrudan fotoğraf akışı, dönüşte aynı sonuçla kapanıyor',
      (tester) async {
        await pumpPage(tester, okApi(), documentsResult: () => false);

        expect(documentsOpened, 1);
        expect(find.text('Kimlik kartını telefona okut'), findsNothing);
        expect(popResults, [false]);
        expect(find.text('profil ekranı'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('NFC olmayan cihaz: doğrudan fotoğraf akışı', (tester) async {
      await pumpPage(
        tester,
        okApi(),
        chipReader: _UnsupportedChipReader(),
        documentsResult: () => false,
      );

      expect(documentsOpened, 1);
      expect(popResults, [false]);
    });

    testWidgets('bekleyen inceleme varken çip formu yerine fotoğraf akışı', (
      tester,
    ) async {
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/users/me/identity-documents') {
            return identityReviewResponse(status: 'PENDING');
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': _user.toJson()},
          );
        },
      );

      await pumpPage(tester, api, documentsResult: () => false);

      expect(documentsOpened, 1);
      expect(popResults, [false]);
    });

    testWidgets(
      'fotoğraf akışı true ile kapanınca kimlik ekranı da true ile kapanıyor',
      (tester) async {
        await pumpPage(tester, okApi(), documentsResult: () => true);

        expect(popResults, [true]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('inceleme durumu okunamazsa çip formu yine açılıyor', (
      tester,
    ) async {
      // Ağ hatası kullanıcıyı çip yolundan mahrum etmiyor; fotoğraf kartı
      // zaten tepede.
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/users/me/identity-documents') {
            return const FakeApiResponse.connectionError();
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': _user.toJson()},
          );
        },
      );

      await pumpPage(tester, api);

      expect(documentsOpened, 0);
      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
    });
  });

  group('fotoğraf yoluna geçiş', () {
    testWidgets('tepedeki kart fotoğraf akışını açıyor; geri dönülürse form '
        'yerinde', (tester) async {
      final router = await pumpPage(tester, okApi());

      await tester.tap(find.text('Fotoğrafla Doğrula'));
      await tester.pumpAndSettle();
      expect(documentsOpened, 1);
      expect(find.text('fotoğraf akışı'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      expect(popResults, isEmpty);
    });

    testWidgets('çip ekranı "Fotoğrafla Devam Et" ile kapanınca fotoğraf '
        'akışı açılıyor', (tester) async {
      await pumpPage(
        tester,
        okApi(),
        chipExit: () => IdentityChipHandoff.photos,
      );

      await readChip(tester);

      expect(documentsOpened, 1);
      expect(find.text('fotoğraf akışı'), findsOneWidget);
    });

    testWidgets('sunucu çip kanıtını reddedince fotoğraf kartı uyarıya '
        'dönüyor', (tester) async {
      final api = rejectingApi(IdentityError.signatureInvalid.code);
      await pumpPage(tester, api, chipResult: () => _chipResult());
      await readChip(tester);

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(find.text('Çip yolu bu sefer tamamlanamadı'), findsOneWidget);
      expect(find.text('Fotoğrafla Devam Et'), findsOneWidget);
      expect(find.text('Fotoğrafla Doğrula'), findsNothing);

      await tester.ensureVisible(find.text('Fotoğrafla Devam Et'));
      await tester.tap(find.text('Fotoğrafla Devam Et'));
      await tester.pumpAndSettle();
      expect(documentsOpened, 1);
    });

    testWidgets('tanınmayan sunucu hatasında da fotoğraf yolu öne çıkıyor', (
      tester,
    ) async {
      final api = rejectingApi('SOMETHING_NEW');
      await pumpPage(tester, api);
      await enterField(tester, 'TC Kimlik No', '12345678950');
      await enterField(tester, 'Seri No', 'A01B23456');

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(find.text('Çip yolu bu sefer tamamlanamadı'), findsOneWidget);
      expect(find.text('Fotoğrafla Devam Et'), findsOneWidget);
    });

    testWidgets('fotoğraf akışında gönderim yapılıp dönülürse kimlik ekranı '
        'kapanıyor', (tester) async {
      // Dönüşte provider bir inceleme taşıyor: kullanıcı fotoğrafları
      // göndermiş. Çip formunun artık işi yok.
      var submitted = false;
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/users/me/identity-documents') {
            return submitted
                ? identityReviewResponse(status: 'PENDING')
                : noIdentityReviewResponse;
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': _user.toJson()},
          );
        },
      );
      final router = await pumpPage(tester, api);

      await tester.tap(find.text('Fotoğrafla Doğrula'));
      await tester.pumpAndSettle();
      submitted = true;
      // Sahte akış provider'ı gerçek ekran gibi tazeliyor.
      final context = tester.element(find.text('fotoğraf akışı'));
      unawaited(context.read<IdentityReviewProvider>().load(silent: true));
      await tester.pumpAndSettle();
      router.pop(false);
      await tester.pumpAndSettle();

      expect(popResults, [false]);
      expect(find.text('profil ekranı'), findsOneWidget);
    });
  });
}
