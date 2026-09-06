import 'dart:async';

import 'package:flutter/widgets.dart';
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

Future<({FakeApi employerApi, FakeApi paymentApi, int Function() launches})>
pumpPage(
  WidgetTester tester, {
  bool progressiveAttempt = false,
  String? activeAttemptStatus,
  bool openDispute = false,
  int disputeStatusCode = 200,
  Completer<FakeApiResponse>? disputeResponse,
  bool settle = true,
  List<Map<String, Object?>> assignments = const [assignmentJson],
  String failureReason = 'Kart reddedildi.',
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  return (
    employerApi: employerApi,
    paymentApi: paymentApi,
    launches: () => launchCount,
  );
}

void main() {
  testWidgets('başarısız ödeme denemesini güvenli açıklamayla gösterir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    expect(find.text('Ödeme Denemeleri'), findsOneWidget);
    expect(find.text('Başarısız'), findsOneWidget);
    expect(find.text('1.050,11 ₺'), findsOneWidget);
    expect(
      find.text('Ödeme tamamlanamadı. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    expect(find.text('Kart reddedildi.'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape('Kart reddedildi.'))),
      findsNothing,
    );
    semantics.dispose();
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
    expect(find.text('Çalışan Ücreti'), findsOneWidget);
    expect(find.text('Koala Hizmet Bedeli'), findsOneWidget);
    expect(find.text('(%5)'), findsOneWidget);
    expect(find.text('İşveren Toplamı'), findsOneWidget);
    expect(find.text('1.000,10 ₺'), findsOneWidget);
    expect(find.text('50,01 ₺'), findsOneWidget);
    expect(find.text('1.050,11 ₺'), findsWidgets);
    expect(
      harness.paymentApi.requests.where(
        (request) => request.path == '/payment-quotes',
      ),
      isEmpty,
    );
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

  testWidgets('bilinen güvenli hata anahtarını kullanıcıya açıklar', (
    tester,
  ) async {
    await pumpPage(tester, failureReason: '{payment.3ds.verification.failed}');

    expect(
      find.text('3D Secure doğrulaması tamamlanamadı. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    expect(find.text('{payment.3ds.verification.failed}'), findsNothing);
  });

  testWidgets(
    'checkout dönüşünde yeni aktif deneme görünür ve yeniden ödeme kapanır',
    (tester) async {
      final harness = await pumpPage(tester, progressiveAttempt: true);

      expect(find.text('Başarısız'), findsOneWidget);
      expect(find.text('Kart reddedildi.'), findsNothing);

      final button = find.text('Güvenli Ödemeyi Tamamla');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Ödemeye geç'));
      await tester.pumpAndSettle();

      expect(harness.launches(), 1);
      expect(find.text('Başarısız'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Başlatıldı'), findsOneWidget);
      expect(find.text('Ödeme sonucu doğrulanıyor.'), findsOneWidget);
      expect(find.text('Güvenli Ödemeyi Tamamla'), findsNothing);
      expect(find.text('Kart reddedildi.'), findsNothing);
    },
  );

  testWidgets('doğrulanan aktif deneme yeni checkout düğmesini kapatır', (
    tester,
  ) async {
    final harness = await pumpPage(
      tester,
      activeAttemptStatus: 'VERIFY_PENDING',
    );

    expect(find.text('Sonuç doğrulanıyor'), findsWidgets);
    expect(find.text('Ödeme sonucu doğrulanıyor.'), findsOneWidget);
    expect(find.text('Güvenli Ödemeyi Tamamla'), findsNothing);
    expect(harness.launches(), 0);
  });

  testWidgets('açık uyuşmazlık tamamlama ve iptali birlikte dondurur', (
    tester,
  ) async {
    await pumpPage(tester, openDispute: true);

    expect(find.textContaining('Emanetteki ücret'), findsOneWidget);
    expect(find.text('İşi Tamamla'), findsNothing);
    expect(find.text('İşi İptal Et'), findsNothing);
  });

  testWidgets('uyuşmazlık durumu alınamazsa finansal eylemler kapalı kalır', (
    tester,
  ) async {
    await pumpPage(tester, disputeStatusCode: 500);

    expect(find.text('Uyuşmazlık durumu doğrulanamadı.'), findsOneWidget);
    expect(find.text('İşi Tamamla'), findsNothing);
    expect(find.text('İşi İptal Et'), findsNothing);
    expect(find.text('Sorun Bildir'), findsNothing);
  });

  testWidgets('uyuşmazlık kontrolü sürerken finansal eylemler kapalı kalır', (
    tester,
  ) async {
    final response = Completer<FakeApiResponse>();
    await pumpPage(tester, disputeResponse: response, settle: false);

    expect(find.text('Uyuşmazlık durumu kontrol ediliyor.'), findsOneWidget);
    expect(find.text('İşi Tamamla'), findsNothing);
    expect(find.text('İşi İptal Et'), findsNothing);

    response.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': []},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uyuşmazlık durumu kontrol ediliyor.'), findsNothing);
    expect(find.text('İşi Tamamla'), findsOneWidget);
    expect(find.text('İşi İptal Et'), findsOneWidget);
  });

  testWidgets('çoklu ilanda çalışan açıkça seçilir ve ödeme hedefi değişir', (
    tester,
  ) async {
    final first = <String, Object?>{
      ...assignmentJson,
      'worker': {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Çalışan'},
    };
    final second = <String, Object?>{
      ...assignmentJson,
      'id': 'assignment-2',
      'worker': {'id': 'worker-2', 'firstName': 'Bora', 'lastName': 'Çalışan'},
    };
    final harness = await pumpPage(tester, assignments: [first, second]);

    final selector = find.byKey(const ValueKey('assignment-selector'));
    expect(selector, findsOneWidget);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bora Çalışan').last);
    await tester.pumpAndSettle();

    expect(
      harness.paymentApi.requests.any(
        (request) => request.path == '/job-assignments/assignment-2/payments',
      ),
      isTrue,
    );
  });
}
