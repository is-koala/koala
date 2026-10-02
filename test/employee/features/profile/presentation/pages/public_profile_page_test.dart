import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/models/public_profile_args.dart';
import 'package:koala/employee/features/profile/presentation/pages/public_profile_page.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/profile_cover.dart';
import 'package:koala/product/widgets/report_sheet.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';
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
  // koala-backend#282: özet profil yanıtında da geliyor.
  'reviewCount': 12,
  'averageRating': 4.5,
};

/// `GET /users/{id}/rating-summary` gövdesi; yalnızca profil yanıtı özeti
/// taşımıyorsa (eski sunucu) çekiliyor.
const Map<String, Object?> _rating = {
  'userId': 'user-9',
  'reviewCount': 12,
  'averageRating': 4.5,
};

const Map<String, Object?> _koalaCafe = {'id': 'comp-7', 'name': 'Koala Cafe'};

/// `GET /jobs/{id}` gövdesi; ilan sahibi şirket mi bireysel mi testin
/// verdiği hâlde.
Map<String, Object?> _jobJson({
  String employerType = 'COMPANY',
  Map<String, Object?>? company = _koalaCafe,
}) => {
  'id': 'job-1',
  'title': 'Hafta Sonu Garson',
  'description': 'Hafta sonu vardiyası.',
  'category': {'id': 'category-1', 'code': 'WAITER', 'name': 'Garson'},
  'type': 'ONE_TIME',
  'employerType': employerType,
  'salaryType': 'DAILY',
  'salary': 1000,
  'status': 'OPEN',
  'addressPrecision': 'APPROXIMATE',
  'address': {
    'id': 'adr-1',
    'countryId': 'c-1',
    'countryName': 'Türkiye',
    'countryCode': 'TR',
    'cityId': 'ct-1',
    'cityName': 'İstanbul',
    'districtId': 'd-1',
    'districtName': 'Kadıköy',
  },
  'company': ?company,
};

const FakeApiResponse _jobNotFound = FakeApiResponse(
  statusCode: 404,
  body: {
    'success': false,
    'message': 'İlan bulunamadı.',
    'errorCategory': 'RESOURCE_NOT_FOUND',
  },
);

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
  FakeApiResponse? jobDetail,
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
      if (path.startsWith('/jobs/')) return jobDetail ?? _jobNotFound;
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
            jobService: JobService.withClient(api.client),
          ),
        ),
      ),
      GoRoute(
        path: EmployeeRoutes.ownProfile,
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

/// Profil gelmeden (ya da hiç gelmeyecekken) yalnız profil isteniyor:
/// değerlendirme, puan özeti ve ilan uçları sonraya bırakılıyor.
void _expectNothingBeyondTheProfileRequested(FakeApi api) {
  final paths = _requestedPaths(api);
  expect(paths, contains('/users/user-9'));
  expect(
    paths.where(
      (path) =>
          path.endsWith('/reviews') ||
          path.endsWith('/rating-summary') ||
          path.startsWith('/jobs/'),
    ),
    isEmpty,
    reason: 'profil gelmeden ek uçlar istenmemeli: $paths',
  );
}

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
          final paths = _requestedPaths(harness.api);
          expect(paths, contains('/users/user-9'));
          expect(paths, contains('/users/user-9/reviews'));
          // Özet profil yanıtında zaten var: ayrı uç çağrılmıyor.
          expect(paths, isNot(contains('/users/user-9/rating-summary')));
          // Hata durumunun hiçbir parçası görünmüyor.
          expect(find.text(PublicProfilePage.unavailableTitle), findsNothing);
        },
      );

      // `GET /users/{id}` bugün 403 üretmiyor (giriş yapmış herkes var olan
      // her kullanıcıyı görüyor); 404 ile 403'ün aynılığı savunmacı eşitlik —
      // ileride bir görünürlük kuralı gelirse hesabın var olup olmadığı
      // ekrandan okunamasın.
      testWidgets('hata: 404 ve 403 aynı tek "profil görüntülenemiyor" '
          'durumu, çağıranın verdiği ad bile çizilmez', (tester) async {
        final notFoundHarness = await _pump(
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
        // Kesin ret: tekrar denemenin anlamı yok; şikayet edilecek bir
        // profil de yok.
        expect(find.text('Tekrar Dene'), findsNothing);
        expect(find.byTooltip('Şikayet Et'), findsNothing);
        _expectNothingBeyondTheProfileRequested(notFoundHarness.api);

        final notFoundTexts = _visibleTexts(tester);

        final forbiddenHarness = await _pump(
          tester,
          args: ayse,
          profile: () => _forbidden,
          brightness: brightness,
        );

        expect(find.text('Bu profili görme yetkiniz yok.'), findsNothing);
        _expectNothingBeyondTheProfileRequested(forbiddenHarness.api);
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

      // Grup sohbetinde şikayet/engelle yok ve sunucu grupta engeli
      // uygulamıyor: çalışanın ekip arkadaşını ya da şirket yetkilisini
      // bildirebileceği yer burası.
      testWidgets('şikayet eylemi mevcut ReportSheet\'i açar, engelle yok', (
        tester,
      ) async {
        await _pump(tester, args: ayse, brightness: brightness);

        expect(findAppIcon(AppIcons.flag), findsOneWidget);
        expect(find.byTooltip('Engelle'), findsNothing);

        await tester.tap(find.byTooltip('Şikayet Et'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final sheet = tester.widget<ReportSheet>(find.byType(ReportSheet));
        expect(sheet.target.reportedUserId, 'user-9');
        // Form hedefin adını taşıyor: yanlış kişiyi bildirmek kolay olmasın.
        expect(
          find.text('Ayşe Yılmaz hakkında bildirimde bulunuyorsun.'),
          findsOneWidget,
        );
      });
    });
  }

  testWidgets('ad ve rol, profil yanıtı gelmeden kapakta çiziliyor', (
    tester,
  ) async {
    final response = Completer<FakeApiResponse>();
    final harness = await _pump(
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
    // Profil gelmeden değerlendirme ve ilan uçları istenmiyor.
    _expectNothingBeyondTheProfileRequested(harness.api);

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

    // Ad bilinmiyorken boş bir kapak çizilmiyor: yalnız bekleme halkası.
    expect(find.byType(ProfileCover), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsNothing);

    response.complete(dataResponse(_ayseProfile));
    await _settle(tester);

    expect(find.byType(ProfileCover), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    // Rol çağıranda yok: uydurulmuyor.
    expect(find.text('İşveren'), findsNothing);
    expect(find.text('Çalışan'), findsNothing);
    expect(find.text('Şirket yetkilisi'), findsNothing);
  });

  // Kimlik yol parametresi; `extra` yalnızca kapağı önceden doldurur ve
  // eksik ya da yanlış olması sayfayı açılmaktan alıkoymaz.
  test('rota: kimlik yol parametresinden, extra yalnız aynı kişiyse', () {
    final bare = PublicProfilePage.fromRoute(userId: 'user-9');
    expect(bare.args.userId, 'user-9');
    expect(bare.args.name, isNull);

    expect(
      PublicProfilePage.fromRoute(userId: 'user-9', extra: ayse).args,
      same(ayse),
    );

    // Başka kişinin extra'sı: kimlik de ad da yol parametresine uyuyor.
    const other = PublicProfileArgs(userId: 'user-1', name: 'Başkası');
    final mismatched = PublicProfilePage.fromRoute(
      userId: 'user-9',
      extra: other,
    );
    expect(mismatched.args.userId, 'user-9');
    expect(mismatched.args.name, isNull);

    // Beklenmeyen türler fırlatmıyor.
    for (final extra in <Object?>[
      null,
      42,
      'user-9',
      const {'a': 1},
    ]) {
      final page = PublicProfilePage.fromRoute(userId: 'user-9', extra: extra);
      expect(page.args.userId, 'user-9', reason: '$extra');
      expect(page.args.name, isNull, reason: '$extra');
    }
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

  // Şirket, profil yanıtında da sohbet katılımcısında da yok: sohbetin
  // bağlı olduğu ilanın detayından çözülüyor.
  group('şirket', () {
    const contact = PublicProfileArgs(
      userId: 'user-9',
      name: 'Yetkili Kişi',
      role: ChatParticipantRole.companyContact,
      jobId: 'job-1',
    );

    for (final brightness in Brightness.values) {
      testWidgets('şirket ilanında şirket adı ve şirket sayfasına bağlantı '
          '(${brightness.name})', (tester) async {
        final harness = await _pump(
          tester,
          args: contact,
          jobDetail: dataResponse(_jobJson()),
          brightness: brightness,
        );

        expect(find.text('Koala Cafe'), findsOneWidget);
        expect(_requestedPaths(harness.api), contains('/jobs/job-1'));

        await tester.tap(find.byKey(const ValueKey('public-profile-company')));
        await tester.pumpAndSettle();

        expect(harness.openedCompanies, ['comp-7']);
      });
    }

    testWidgets('işveren rolü de şirketi ilandan çözer', (tester) async {
      await _pump(
        tester,
        args: PublicProfileArgs(
          userId: contact.userId,
          name: contact.name,
          role: ChatParticipantRole.employer,
          jobId: 'job-1',
        ),
        jobDetail: dataResponse(_jobJson()),
      );

      expect(find.text('Koala Cafe'), findsOneWidget);
    });

    testWidgets('bireysel ilanda şirket satırı yok', (tester) async {
      await _pump(
        tester,
        args: contact,
        // Bireysel ilan: `company` alanı gelse bile satır çizilmiyor.
        jobDetail: dataResponse(_jobJson(employerType: 'INDIVIDUAL')),
      );

      expect(
        find.byKey(const ValueKey('public-profile-company')),
        findsNothing,
      );
    });

    testWidgets('ilan okunamazsa satır yok, profil yine çizilir', (
      tester,
    ) async {
      await _pump(tester, args: contact, jobDetail: _jobNotFound);

      expect(
        find.byKey(const ValueKey('public-profile-company')),
        findsNothing,
      );
      expect(find.text('Kafe işletmecisi'), findsOneWidget);
      expect(find.text(PublicProfilePage.unavailableTitle), findsNothing);
    });

    testWidgets('çalışan rolü ya da ilansız açılış ilanı hiç istemez', (
      tester,
    ) async {
      final worker = await _pump(
        tester,
        args: PublicProfileArgs(
          userId: contact.userId,
          name: contact.name,
          role: ChatParticipantRole.worker,
          jobId: 'job-1',
        ),
        jobDetail: dataResponse(_jobJson()),
      );
      expect(_requestedPaths(worker.api), isNot(contains('/jobs/job-1')));
      expect(find.text('Koala Cafe'), findsNothing);

      final withoutJob = await _pump(
        tester,
        args: ayse,
        jobDetail: dataResponse(_jobJson()),
      );
      expect(
        _requestedPaths(withoutJob.api).where((p) => p.startsWith('/jobs/')),
        isEmpty,
      );
      expect(find.text('Koala Cafe'), findsNothing);
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
      profile: () =>
          dataResponse({..._ayseProfile, 'reviewCount': 0, 'averageRating': 0}),
      reviews: reviewsPageResponse(const []),
    );

    expect(find.text('Henüz puan yok'), findsOneWidget);
    expect(find.text('Henüz değerlendirme yok.'), findsOneWidget);
    expect(find.textContaining('Henüz değerlendirilmedin'), findsNothing);
    expect(find.text('0.0'), findsNothing);
  });

  // Eski sunucu profil yanıtına özet koymuyor: o zaman özet ayrı uçtan.
  testWidgets('profil yanıtında özet yoksa rating-summary ucuna düşer', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      args: ayse,
      profile: () => dataResponse({
        for (final entry in _ayseProfile.entries)
          if (entry.key != 'reviewCount' && entry.key != 'averageRating')
            entry.key: entry.value,
      }),
    );

    expect(
      _requestedPaths(harness.api),
      contains('/users/user-9/rating-summary'),
    );
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('(12)'), findsOneWidget);
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
