import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/models/public_profile_args.dart';
import 'package:koala/employee/features/profile/presentation/pages/public_profile_page.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/review_fixtures.dart';
import '../../../../../support/work_test_support.dart';

/// Karşı tarafın `GET /users/{id}` gövdesi (`PublicProfileDto`).
const Map<String, Object?> _ayseProfile = {
  'id': 'user-9',
  'firstName': 'Ayşe',
  'lastName': 'Yılmaz',
  'jobTitle': 'Kafe işletmecisi',
  'about': 'Moda\'da küçük bir kafe işletiyorum.',
  'cityName': 'İstanbul',
  'districtName': 'Kadıköy',
};

const Map<String, Object?> _rating = {
  'userId': 'user-9',
  'reviewCount': 12,
  'averageRating': 4.5,
};

/// Sunucunun var/yok bilgisini sızdırabileceği iki ayrı ret: farklı durum
/// kodu, farklı kategori, farklı mesaj. Ekran ikisini ayırt etmemeli.
const FakeApiResponse _notFound = FakeApiResponse(
  statusCode: 404,
  body: {
    'success': false,
    'message': 'Kullanıcı bulunamadı.',
    'errorCategory': 'RESOURCE_NOT_FOUND',
  },
);

const FakeApiResponse _forbidden = FakeApiResponse(
  statusCode: 403,
  body: {
    'success': false,
    'message': 'Bu profili görme yetkiniz yok.',
    'errorCategory': 'ACCESS_DENIED',
  },
);

const FakeApiResponse _serverError = FakeApiResponse(
  statusCode: 500,
  body: {
    'success': false,
    'message': 'Beklenmeyen bir hata oluştu.',
    'errorCategory': 'UNEXPECTED',
  },
);

typedef _Harness = ({
  FakeApi api,
  List<Object?> openedCompanies,
  List<String> ownProfileVisits,
});

/// Sayfayı gerçek temada, sahte sunucuya bağlı çizer. Şirket sayfası ve kendi
/// profil sekmesi sahte rotalar: yalnız açılıp açılmadıkları ölçülüyor.
Future<_Harness> _pump(
  WidgetTester tester, {
  required PublicProfileArgs args,
  FutureOr<FakeApiResponse> Function()? profile,
  FakeApiResponse? ratingSummary,
  FakeApiResponse? reviews,
  Brightness brightness = Brightness.light,
  bool awaitsProfile = false,
}) async {
  final openedCompanies = <Object?>[];
  final ownProfileVisits = <String>[];

  final api = FakeApi(
    handler: (options) {
      final path = options.path;
      if (path == '/users/${args.userId}') {
        return profile?.call() ?? dataResponse(_ayseProfile);
      }
      if (path.endsWith('/rating-summary')) {
        return ratingSummary ?? dataResponse(_rating);
      }
      if (path.endsWith('/reviews')) {
        return reviews ??
            reviewsPageResponse([
              reviewDtoJson(comment: 'Ödemeyi zamanında yaptı.'),
            ]);
      }
      return dataResponse(null);
    },
  );

  final userProvider = (await tester.runAsync(loadedWorkerProvider))!;
  addTearDown(userProvider.dispose);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: PublicProfilePage(
            args: args,
            userService: UserService.withClient(api.client),
            reviewService: ReviewService.withClient(api.client),
          ),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) {
          ownProfileVisits.add(state.matchedLocation);
          return MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: Text('profil sekmesi')),
          );
        },
      ),
      GoRoute(
        path: '/company-detail',
        pageBuilder: (context, state) {
          openedCompanies.add(state.extra);
          return MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: Text('şirket ekranı')),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: userProvider,
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    ),
  );
  // Profil yanıtı bilerek bekletiliyorsa dönen gösterge hiç durmaz;
  // `pumpAndSettle` o zaman zaman aşımına uğrar, kareler elle ilerletiliyor.
  if (awaitsProfile) {
    await _pumpFrames(tester);
  } else {
    await _settle(tester);
  }

  return (
    api: api,
    openedCompanies: openedCompanies,
    ownProfileVisits: ownProfileVisits,
  );
}

/// Yükleme birkaç async servis katmanından geçiyor; olay döngüsü sabit
/// sayıda kareyle ilerletiliyor (bkz. work_detail_page_test).
Future<void> _settle(WidgetTester tester) async {
  await _pumpFrames(tester);
  await tester.pumpAndSettle();
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

List<String> _requestedPaths(FakeApi api) =>
    api.requests.map((request) => request.path).toList();

void main() {
  const ayse = PublicProfileArgs(
    userId: 'user-9',
    name: 'Ayşe Yılmaz',
    role: ChatParticipantRole.employer,
  );

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light ? 'açık' : 'koyu';

    group('$theme tema', () {
      testWidgets(
        'karşı taraf: ad, rol, meslek, konum, hakkında ve puan özeti',
        (tester) async {
          final harness = await _pump(
            tester,
            args: ayse,
            brightness: brightness,
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Ayşe Yılmaz'), findsWidgets);
          expect(find.text('İşveren'), findsOneWidget);
          expect(find.text('Kafe işletmecisi'), findsOneWidget);
          expect(find.text('Kadıköy/İstanbul'), findsOneWidget);
          expect(find.text('Hakkında'), findsOneWidget);
          expect(
            find.text('Moda\'da küçük bir kafe işletiyorum.'),
            findsOneWidget,
          );
          // Puan özeti ve son yorum: sahibinin kendi profiliyle aynı bölüm.
          expect(find.text('Değerlendirmeler'), findsOneWidget);
          expect(find.text('4.5'), findsOneWidget);
          expect(find.text('(12)'), findsOneWidget);
          expect(find.text('Ödemeyi zamanında yaptı.'), findsOneWidget);
          expect(_requestedPaths(harness.api), contains('/users/user-9'));
          // Hata durumunun hiçbir parçası görünmüyor.
          expect(find.text(PublicProfilePage.unavailableTitle), findsNothing);
        },
      );

      testWidgets('hata: 404 ve 403 aynı tek "profil görüntülenemiyor" '
          'durumu, çağıranın verdiği ad bile çizilmez', (tester) async {
        await _pump(
          tester,
          args: ayse,
          profile: () => _notFound,
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Profil görüntülenemiyor'), findsOneWidget);
        expect(
          find.text('Bu profil silinmiş ya da erişiminize kapalı olabilir.'),
          findsOneWidget,
        );
        // Var/yok sızdırma yok: sunucunun mesajı, çağıranın elindeki ad ve
        // profilin kendisi ekranda yok.
        expect(find.text('Kullanıcı bulunamadı.'), findsNothing);
        expect(find.text('Ayşe Yılmaz'), findsNothing);
        expect(find.text('İşveren'), findsNothing);
        expect(find.text('Hakkında'), findsNothing);
        expect(find.text('Değerlendirmeler'), findsNothing);
        // Kesin ret: tekrar denemenin anlamı yok.
        expect(find.text('Tekrar Dene'), findsNothing);

        final notFoundTexts = _visibleTexts(tester);

        await _pump(
          tester,
          args: ayse,
          profile: () => _forbidden,
          brightness: brightness,
        );

        expect(find.text('Bu profili görme yetkiniz yok.'), findsNothing);
        // İki ret ekranda birebir aynı.
        expect(_visibleTexts(tester), notFoundTexts);
      });

      testWidgets('geçici hata: aynı başlık, Tekrar Dene ile yeniden çekilir', (
        tester,
      ) async {
        var calls = 0;
        await _pump(
          tester,
          args: ayse,
          profile: () {
            calls++;
            return calls == 1 ? _serverError : dataResponse(_ayseProfile);
          },
          brightness: brightness,
        );

        expect(find.text('Profil görüntülenemiyor'), findsOneWidget);
        expect(
          find.text('Profil şu an yüklenemedi. Biraz sonra tekrar deneyin.'),
          findsOneWidget,
        );
        expect(find.text('Hakkında'), findsNothing);

        await tester.tap(find.text('Tekrar Dene'));
        await _settle(tester);

        expect(calls, 2);
        expect(find.text('Profil görüntülenemiyor'), findsNothing);
        expect(find.text('Kafe işletmecisi'), findsOneWidget);
      });
    });
  }

  testWidgets('ad ve rol, profil yanıtı gelmeden kapakta çiziliyor', (
    tester,
  ) async {
    final response = Completer<FakeApiResponse>();
    await _pump(
      tester,
      args: ayse,
      profile: () => response.future,
      awaitsProfile: true,
    );

    // Yanıt yok: kapak çağıranın verdiği ad ve rolle çizili, gövde bekliyor.
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('İşveren'), findsOneWidget);
    expect(find.text('Kafe işletmecisi'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(PublicProfilePage.unavailableTitle), findsNothing);

    response.complete(dataResponse(_ayseProfile));
    await _settle(tester);

    expect(find.text('Kafe işletmecisi'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('yalnız kimlikle açılınca kapak profil yanıtından dolar', (
    tester,
  ) async {
    final response = Completer<FakeApiResponse>();
    await _pump(
      tester,
      args: const PublicProfileArgs(userId: 'user-9'),
      profile: () => response.future,
      awaitsProfile: true,
    );

    // Ad bilinmiyorken boş bir kapak çizilmiyor.
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsNothing);

    response.complete(dataResponse(_ayseProfile));
    await _settle(tester);

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    // Rol çağıranda yok: uydurulmuyor.
    expect(find.text('İşveren'), findsNothing);
    expect(find.text('Çalışan'), findsNothing);
    expect(find.text('Şirket yetkilisi'), findsNothing);
  });

  testWidgets('rota extra\'sı kimlik dizgesi de olabilir', (tester) async {
    final page = PublicProfilePage.fromExtra('user-9');
    expect(page.args.userId, 'user-9');
    expect(page.args.name, isNull);

    final fromArgs = PublicProfilePage.fromExtra(ayse);
    expect(fromArgs.args, same(ayse));

    expect(() => PublicProfilePage.fromExtra(42), throwsArgumentError);
    expect(() => PublicProfilePage.fromExtra(null), throwsArgumentError);
  });

  group('rol etiketi', () {
    for (final (role, label) in [
      (ChatParticipantRole.employer, 'İşveren'),
      (ChatParticipantRole.companyContact, 'Şirket yetkilisi'),
      (ChatParticipantRole.worker, 'Çalışan'),
    ]) {
      testWidgets('${role.name} → $label', (tester) async {
        await _pump(
          tester,
          args: PublicProfileArgs(
            userId: 'user-9',
            name: 'Ayşe Yılmaz',
            role: role,
          ),
        );

        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('katılımcı satırından gelen rol aynen taşınır', (tester) async {
      const participant = ChatParticipant(
        id: 'user-9',
        firstName: 'Ayşe',
        lastName: 'Yılmaz',
        profilePictureUrl: 'https://cdn.example/ayse.png',
        role: ChatParticipantRole.companyContact,
      );

      final args = PublicProfileArgs.fromParticipant(participant);

      expect(args.userId, 'user-9');
      expect(args.name, 'Ayşe Yılmaz');
      expect(args.imageUrl, 'https://cdn.example/ayse.png');
      expect(args.role, ChatParticipantRole.companyContact);
    });
  });

  group('şirket', () {
    testWidgets('biliniyorsa ad ve şirket sayfasına bağlantı çizilir', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        args: const PublicProfileArgs(
          userId: 'user-9',
          name: 'Ayşe Yılmaz',
          role: ChatParticipantRole.companyContact,
          companyId: 'comp-7',
          companyName: 'Koala Cafe',
        ),
      );

      expect(find.text('Koala Cafe'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('public-profile-company')));
      await tester.pumpAndSettle();

      expect(harness.openedCompanies, ['comp-7']);
    });

    testWidgets('bilinmiyorsa satır da bağlantı da yok', (tester) async {
      await _pump(tester, args: ayse);

      expect(
        find.byKey(const ValueKey('public-profile-company')),
        findsNothing,
      );
    });

    testWidgets('kimliği yoksa ad çizilir ama dokunulmaz', (tester) async {
      final harness = await _pump(
        tester,
        args: const PublicProfileArgs(
          userId: 'user-9',
          name: 'Ayşe Yılmaz',
          companyName: 'Koala Cafe',
        ),
      );

      expect(find.text('Koala Cafe'), findsOneWidget);
      await tester.tap(find.text('Koala Cafe'));
      await tester.pumpAndSettle();

      expect(harness.openedCompanies, isEmpty);
    });
  });

  testWidgets('kendi profili: sekmeye yönlenir, profil çekilmez', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      args: const PublicProfileArgs(userId: workerId, name: 'Yakup Kahraman'),
    );

    expect(harness.ownProfileVisits, ['/profile']);
    expect(find.text('profil sekmesi'), findsOneWidget);
    expect(
      _requestedPaths(harness.api),
      isNot(contains('/users/$workerId')),
      reason: 'kendi profili "başkasının gözüyle" çekilmemeli',
    );
  });

  testWidgets('değerlendirmesi olmayanda sahibine konuşan cümle çıkmaz', (
    tester,
  ) async {
    await _pump(
      tester,
      args: ayse,
      ratingSummary: dataResponse(null),
      reviews: reviewsPageResponse(const []),
    );

    expect(find.text('Henüz puan yok'), findsOneWidget);
    expect(find.text('Henüz değerlendirme yok.'), findsOneWidget);
    expect(find.textContaining('Henüz değerlendirilmedin'), findsNothing);
    expect(find.text('0.0'), findsNothing);
  });

  testWidgets('hakkında boşsa boş bir kart çizilmez', (tester) async {
    await _pump(
      tester,
      args: ayse,
      profile: () => dataResponse({..._ayseProfile, 'about': null}),
    );

    expect(find.text('Kafe işletmecisi'), findsOneWidget);
    expect(find.text('Hakkında'), findsNothing);
  });
}

/// Ekranda çizilen bütün metinler; iki hata ekranının aynılığını ölçmek için.
List<String> _visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .toList();
