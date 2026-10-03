import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_home_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

const _job = {
  'id': 'job-1',
  'title': 'Barista',
  'salary': 1000,
  'status': 'OPEN',
  'applicationCount': 4,
  'category': {'id': 'category-1', 'code': 'BARISTA', 'name': 'Barista'},
};

/// Ana sayfayı, gelen kutusu rotasının yerine geçen bir sayfayla birlikte
/// çizer; "kutu açıldı" iddiası bu sayfanın başlığına bakıyor.
Future<void> _pumpHome(WidgetTester tester, Brightness brightness) async {
  final jobsApi = FakeApi(
    handler: (request) => request.path == '/users/me/jobs'
        ? const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'content': [_job],
              },
            },
          )
        : const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': <Object>[]},
          ),
  );
  final jobsProvider = BJobsProvider(
    service: EmployerJobService.withClient(jobsApi.client),
  );
  await tester.runAsync(jobsProvider.load);

  final auxiliaryApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 500,
      body: {'success': false, 'message': 'Testte kullanılmıyor'},
    ),
  );

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => BHomePage()),
      GoRoute(
        path: BusinessRoutes.applications,
        builder: (context, state) =>
            const Scaffold(body: Text('Gelen kutusu açıldı')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: jobsProvider),
        ChangeNotifierProvider(
          create: (_) => UserProvider(
            userService: UserService.withClient(auxiliaryApi.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(
            service: NotificationService.withClient(auxiliaryApi.client),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    ),
  );
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  for (final brightness in Brightness.values) {
    group('BHomePage gelen kutusu girişi (${brightness.name})', () {
      testWidgets('Son Başvurular başlığındaki Tümünü Gör kutuyu açar', (
        tester,
      ) async {
        await _pumpHome(tester, brightness);

        final seeAll = find.byKey(const ValueKey('home-applications-see-all'));
        expect(seeAll, findsOneWidget);
        expect(
          find.descendant(of: seeAll, matching: find.text('Tümünü Gör')),
          findsOneWidget,
        );

        await tester.ensureVisible(seeAll);
        await tester.tap(seeAll);
        await tester.pumpAndSettle();

        expect(find.text('Gelen kutusu açıldı'), findsOneWidget);
      });

      testWidgets('Başvuru sayaç kartı da kutuyu açar', (tester) async {
        await _pumpHome(tester, brightness);

        // Sayı bütün başvuruları sayıyor; kart onların listesine götürüyor.
        final stat = find.byKey(const ValueKey('home-stat-Başvuru'));
        expect(stat, findsOneWidget);
        expect(
          find.descendant(of: stat, matching: find.text('4')),
          findsOneWidget,
        );

        await tester.tap(stat);
        await tester.pumpAndSettle();

        expect(find.text('Gelen kutusu açıldı'), findsOneWidget);
      });

      // Süslü bir `Container`'ın altında mürekkep görünmezdi: kart `Material` +
      // `InkWell`, ayrıca ekran okuyucuya düğme olarak tanıtılıyor.
      testWidgets('Başvuru sayaç kartı mürekkep verir ve düğme olarak okunur', (
        tester,
      ) async {
        await _pumpHome(tester, brightness);

        final stat = find.byKey(const ValueKey('home-stat-Başvuru'));
        expect(tester.widget(stat), isA<InkWell>());
        expect(
          find.ancestor(of: stat, matching: find.byType(Material)),
          findsWidgets,
        );
        expect(
          find.ancestor(
            of: stat,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.button == true &&
                  widget.properties.hint == 'Tüm başvuruları aç',
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('diğer sayaç kartları tıklanabilir değil', (tester) async {
        await _pumpHome(tester, brightness);

        expect(
          find.byKey(const ValueKey('home-stat-Aktif İlan')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('home-stat-Tamamlanan')),
          findsNothing,
        );
      });
    });
  }
}
