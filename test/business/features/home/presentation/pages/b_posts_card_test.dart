import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_posts_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_gate_test_support.dart';
import '../../../../../support/pump.dart';

const _category = {'id': 'category-1', 'code': 'BARISTA', 'name': 'Barista'};

const _openJob = {
  'id': 'job-open',
  'title': 'Barista',
  'salary': 1000,
  'status': 'OPEN',
  'applicationCount': 2,
  'headcount': 3,
  'hiredCount': 2,
  'startDateTime': '2026-09-10T09:00:00',
  'endDateTime': '2026-09-10T17:00:00',
  'companyName': 'Kahve Dünyası',
  'companyId': 'company-1',
  'category': _category,
};

const _closedJob = {
  'id': 'job-closed',
  'title': 'Garson',
  'salary': 900,
  'status': 'CLOSED',
  'headcount': 1,
  'hiredCount': 1,
  'startDateTime': '2026-09-01T09:00:00',
  'endDateTime': '2026-09-02T17:00:00',
  'category': _category,
};

const _cancelledJob = {
  'id': 'job-cancelled',
  'title': 'Komi',
  'salary': 700,
  'status': 'CANCELLED',
  'category': _category,
};

Future<void> _pumpPosts(
  WidgetTester tester, {
  required Brightness brightness,
  List<Map<String, dynamic>> companies = const [],
}) async {
  final api = FakeApi(
    handler: (request) {
      if (request.path == '/users/me') {
        return FakeApiResponse(
          statusCode: 200,
          body: employerMeResponse(
            identityVerified: true,
            companies: companies,
          ),
        );
      }
      if (request.path == '/users/me/jobs') {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [_openJob, _closedJob, _cancelledJob],
            },
          },
        );
      }
      return const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': []},
      );
    },
  );
  final jobsProvider = BJobsProvider(
    service: EmployerJobService.withClient(api.client),
  );
  final userProvider = UserProvider(
    userService: UserService.withClient(api.client),
  );
  await tester.runAsync(() async {
    await jobsProvider.load();
    await userProvider.load();
  });

  await pumpInApp(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: jobsProvider),
        ChangeNotifierProvider.value(value: userProvider),
      ],
      child: const BPostsPage(),
    ),
    brightness: brightness,
  );
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('aktif kartta kontenjan ve iş tarihi (${brightness.name})', (
      tester,
    ) async {
      await _pumpPosts(tester, brightness: brightness);

      final staffing = find.byKey(const ValueKey('post-staffing-job-open'));
      expect(staffing, findsOneWidget);
      expect(tester.widget<Text>(staffing).data, '2/3 dolu');

      final schedule = find.byKey(const ValueKey('post-schedule-job-open'));
      final start = DateTime.parse('2026-09-10T09:00:00');
      final end = DateTime.parse('2026-09-10T17:00:00');
      expect(
        tester.widget<Text>(schedule).data,
        '${start.asShortDateTime} - ${end.asShortTime}',
      );
      expect(find.text('Aktif'), findsOneWidget);
      // Tek şirketli/bireysel kullanıcıda şirket adı kartta yer kaplamıyor.
      expect(find.byKey(const ValueKey('post-company-job-open')), findsNothing);
    });
  }

  // "Geçmiş" sekmesinde kapalı ve iptal edilen ilan aynı şey değil; rozet
  // sunucudaki durumu yazıyor.
  testWidgets('geçmiş kartlarda kapalı ile iptal ayrı yazılır', (tester) async {
    await _pumpPosts(tester, brightness: Brightness.light);
    await tester.tap(find.text('Geçmiş (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Kapalı'), findsOneWidget);
    expect(find.text('İptal edildi'), findsOneWidget);
    expect(find.text('Geçmiş'), findsNothing);

    // Başka güne taşan işte iki tarih de tam.
    final schedule = find.byKey(const ValueKey('post-schedule-job-closed'));
    final start = DateTime.parse('2026-09-01T09:00:00');
    final end = DateTime.parse('2026-09-02T17:00:00');
    expect(
      tester.widget<Text>(schedule).data,
      '${start.asShortDateTime} - ${end.asShortDateTime}',
    );
    expect(find.text('1/1 dolu'), findsOneWidget);
    // Kontenjan ve tarih göndermeyen sunucuda satır hiç yok.
    expect(
      find.byKey(const ValueKey('post-staffing-job-cancelled')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('post-schedule-job-cancelled')),
      findsNothing,
    );
  });

  testWidgets('çok şirketli kullanıcıda kart şirket adını yazar', (
    tester,
  ) async {
    await _pumpPosts(
      tester,
      brightness: Brightness.dark,
      companies: const [
        {'companyId': 'company-1', 'companyName': 'Kahve Dünyası'},
        {'companyId': 'company-2', 'companyName': 'Çay Evi'},
      ],
    );

    final company = find.byKey(const ValueKey('post-company-job-open'));
    expect(company, findsOneWidget);
    expect(tester.widget<Text>(company).data, 'Kahve Dünyası');

    await tester.tap(find.text('Geçmiş (2)'));
    await tester.pumpAndSettle();
    // Şirketsiz açılmış ilan bireysel; çok şirketli kullanıcıda bu da bilgi.
    final individual = find.byKey(const ValueKey('post-company-job-closed'));
    expect(tester.widget<Text>(individual).data, 'Bireysel');
  });
}
