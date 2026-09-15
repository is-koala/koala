import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_job_detail_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/services/job_gallery_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const _jobJson = {
  'id': 'job-1',
  'title': 'Barista',
  'category': {'id': 'category-1', 'code': 'BARISTA', 'name': 'Barista'},
  'type': 'ONE_TIME',
  'employerType': 'INDIVIDUAL',
  'salaryType': 'DAILY',
  'salary': 1000,
  'status': 'OPEN',
  'startDateTime': '2026-09-10T09:00:00Z',
  'endDateTime': '2026-09-10T17:00:00Z',
};

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakeApi jobsApi,
  required Brightness brightness,
}) async {
  final detailApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': _jobJson},
    ),
  );
  final emptyApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'content': []},
      },
    ),
  );
  final emptyListApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );
  // Planı olmayan ilan: ulaşım bölümü "plan ekle" düğmesine düşüyor.
  final noPlanApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 404,
      body: {
        'success': false,
        'message': 'Ulaşım planı bulunamadı.',
        'errorCategory': 'RESOURCE_NOT_FOUND',
        'errorCode': 'TRANSPORT_PLAN_NOT_FOUND',
      },
    ),
  );

  await pumpInApp(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BJobsProvider(
            service: EmployerJobService.withClient(jobsApi.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BCompanyProvider(
            service: BCompanyService.withClient(emptyApi.client),
            companyService: CompanyService.withClient(emptyApi.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(
            userService: UserService.withClient(emptyApi.client),
          ),
        ),
        ChangeNotifierProvider(create: (_) => BTalentPoolProvider()),
      ],
      child: BJobDetailPage(
        jobId: 'job-1',
        jobService: JobService.withClient(detailApi.client),
        employerJobService: EmployerJobService.withClient(emptyApi.client),
        assignmentService: AssignmentService.withClient(emptyListApi.client),
        galleryProvider: JobGalleryProvider(
          service: JobGalleryService.withClient(emptyListApi.client),
        ),
        transportService: TransportService.withClient(noPlanApi.client),
      ),
    ),
    brightness: brightness,
  );
  // Hatanın eski davranışında sayfa sonsuz bir yükleme halkası çiziyor;
  // `pumpAndSettle` bu yüzden hiçbir zaman bitmez. Ağ microtask'lerini sabit
  // sayıda frame ile ilerletip kullanıcıya görünen durumu doğrudan sınarız.
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('başvuru hatasını gösterir ve tekrar deneyince adayları çizer '
        '(${brightness.name})', (tester) async {
      var applicantRequestCount = 0;
      final jobsApi = FakeApi(
        handler: (request) {
          if (request.path == '/users/me/jobs') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [_jobJson],
                },
              },
            );
          }

          applicantRequestCount++;
          if (applicantRequestCount == 1) {
            return const FakeApiResponse(
              statusCode: 500,
              body: {'success': false, 'message': 'Başvuru listesi alınamadı'},
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [
                {
                  'id': 'application-1',
                  'status': 'APPLIED',
                  'applicationDateTime': '2026-09-08T10:00:00Z',
                  'applicant': {
                    'id': 'worker-1',
                    'firstName': 'Ayşe',
                    'lastName': 'Yılmaz',
                  },
                },
              ],
            },
          );
        },
      );
      await _pumpPage(tester, jobsApi: jobsApi, brightness: brightness);

      expect(find.text('Başvuru listesi alınamadı'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.text('Başvuranlar (0)'), findsNothing);
      expect(find.text('Henüz başvuru yok'), findsNothing);

      final retryButton = find.text('Tekrar Dene');
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(find.text('Başvuru listesi alınamadı'), findsNothing);
      expect(find.text('Tekrar Dene'), findsNothing);
      expect(find.text('Başvuranlar (1)'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    });

    testWidgets('doğrudan detayda ilan listesi hatasını yeniden dener '
        '(${brightness.name})', (tester) async {
      var listRequestCount = 0;
      final jobsApi = FakeApi(
        handler: (request) {
          if (request.path == '/users/me/jobs') {
            listRequestCount++;
            if (listRequestCount == 1) {
              return const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'İlan listesi alınamadı'},
              );
            }
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [_jobJson],
                },
              },
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [
                {
                  'id': 'application-1',
                  'status': 'APPLIED',
                  'applicationDateTime': '2026-09-08T10:00:00Z',
                  'applicant': {
                    'id': 'worker-1',
                    'firstName': 'Ayşe',
                    'lastName': 'Yılmaz',
                  },
                },
              ],
            },
          );
        },
      );
      await _pumpPage(tester, jobsApi: jobsApi, brightness: brightness);

      expect(find.text('İlan listesi alınamadı'), findsOneWidget);
      expect(find.byKey(const ValueKey('applicants-retry')), findsOneWidget);
      expect(find.text('Henüz başvuru yok'), findsNothing);

      final retryButton = find.byKey(const ValueKey('applicants-retry'));
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(listRequestCount, 2);
      expect(find.text('İlan listesi alınamadı'), findsNothing);
      expect(find.text('Başvuranlar (1)'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    });

    testWidgets('200 boş başvuru yanıtı gerçek boş durumu çizer '
        '(${brightness.name})', (tester) async {
      final jobsApi = FakeApi(
        handler: (request) {
          if (request.path == '/users/me/jobs') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [_jobJson],
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

      await _pumpPage(tester, jobsApi: jobsApi, brightness: brightness);

      expect(
        jobsApi.requests.map((request) => request.path),
        contains('/jobs/job-1/applications'),
      );
      expect(find.text('Başvuranlar (0)'), findsOneWidget);
      expect(find.text('Henüz başvuru yok'), findsOneWidget);
      expect(find.byKey(const ValueKey('applicants-retry')), findsNothing);
    });
  }
}
