import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/presentation/pages/b_applications_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/business/features/home/services/received_application_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';
import '../../../../../support/identity_gate_test_support.dart';
import '../../../../../support/received_application_fixtures.dart';

const _companyA = {
  'companyId': 'company-a',
  'companyName': 'Kahve Evi',
  'approved': true,
  'role': 'ADMIN',
};

/// Henüz onaylanmamış şirket üyeliği: ilan açamıyor, süzecek bir şey yok.
const _companyPending = {
  'companyId': 'company-pending',
  'companyName': 'Onay Bekleyen Ltd.',
  'approved': false,
  'role': 'ADMIN',
};

const _ownJob = {
  'id': 'job-own',
  'title': 'Garson',
  'salary': 1000,
  'status': 'OPEN',
  'applicationCount': 2,
  'category': {'id': 'category-1', 'code': 'WAITER', 'name': 'Garson'},
};

/// Testin gözlediği gezinme: hangi rota hangi `extra` ile açıldı.
class _Navigation {
  final List<Object?> reviewOpened = [];
  final List<Object?> profileOpened = [];
}

class _Harness {
  _Harness(this.api, this.navigation);

  final FakeApi api;
  final _Navigation navigation;

  /// Gelen kutusuna giden istekler.
  List<Map<String, dynamic>> get inboxQueries => [
    for (final request in api.requests)
      if (isReceivedApplicationsRequest(request.path)) request.queryParameters,
  ];
}

/// Sayfayı gerçek temayla, iki yan rotası olan bir `GoRouter` içinde çizer.
Future<_Harness> _pump(
  WidgetTester tester, {
  required FutureOr<FakeApiResponse> Function(RequestOptions options) inbox,
  List<Map<String, dynamic>> companies = const [],
  List<Map<String, dynamic>> ownJobs = const [],
  Brightness brightness = Brightness.light,
  bool settle = true,
}) async {
  // Üç satır ve üç çip sırası ekrana sığsın.
  tester.view.physicalSize = const Size(1170, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final api = FakeApi(handler: inbox);

  final userApi = FakeApi(
    handler: (_) => FakeApiResponse(
      statusCode: 200,
      body: employerMeResponse(identityVerified: true, companies: companies),
    ),
  );
  final userProvider = UserProvider(
    userService: UserService.withClient(userApi.client),
  );
  await tester.runAsync(userProvider.load);

  final jobsApi = FakeApi(
    handler: (_) => FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'content': ownJobs},
      },
    ),
  );
  final jobsProvider = BJobsProvider(
    service: EmployerJobService.withClient(jobsApi.client),
  );
  await tester.runAsync(jobsProvider.load);

  final navigation = _Navigation();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => BApplicationsPage(
          service: ReceivedApplicationService.withClient(api.client),
        ),
      ),
      GoRoute(
        path: '/business/job-detail',
        builder: (context, state) {
          navigation.reviewOpened.add(state.extra);
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey('stub-review-back'),
                onPressed: context.pop,
                child: Text('Karar ekranı ${state.extra}'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: BusinessRoutes.userProfile,
        builder: (context, state) {
          navigation.profileOpened.add(state.extra);
          return Scaffold(
            body: Text('Aday profili ${state.extra.runtimeType}'),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: jobsProvider),
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    ),
  );
  // Yanıtı bekleyen ekranda çark sonsuza dek dönüyor: `pumpAndSettle` bitmez.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return _Harness(api, navigation);
}

/// Yatay kayan çip satırında ekran dışında kalan çipe dokunur.
Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

FutureOr<FakeApiResponse> Function(RequestOptions) _alwaysReturning(
  List<Map<String, dynamic>> rows,
) {
  return (_) => receivedApplicationsResponse(rows);
}

void main() {
  for (final brightness in Brightness.values) {
    group('BApplicationsPage (${brightness.name})', () {
      testWidgets('satır başvuranı, ilanı, şirketi ve durumu yazar', (
        tester,
      ) async {
        await _pump(
          tester,
          brightness: brightness,
          inbox: _alwaysReturning([
            receivedApplicationJson(
              'app-1',
              companyId: 'company-a',
              companyName: 'Kahve Evi',
              notes: 'Hafta sonu çalışabilirim',
            ),
            receivedApplicationJson(
              'app-2',
              status: 'ACCEPTED',
              firstName: 'Mehmet',
              lastName: 'Demir',
              workerId: 'worker-2',
              postingTitle: 'Garson',
              answeredDateTime: '2026-09-16T09:30:00Z',
              assignmentId: 'asg-1',
            ),
            receivedApplicationJson(
              'app-3',
              status: 'REJECTED',
              firstName: 'Zeynep',
              lastName: 'Kaya',
              workerId: 'worker-3',
              jobStatus: 'CLOSED',
            ),
          ]),
        );

        expect(find.text('Başvurular'), findsOneWidget);
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
        expect(find.text('Barista'), findsWidgets);
        expect(find.text('Kahve Evi'), findsWidgets);
        expect(find.text('Hafta sonu çalışabilirim'), findsOneWidget);
        expect(find.text('Bekliyor'), findsOneWidget);
        expect(find.text('Başvuru: 15.09.2026'), findsWidgets);

        // Kabul edilen satır yanıt tarihini taşır.
        expect(find.text('Mehmet Demir'), findsOneWidget);
        expect(find.text('Kabul edildi'), findsOneWidget);
        expect(find.text('Kabul: 16.09.2026'), findsOneWidget);

        // Reddedilen ve kapanmış ilan: ikisi de söyleniyor.
        expect(find.text('Zeynep Kaya'), findsOneWidget);
        expect(find.text('Reddedildi'), findsOneWidget);
        expect(find.text('İlan kapalı'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tanınmayan durum "Bilinmiyor" yazar, bekliyor demez', (
        tester,
      ) async {
        await _pump(
          tester,
          brightness: brightness,
          inbox: _alwaysReturning([
            receivedApplicationJson('app-1', status: 'EXPIRED'),
          ]),
        );

        expect(find.text('Bilinmiyor'), findsWidgets);
        expect(find.text('Bekliyor'), findsNothing);
      });

      testWidgets('yükleme sürerken çark, yanıtla birlikte liste', (
        tester,
      ) async {
        final reply = Completer<FakeApiResponse>();
        await _pump(
          tester,
          brightness: brightness,
          inbox: (_) => reply.future,
          settle: false,
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Henüz başvuru yok'), findsNothing);

        reply.complete(
          receivedApplicationsResponse([receivedApplicationJson('app-1')]),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      });

      testWidgets('boş gelen kutusu hata değil; açıklama yazar', (
        tester,
      ) async {
        await _pump(
          tester,
          brightness: brightness,
          inbox: _alwaysReturning(const []),
        );

        expect(find.text('Henüz başvuru yok'), findsOneWidget);
        expect(find.text('Tekrar Dene'), findsNothing);
        expect(find.byKey(const ValueKey('inbox-clear-filters')), findsNothing);
      });

      testWidgets('hata satır yerine mesaj ve Tekrar Dene çizer', (
        tester,
      ) async {
        var calls = 0;
        final harness = await _pump(
          tester,
          brightness: brightness,
          inbox: (_) => ++calls == 1
              ? receivedApplicationsFailure
              : receivedApplicationsResponse([receivedApplicationJson('a')]),
        );

        expect(find.text('Başvurular alınamadı'), findsOneWidget);
        // "Başvuru yok" demek sunucuya ulaşılamadığında yanlış olurdu.
        expect(find.text('Henüz başvuru yok'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('inbox-retry')));
        await tester.pumpAndSettle();

        expect(harness.inboxQueries, hasLength(2));
        expect(find.text('Başvurular alınamadı'), findsNothing);
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      });

      testWidgets('durum çipi süzgeci sunucuya adıyla gönderir', (
        tester,
      ) async {
        final harness = await _pump(
          tester,
          brightness: brightness,
          inbox: (options) => options.queryParameters['status'] == 'ACCEPTED'
              ? receivedApplicationsResponse([
                  receivedApplicationJson(
                    'app-2',
                    status: 'ACCEPTED',
                    firstName: 'Mehmet',
                    lastName: 'Demir',
                  ),
                ])
              : receivedApplicationsResponse([
                  receivedApplicationJson('app-1'),
                ]),
        );
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);

        await _tapKey(tester, 'inbox-status-ACCEPTED');

        expect(harness.inboxQueries.last, {
          'status': 'ACCEPTED',
          'page': 0,
          'size': 20,
        });
        expect(find.text('Ayşe Yılmaz'), findsNothing);
        expect(find.text('Mehmet Demir'), findsOneWidget);

        await _tapKey(tester, 'inbox-status-all');

        expect(harness.inboxQueries.last, {'page': 0, 'size': 20});
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      });

      testWidgets('süzgeçli boş durum süzgeci temizleme yolu verir', (
        tester,
      ) async {
        final harness = await _pump(
          tester,
          brightness: brightness,
          inbox: (options) => options.queryParameters.containsKey('status')
              ? receivedApplicationsResponse(const [])
              : receivedApplicationsResponse([receivedApplicationJson('a')]),
        );

        await _tapKey(tester, 'inbox-status-REJECTED');

        expect(find.text('Bu süzgeçte başvuru yok'), findsOneWidget);
        expect(find.text('Henüz başvuru yok'), findsNothing);
        // Üç süzgecin üçü de söyleniyor: ilan süzgeci de açıklamada geçiyor.
        expect(find.textContaining('durum, şirket ya da ilan'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('inbox-clear-filters')));
        await tester.pumpAndSettle();

        expect(harness.inboxQueries.last, {'page': 0, 'size': 20});
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      });

      testWidgets('şirket çipleri yalnız şirket üyeliği varsa çıkar', (
        tester,
      ) async {
        await _pump(
          tester,
          brightness: brightness,
          inbox: _alwaysReturning([receivedApplicationJson('a')]),
        );
        expect(find.byKey(const ValueKey('inbox-company-all')), findsNothing);

        await _pump(
          tester,
          brightness: brightness,
          companies: const [_companyA],
          inbox: _alwaysReturning([receivedApplicationJson('a')]),
        );
        expect(find.byKey(const ValueKey('inbox-company-all')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('inbox-company-company-a')),
          findsOneWidget,
        );
      });

      testWidgets('onaylanmamış şirket çip olmaz', (tester) async {
        await _pump(
          tester,
          brightness: brightness,
          companies: const [_companyPending],
          inbox: _alwaysReturning([receivedApplicationJson('a')]),
        );

        // Onaysız şirketin tek üyeliği varsa şirket satırı hiç çıkmıyor.
        expect(find.byKey(const ValueKey('inbox-company-all')), findsNothing);

        await _pump(
          tester,
          brightness: brightness,
          companies: const [_companyA, _companyPending],
          inbox: _alwaysReturning([receivedApplicationJson('a')]),
        );
        expect(
          find.byKey(const ValueKey('inbox-company-company-a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('inbox-company-company-pending')),
          findsNothing,
        );
      });

      testWidgets('şirket çipi companyId gönderir', (tester) async {
        final harness = await _pump(
          tester,
          brightness: brightness,
          companies: const [_companyA],
          inbox: _alwaysReturning([receivedApplicationJson('a')]),
        );

        await _tapKey(tester, 'inbox-company-company-a');

        expect(harness.inboxQueries.last, {
          'companyId': 'company-a',
          'page': 0,
          'size': 20,
        });
      });

      testWidgets('ilan süzgeci seçici ve kaldırılabilir çip', (tester) async {
        final harness = await _pump(
          tester,
          brightness: brightness,
          ownJobs: const [_ownJob],
          inbox: _alwaysReturning([
            receivedApplicationJson(
              'a',
              jobId: 'job-1',
              postingTitle: 'Barista',
            ),
          ]),
        );

        await tester.tap(find.byKey(const ValueKey('inbox-job-pill')));
        await tester.pumpAndSettle();
        // Seçenekler: kendi ilanları ve listede görünenler.
        expect(find.text('Tüm ilanlar'), findsOneWidget);
        expect(find.text('Garson'), findsOneWidget);

        await tester.tap(find.text('Garson'));
        await tester.pumpAndSettle();

        expect(harness.inboxQueries.last, {
          'jobId': 'job-own',
          'page': 0,
          'size': 20,
        });
        expect(find.text('İlan: Garson'), findsOneWidget);

        // Çipin çarpısı süzgeci kaldırır.
        await tester.tap(findAppIcon(AppIcons.close));
        await tester.pumpAndSettle();
        expect(harness.inboxQueries.last, {'page': 0, 'size': 20});
        expect(find.text('İlana göre'), findsOneWidget);
      });

      testWidgets(
        'karta dokunmak ilanın karar ekranını açar, dönünce tazeler',
        (tester) async {
          final harness = await _pump(
            tester,
            brightness: brightness,
            inbox: _alwaysReturning([
              receivedApplicationJson('app-1', jobId: 'job-77'),
            ]),
          );
          expect(harness.inboxQueries, hasLength(1));

          await tester.tap(find.byKey(const ValueKey('application-app-1')));
          await tester.pumpAndSettle();

          expect(harness.navigation.reviewOpened, ['job-77']);
          expect(find.text('Karar ekranı job-77'), findsOneWidget);

          await tester.tap(find.byKey(const ValueKey('stub-review-back')));
          await tester.pumpAndSettle();

          // Kabul/ret orada verildiği için dönüşte liste yeniden okunuyor.
          expect(harness.inboxQueries, hasLength(2));
          expect(find.text('Ayşe Yılmaz'), findsOneWidget);
        },
      );

      testWidgets(
        'karar ekranından dönüşteki başarısız yenileme toast ile söylenir',
        (tester) async {
          var calls = 0;
          final harness = await _pump(
            tester,
            brightness: brightness,
            inbox: (_) => ++calls == 1
                ? receivedApplicationsResponse([
                    receivedApplicationJson('app-1'),
                  ])
                : receivedApplicationsFailure,
          );

          await tester.tap(find.byKey(const ValueKey('application-app-1')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('stub-review-back')));
          await tester.pumpAndSettle();

          // Yenileme sessizce yutulsaydı kullanıcı bayat durumu güncel sanırdı.
          expect(harness.inboxQueries, hasLength(2));
          expect(find.text('Başvurular alınamadı'), findsOneWidget);
          // Satır yerinde; tam hata ekranına düşülmedi.
          expect(find.text('Ayşe Yılmaz'), findsOneWidget);
          expect(find.byKey(const ValueKey('inbox-retry')), findsNothing);
        },
      );

      testWidgets('Adayın profili başvuranı profil rotasına taşır', (
        tester,
      ) async {
        final harness = await _pump(
          tester,
          brightness: brightness,
          inbox: _alwaysReturning([
            receivedApplicationJson('app-1', notes: 'Merhaba'),
          ]),
        );

        await tester.tap(
          find.byKey(const ValueKey('application-profile-app-1')),
        );
        await tester.pumpAndSettle();

        final extra = harness.navigation.profileOpened.single;
        expect(extra, isA<JobApplicant>());
        extra as JobApplicant;
        expect(extra.id, 'app-1');
        expect(extra.user.id, 'worker-1');
        expect(extra.notes, 'Merhaba');
        expect(extra.status, ApplicationStatus.applied);
        // Karar ekranı açılmadı.
        expect(harness.navigation.reviewOpened, isEmpty);
      });

      testWidgets('çekip yenileme listeyi yeniden okur', (tester) async {
        final harness = await _pump(
          tester,
          brightness: brightness,
          inbox: _alwaysReturning([receivedApplicationJson('a')]),
        );

        await tester.drag(find.byType(ListView).last, const Offset(0, 400));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(harness.inboxQueries, hasLength(2));
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      });

      testWidgets('başarısız yenileme listeyi korur ve toast ile söyler', (
        tester,
      ) async {
        var calls = 0;
        await _pump(
          tester,
          brightness: brightness,
          inbox: (_) => ++calls == 1
              ? receivedApplicationsResponse([receivedApplicationJson('a')])
              : receivedApplicationsFailure,
        );

        await tester.drag(find.byType(ListView).last, const Offset(0, 400));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
        expect(find.text('Başvurular alınamadı'), findsOneWidget);
        // Satır varken tam hata ekranına düşülmüyor.
        expect(find.byKey(const ValueKey('inbox-retry')), findsNothing);
      });

      testWidgets('listenin sonuna gelince sonraki sayfa istenir', (
        tester,
      ) async {
        final harness = await _pump(
          tester,
          brightness: brightness,
          inbox: (options) => options.queryParameters['page'] == 0
              ? receivedApplicationsResponse([
                  for (var i = 0; i < 20; i++) receivedApplicationJson('a-$i'),
                ], last: false)
              : receivedApplicationsResponse([
                  receivedApplicationJson(
                    'b-0',
                    firstName: 'Sonraki',
                    lastName: 'Sayfa',
                  ),
                ], page: 1),
        );
        expect(harness.inboxQueries, hasLength(1));

        await tester.drag(find.byType(ListView).last, const Offset(0, -20000));
        await tester.pumpAndSettle();

        expect(harness.inboxQueries.last, {'page': 1, 'size': 20});
        await tester.drag(find.byType(ListView).last, const Offset(0, -20000));
        await tester.pumpAndSettle();
        expect(find.text('Sonraki Sayfa'), findsOneWidget);
        // Son sayfadan sonra yeni istek yok.
        expect(harness.inboxQueries, hasLength(2));
      });

      testWidgets('sonraki sayfa hatası liste sonunda Tekrar Dene verir', (
        tester,
      ) async {
        var secondPageCalls = 0;
        final harness = await _pump(
          tester,
          brightness: brightness,
          inbox: (options) {
            if (options.queryParameters['page'] == 0) {
              return receivedApplicationsResponse([
                for (var i = 0; i < 20; i++) receivedApplicationJson('a-$i'),
              ], last: false);
            }
            return ++secondPageCalls == 1
                ? receivedApplicationsFailure
                : receivedApplicationsResponse([
                    receivedApplicationJson(
                      'b-0',
                      firstName: 'Sonraki',
                      lastName: 'Sayfa',
                    ),
                  ], page: 1);
          },
        );

        await tester.drag(find.byType(ListView).last, const Offset(0, -20000));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('inbox-load-more-retry')),
          findsOneWidget,
        );

        // Hata sürerken kaydırmak sunucuya yüklenmiyor.
        await tester.drag(find.byType(ListView).last, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(harness.inboxQueries, hasLength(2));

        await tester.tap(find.byKey(const ValueKey('inbox-load-more-retry')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).last, const Offset(0, -20000));
        await tester.pumpAndSettle();
        expect(find.text('Sonraki Sayfa'), findsOneWidget);
      });
    });
  }
}
