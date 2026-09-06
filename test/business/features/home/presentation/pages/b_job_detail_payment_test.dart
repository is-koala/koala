import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_job_detail_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/business/features/home/services/b_payment_browser.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/services/job_gallery_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const jobJson = {
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

const assignmentJson = {
  'id': 'assignment-1',
  'status': 'CONFIRMED',
  'paymentStatus': 'PENDING_COLLECTION',
  'workerPayout': 1000.10,
  'job': jobJson,
};

Future<({FakeApi employerApi, FakeApi paymentApi, int Function() launches})>
pumpPage(WidgetTester tester) async {
  final detailApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': jobJson},
    ),
  );
  final jobsApi = FakeApi(
    handler: (request) {
      if (request.path == '/users/me/jobs') {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [jobJson],
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
  final employerApi = FakeApi(
    handler: (request) {
      if (request.method == 'POST') {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'paymentPageUrl':
                  'https://sandbox-payment.iyzipay.com/checkoutform/token',
            },
          },
        );
      }
      return const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'content': [assignmentJson],
          },
        },
      );
    },
  );
  final assignmentApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );
  final paymentApi = FakeApi(
    handler: (request) {
      if (request.path == '/payment-quotes') {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'pricingVersion': 'v1',
              'currency': 'TRY',
              'workerPayout': '1000.10',
              'serviceFeeRate': '0.075',
              'serviceFeeAmount': '75.01',
              'employerTotal': '1075.11',
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
              'id': 'attempt-1',
              'status': 'FAILED',
              'currency': 'TRY',
              'workerPayout': '1000.10',
              'commissionAmount': '75.01',
              'commissionRate': '0.075',
              'totalCharged': '1075.11',
              'failureReason': 'Kart reddedildi.',
              'createdAt': '2026-09-06T12:00:00Z',
            },
          ],
        },
      );
    },
  );
  final galleryApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );
  var launchCount = 0;
  final browser = BPaymentBrowser(
    supportsMode: (_) async => true,
    launch: (_, _) async {
      launchCount++;
      return true;
    },
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
            service: BCompanyService.withClient(assignmentApi.client),
            companyService: CompanyService.withClient(assignmentApi.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(
            userService: UserService.withClient(assignmentApi.client),
          ),
        ),
      ],
      child: BJobDetailPage(
        jobId: 'job-1',
        jobService: JobService.withClient(detailApi.client),
        employerJobService: EmployerJobService.withClient(employerApi.client),
        assignmentService: AssignmentService.withClient(assignmentApi.client),
        paymentService: BPaymentService.withClient(paymentApi.client),
        paymentBrowser: browser,
        galleryProvider: JobGalleryProvider(
          service: JobGalleryService.withClient(galleryApi.client),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (
    employerApi: employerApi,
    paymentApi: paymentApi,
    launches: () => launchCount,
  );
}

void main() {
  testWidgets('başarısız ödeme denemesini sebebi ve tutarıyla gösterir', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Ödeme Denemeleri'), findsOneWidget);
    expect(find.text('Başarısız'), findsOneWidget);
    expect(find.text('1075.11'), findsOneWidget);
    expect(find.text('Kart reddedildi.'), findsOneWidget);
  });

  testWidgets('Iyzico yalnız backend dökümü açıkça onaylanınca açılır', (
    tester,
  ) async {
    final harness = await pumpPage(tester);
    final button = find.text('Güvenli Ödemeyi Tamamla');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ödemeyi Onayla'), findsOneWidget);
    expect(find.text('1000.10'), findsOneWidget);
    expect(find.text('75.01'), findsOneWidget);
    expect(find.text('1075.11'), findsWidgets);
    expect(
      harness.employerApi.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );
    expect(harness.launches(), 0);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(
      harness.employerApi.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ödemeye geç'));
    await tester.pumpAndSettle();

    expect(
      harness.employerApi.requests.where((request) => request.method == 'POST'),
      hasLength(1),
    );
    expect(harness.launches(), 1);
  });
}
