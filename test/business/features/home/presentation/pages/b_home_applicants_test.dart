import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_home_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const _job = {
  'id': 'job-1',
  'title': 'Barista',
  'salary': 1000,
  'status': 'OPEN',
  'applicationCount': 1,
  'category': {'id': 'category-1', 'code': 'BARISTA', 'name': 'Barista'},
};

const _applicant = {
  'id': 'application-1',
  'status': 'APPLIED',
  'applicationDateTime': '2026-09-08T10:00:00Z',
  'applicant': {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
};

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'son başvurular hatada kendi kendine tekrar etmez ve elle yenilenir '
      '(${brightness.name})',
      (tester) async {
        var applicantRequestCount = 0;
        final jobsApi = FakeApi(
          handler: (request) {
            if (request.path == '/users/me/jobs') {
              return const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [_job],
                  },
                },
              );
            }

            applicantRequestCount++;
            if (applicantRequestCount == 1) {
              return const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Son başvurular alınamadı'},
              );
            }
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [_applicant],
              },
            );
          },
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
        await pumpInApp(
          tester,
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
            child: const BHomePage(),
          ),
          brightness: brightness,
        );

        for (var index = 0; index < 20; index++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(applicantRequestCount, 1);
        expect(find.text('Son başvurular alınamadı'), findsOneWidget);
        expect(find.text('Henüz başvuru yok'), findsNothing);

        final retry = find.byKey(const ValueKey('recent-applicants-retry'));
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        for (var index = 0; index < 20; index++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(applicantRequestCount, 2);
        expect(find.text('Son başvurular alınamadı'), findsNothing);
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      },
    );
  }
}
