import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_job_detail_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/business/features/home/services/b_payment_browser.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/services/job_gallery_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';
import '../../../../../support/review_fixtures.dart';

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
  'pricing': {
    'pricingVersion': 'assignment-v1',
    'currency': 'TRY',
    'workerPayout': '1000.10',
    'serviceFeeRate': '0.050',
    'serviceFeeAmount': '50.01',
    'employerTotal': '1050.11',
  },
  'job': jobJson,
};

FakeApiResponse assignmentPage(Map<String, Object?> assignment) =>
    FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'content': [assignment],
        },
      },
    );

Future<
  ({
    FakeApi assignmentApi,
    FakeApi employerApi,
    FakeApi paymentApi,
    FakeApi chatApi,
    FakeApi reviewApi,
    int Function() launches,
  })
>
pumpPage(
  WidgetTester tester, {
  bool progressiveAttempt = false,
  String? activeAttemptStatus,
  bool openDispute = false,
  int disputeStatusCode = 200,
  Completer<FakeApiResponse>? disputeResponse,
  bool settle = true,
  List<Map<String, Object?>> assignments = const [assignmentJson],
  List<Map<String, Object?>> applicants = const [],
  String failureReason = 'Kart reddedildi.',
  Brightness brightness = Brightness.light,
  Completer<FakeApiResponse>? jobsResponse,
  FutureOr<FakeApiResponse> Function(RequestOptions request)? employerHandler,
  FutureOr<FakeApiResponse> Function(RequestOptions request)? assignmentHandler,
  FutureOr<FakeApiResponse> Function(RequestOptions request)? paymentHandler,
  FutureOr<FakeApiResponse> Function(RequestOptions request)? chatHandler,
  FutureOr<FakeApiResponse> Function(RequestOptions request)? reviewHandler,
  Map<String, Object?>? currentUser,
  List<String> reviewedAssignmentIds = const [],
  String? reviewedAssignmentDetails,
  List<GoRoute> extraRoutes = const [],
  Future<bool> Function(Uri url)? openExternalUrl,
}) async {
  final detailApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': jobJson},
    ),
  );
  final jobsApi = FakeApi(
    handler: (request) {
      if (request.path == '/users/me/jobs') {
        if (jobsResponse != null) return jobsResponse.future;
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
      return FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': applicants},
      );
    },
  );
  final employerApi = FakeApi(
    handler: (request) {
      if (employerHandler != null) return employerHandler(request);
      if (request.method == 'POST') {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'paymentPageUrl':
                  'https://sandbox-cpp.iyzipay.com?token=token&lang=tr',
            },
          },
        );
      }
      return FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {'content': assignments},
        },
      );
    },
  );
  final assignmentApi = FakeApi(
    handler: (request) {
      if (request.path == '/users/me' && currentUser != null) {
        return FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': currentUser},
        );
      }
      if (assignmentHandler != null) return assignmentHandler(request);
      if (request.path.endsWith('/disputes') && disputeResponse != null) {
        return disputeResponse.future;
      }
      if (request.path.endsWith('/disputes') && disputeStatusCode != 200) {
        return FakeApiResponse(
          statusCode: disputeStatusCode,
          body: const {'success': false, 'message': 'Uyuşmazlıklar alınamadı.'},
        );
      }
      if (request.path.endsWith('/disputes') && openDispute) {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'dispute-1',
                'jobAssignmentId': 'assignment-1',
                'status': 'OPEN',
                'reason': 'Ücret uyuşmazlığı',
              },
            ],
          },
        );
      }
      return const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': []},
      );
    },
  );
  var paymentFetchCount = 0;
  final paymentApi = FakeApi(
    handler: (request) {
      if (paymentHandler != null) return paymentHandler(request);
      // Güncel tarife atamaya sabitlenmiş snapshot'tan bilerek farklı. Ödeme
      // onayı bu ucu çağırırsa toplam sessizce değişir ve test kırılmalıdır.
      if (request.path == '/payment-quotes') {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'pricingVersion': 'current-v2',
              'currency': 'TRY',
              'workerPayout': '1000.10',
              'serviceFeeRate': '0.075',
              'serviceFeeAmount': '75.01',
              'employerTotal': '1075.11',
            },
          },
        );
      }

      paymentFetchCount++;
      final isInitiated = progressiveAttempt && paymentFetchCount > 1;
      return FakeApiResponse(
        statusCode: 200,
        body: <String, dynamic>{
          'success': true,
          'data': [
            {
              'id': 'attempt-1',
              'status':
                  activeAttemptStatus ?? (isInitiated ? 'INITIATED' : 'FAILED'),
              'currency': 'TRY',
              'workerPayout': '1000.10',
              'commissionAmount': '50.01',
              'commissionRate': '0.050',
              'totalCharged': '1050.11',
              if (!isInitiated) 'failureReason': failureReason,
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
  final chatApi = FakeApi(
    handler: (request) =>
        chatHandler?.call(request) ??
        const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': {}},
        ),
  );
  // `ReviewProvider` kaydı oturum sahibinin kimliğiyle okuyor; sahte depo
  // burada dolduruluyor ki testler "başka cihazda değerlendirilmiş" hâli
  // kurabilsin. Anahtar `currentUser`'ın kimliğiyle ekleniyor.
  final reviewOwnerId = currentUser?['id'] as String?;
  SharedPreferences.setMockInitialValues({
    if (reviewOwnerId != null && reviewedAssignmentIds.isNotEmpty)
      'reviewed_assignments:$reviewOwnerId': reviewedAssignmentIds,
    if (reviewOwnerId != null && reviewedAssignmentDetails != null)
      'reviewed_assignment_details:$reviewOwnerId': reviewedAssignmentDetails,
  });
  // Değerlendirme: yazma `POST .../reviews`, kendi kaydını arama
  // `GET /users/{id}/reviews`. Varsayılan: boş sayfa, yazma 201.
  final reviewClient = FakeApi(
    handler: (request) =>
        reviewHandler?.call(request) ??
        (request.method == 'GET'
            ? reviewsPageResponse(const [])
            : reviewCreatedResponse(reviewDtoJson())),
  );
  // Sohbet açmak oturum sahibini istiyor; sayfa onu kendisi yüklemiyor.
  final userProvider = UserProvider(
    userService: UserService.withClient(assignmentApi.client),
  );
  if (currentUser != null) {
    await tester.runAsync(userProvider.load);
  }
  var launchCount = 0;
  final browser = BPaymentBrowser(
    supportsMode: (_) async => true,
    launch: (_, _) async {
      launchCount++;
      return true;
    },
  );

  final page = MultiProvider(
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
      ChangeNotifierProvider.value(value: userProvider),
      ChangeNotifierProvider(create: (_) => BTalentPoolProvider()),
      ChangeNotifierProvider(
        create: (_) => ReviewProvider(
          userIdOf: () => userProvider.user?.id,
          service: ReviewService.withClient(reviewClient.client),
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
      chatService: ChatService.withClient(chatApi.client),
      openExternalUrl: openExternalUrl,
    ),
  );
  if (extraRoutes.isEmpty) {
    await pumpInApp(tester, page, brightness: brightness);
  } else {
    // Sayfanın başka bir rotaya gittiğini sınayan testler için: sayfa kökte,
    // hedefler `extraRoutes`'ta. `pumpInApp` router taşımıyor.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => MaterialPage<void>(child: page),
        ),
        ...extraRoutes,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    );
  }
  // Post-frame yükleme dört async servis katmanından geçiyor. İlk istek ve
  // state yazımı tamamlanmadan `pumpAndSettle` erken dönebildiği için olay
  // döngüsünü deterministik biçimde ilerlet.
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  if (settle) {
    await tester.pumpAndSettle();
  }

  return (
    assignmentApi: assignmentApi,
    employerApi: employerApi,
    paymentApi: paymentApi,
    chatApi: chatApi,
    reviewApi: reviewClient,
    launches: () => launchCount,
  );
}
