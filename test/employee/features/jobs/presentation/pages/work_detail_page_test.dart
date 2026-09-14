import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/employer_type_badge.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/work_test_support.dart';

/// `GET /jobs/{id}` gövdesi; adres kesinliği ve ilanı açan taraf testin
/// verdiği hâlde.
Map<String, Object?> detailJson({
  String precision = 'APPROXIMATE',
  String? displayAddress,
  String? directions,
  Map<String, Object?>? creator,
  Map<String, Object?>? company,
  String employerType = 'INDIVIDUAL',
}) => {
  'id': 'job-1',
  'title': 'Barista',
  'description': 'Sabah vardiyası için barista.',
  'category': {'id': 'category-1', 'code': 'BARISTA', 'name': 'Barista'},
  'type': 'ONE_TIME',
  'employerType': employerType,
  'salaryType': 'DAILY',
  'salary': 1000,
  'status': 'OPEN',
  'addressPrecision': precision,
  'address': {
    'id': 'adr-1',
    'countryId': 'c-1',
    'countryName': 'Türkiye',
    'countryCode': 'TR',
    'cityId': 'ct-1',
    'cityName': 'İstanbul',
    'districtId': 'd-1',
    'districtName': 'Kadıköy',
    'displayAddress': ?displayAddress,
    if (directions != null)
      'components': {
        'neighborhood': 'Caferağa',
        'thoroughfare': 'Moda Cad.',
        'postalCode': '34710',
        'additionalDirections': directions,
      },
  },
  'creator': ?creator,
  'company': ?company,
};

const Map<String, Object?> _ayse = {
  'id': 'user-9',
  'firstName': 'Ayşe',
  'lastName': 'Yılmaz',
};

const Map<String, Object?> _koalaCafe = {
  'id': 'comp-7',
  'name': 'Koala Cafe',
  'logoUrl': 'https://cdn.example/logo.png',
};

MyJob assignmentRow(Map<String, Object?> body) =>
    MyJob.fromAssignment(Assignment.fromJson(body));

MyJob applicationRow(Map<String, Object?> body) =>
    MyJob.fromApplication(JobApplication.fromJson(body))!;

typedef Harness = ({
  FakeApi api,
  List<Object?> openedCompanies,
  List<Object?> openedReviews,
});

/// Sayfayı gerçek temada, sahte sunucuya bağlı çizer.
///
/// Tek bir sahte sunucu bütün uçları karşılıyor: ilan detayı, mesai
/// oturumları, iptal kaydı ve tekil atama. Şirket ve değerlendirme
/// rotaları sahte; yalnızca açılıp açılmadıkları ve `extra`'ları ölçülüyor.
Future<Harness> pumpDetail(
  WidgetTester tester, {
  required MyJob job,
  Map<String, Object?>? detail,
  List<Map<String, Object?>> sessions = const [],
  Map<String, Object?>? cancellation,
  Map<String, Object?>? refreshedAssignment,
  List<Map<String, Object?>> applications = const [],
  Map<String, FakeApiResponse Function(RequestOptions request)> overrides =
      const {},
  Brightness brightness = Brightness.light,
}) async {
  final openedCompanies = <Object?>[];
  final openedReviews = <Object?>[];

  final api = FakeApi(
    handler: (RequestOptions request) {
      final path = request.path;
      // Yol sonekine göre testin verdiği yanıt; eylem uçları buradan.
      for (final entry in overrides.entries) {
        if (path.endsWith(entry.key)) return entry.value(request);
      }
      if (path.startsWith('/jobs/')) {
        return detail == null
            ? const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'İlan okunamadı.'},
              )
            : dataResponse(detail);
      }
      if (path.endsWith('/work-sessions')) return dataResponse(sessions);
      if (path.endsWith('/cancellation')) return dataResponse(cancellation);
      if (path.endsWith('/respond')) {
        return dataResponse({'status': 'CONFIRMED'});
      }
      if (path.startsWith('/job-assignments/')) {
        return dataResponse(refreshedAssignment ?? assignmentJson());
      }
      if (path == '/users/me/applications') return pageResponse(applications);
      return pageResponse(const []);
    },
  );

  final userProvider = (await tester.runAsync(loadedWorkerProvider))!;
  addTearDown(userProvider.dispose);
  final queue = idleTimesheetQueue();

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: WorkDetailPage(
            job: job,
            assignmentService: AssignmentService.withClient(api.client),
            chatService: ChatService.withClient(api.client),
            jobService: JobService.withClient(api.client),
          ),
        ),
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
      GoRoute(
        path: '/review',
        pageBuilder: (context, state) {
          openedReviews.add(state.extra);
          return MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: Text('değerlendirme ekranı')),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: queue),
        ChangeNotifierProvider(
          create: (_) => ApplyProvider(
            service: JobApplicationService.withClient(api.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ReviewProvider(service: ReviewService.withClient(api.client)),
        ),
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await settle(tester);

  return (
    api: api,
    openedCompanies: openedCompanies,
    openedReviews: openedReviews,
  );
}

/// Yükleme birden çok async servis katmanından geçiyor; olay döngüsü sabit
/// sayıda kareyle ilerletiliyor (bkz. my_jobs_page_test).
Future<void> settle(WidgetTester tester) async {
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    group('İş detayı / ${brightness.name}', () {
      testWidgets('çizelge: bütün damgalar geldiğinde her satır çizilir', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              status: 'COMPLETED',
              paymentStatus: 'RELEASED_TO_WORKER',
              actualCompletionDateTime: '2026-09-10T17:00:00Z',
              extra: timelineFieldsJson,
            ),
          ),
          detail: detailJson(creator: _ayse),
          sessions: [workSessionJson()],
        );

        for (final label in [
          'Başvurdunuz',
          'İşveren sizi seçti',
          'İşi kabul ettiniz',
          'Ödeme emanete alındı',
          'Mesaiye başladınız',
          'Mesaiyi bitirdiniz',
          'İş tamamlandı',
          'Hakedişiniz ödendi',
        ]) {
          await tester.scrollUntilVisible(find.text(label), 200);
          expect(find.text(label), findsOneWidget, reason: label);
        }
        // Mesai süresi kapalı oturumun sunucu dakikasından.
        expect(find.text('7s 45dk'), findsOneWidget);
      });

      // Backend #282 gelmeden: yalnız mevcut damgalar, eksik satır gizli.
      testWidgets('çizelge: eski sunucuda yalnız mevcut damgalar', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              status: 'COMPLETED',
              paymentStatus: 'PENDING_COLLECTION',
              actualCompletionDateTime: '2026-09-10T17:00:00Z',
            ),
          ),
          detail: detailJson(creator: _ayse),
          sessions: [workSessionJson()],
        );

        for (final label in [
          'İşveren sizi seçti',
          'Mesaiye başladınız',
          'Mesaiyi bitirdiniz',
          'İş tamamlandı',
        ]) {
          await tester.scrollUntilVisible(find.text(label), 200);
          expect(find.text(label), findsOneWidget, reason: label);
        }
        for (final label in [
          'Başvurdunuz',
          'İşi kabul ettiniz',
          'Ödeme emanete alındı',
          'Hakedişiniz ödendi',
        ]) {
          expect(find.text(label), findsNothing, reason: label);
        }
      });

      testWidgets('bireysel işveren: ad ve rozet, şirket bağlantısı yok', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(assignmentJson()),
          detail: detailJson(creator: _ayse),
        );

        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is EmployerTypeBadge &&
                widget.type.displayName == 'Bireysel',
          ),
          findsWidgets,
        );
        expect(
          find.byKey(const ValueKey('employer-card-company')),
          findsNothing,
        );
      });

      testWidgets('şirket ilanı: ad, logo ve şirket sayfasına bağlantı', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              job: jobSummaryJson(
                employerType: 'COMPANY',
                companyName: 'Koala Cafe',
                companyId: 'comp-7',
              ),
              extra: const {'company': _koalaCafe},
            ),
          ),
          detail: detailJson(employerType: 'COMPANY', company: _koalaCafe),
        );

        expect(find.text('Koala Cafe'), findsOneWidget);
        expect(find.text('Kurumsal'), findsWidgets);
        final link = find.byKey(const ValueKey('employer-card-company'));
        expect(link, findsOneWidget);

        await tester.tap(link);
        await tester.pumpAndSettle();

        expect(harness.openedCompanies, ['comp-7']);
      });

      testWidgets('iptal kartı: kayıt sunucudan çekilir ve yazılır', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(status: 'CANCELLED', paymentStatus: 'REFUNDED'),
          ),
          detail: detailJson(creator: _ayse),
          cancellation: {
            'id': 'cnc-1',
            'jobAssignmentId': 'assignment-1',
            'cancelledByParty': 'EMPLOYER',
            'reason': 'Etkinlik ertelendi',
            'noticeMinutes': 300,
            'feeRate': '0.25',
            'feeAmount': '250.00',
            'refundAmount': '750.00',
            'cancelledAt': '2026-09-09T12:00:00Z',
          },
        );

        expect(
          harness.api.requests.map((request) => request.path),
          contains('/job-assignments/assignment-1/cancellation'),
        );
        final card = find.byKey(const ValueKey('cancellation-card'));
        await tester.scrollUntilVisible(card, 200);
        expect(card, findsOneWidget);
        Finder inCard(Finder finder) =>
            find.descendant(of: card, matching: finder);
        expect(inCard(find.text('İşveren iptal etti')), findsOneWidget);
        expect(inCard(find.text('"Etkinlik ertelendi"')), findsOneWidget);
        expect(
          inCard(find.textContaining('%25 kesinti uygulandı')),
          findsOneWidget,
        );
      });

      testWidgets('adres: EXACT ise açık adres ve tarif', (tester) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(assignmentJson()),
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy',
            directions: 'Eczanenin yanındaki kapı',
            creator: _ayse,
          ),
        );

        expect(find.text('Konum'), findsOneWidget);
        expect(
          find.text('Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy'),
          findsOneWidget,
        );
        expect(find.text('Tarif: Eczanenin yanındaki kapı'), findsOneWidget);
        expect(find.text('Yaklaşık konum'), findsNothing);
      });

      // Sunucu `APPROXIMATE` derken gövdede açık adres ve tarif gelse bile
      // çizilmemeli (ADR-0003): bayrak kesinliği, metin değil.
      testWidgets('adres: APPROXIMATE ise açık adres ve tarif gelse de yalnız '
          'ilçe', (tester) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: applicationRow(applicationJson()),
          detail: detailJson(
            precision: 'APPROXIMATE',
            displayAddress: 'Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy',
            directions: 'Eczanenin yanındaki kapı',
            creator: _ayse,
          ),
        );

        expect(find.text('Yaklaşık konum'), findsOneWidget);
        expect(find.text('Kadıköy/İstanbul'), findsOneWidget);
        expect(
          find.text('Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy'),
          findsNothing,
        );
        expect(find.textContaining('Tarif:'), findsNothing);
      });
    });
  }

  group('ödeme durumu metni', () {
    for (final (code, label) in const [
      ('PENDING_COLLECTION', 'Ödeme bekleniyor'),
      ('HELD_IN_ESCROW', 'Emanette'),
      ('RELEASED_TO_WORKER', 'Ödendi'),
      ('REFUNDED', 'İade edildi'),
    ]) {
      testWidgets('$code → "$label"', (tester) async {
        await pumpDetail(
          tester,
          job: assignmentRow(assignmentJson(paymentStatus: code)),
          detail: detailJson(creator: _ayse),
        );

        final status = find.byKey(const ValueKey('work-detail-payment-status'));
        await tester.scrollUntilVisible(status, 200);
        expect(tester.widget<Text>(status).data, label);
      });
    }

    testWidgets('başvuruda ödeme kartı yok', (tester) async {
      await pumpDetail(
        tester,
        job: applicationRow(applicationJson()),
        detail: detailJson(creator: _ayse),
      );

      expect(
        find.byKey(const ValueKey('work-detail-payment-status')),
        findsNothing,
      );
    });
  });

  group('eylemler', () {
    testWidgets('cevap bekleyen atamada kabul, sunucuya gider ve kaydı '
        'tazeler', (tester) async {
      final harness = await pumpDetail(
        tester,
        job: assignmentRow(
          assignmentJson(
            status: 'PENDING_CONFIRMATION',
            paymentStatus: 'PENDING_COLLECTION',
          ),
        ),
        detail: detailJson(creator: _ayse),
        refreshedAssignment: assignmentJson(
          status: 'CONFIRMED',
          paymentStatus: 'PENDING_COLLECTION',
        ),
      );

      expect(find.byKey(const ValueKey('work-detail-accept')), findsOneWidget);
      expect(find.byKey(const ValueKey('work-detail-reject')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('work-detail-accept')));
      await settle(tester);

      final paths = harness.api.requests.map((request) => request.path);
      expect(paths, contains('/job-assignments/assignment-1/respond'));
      expect(paths, contains('/job-assignments/assignment-1'));
      expect(find.text('Onaylandı'), findsOneWidget);
      expect(find.byKey(const ValueKey('work-detail-accept')), findsNothing);
    });

    testWidgets('süren işte mesai bitirme düğmesi ve başlangıç saati', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        job: assignmentRow(assignmentJson(status: 'IN_PROGRESS')),
        detail: detailJson(creator: _ayse),
        sessions: [workSessionJson(checkOutAt: null, minutes: null)],
      );

      expect(
        find.byKey(const ValueKey('work-detail-check-out')),
        findsOneWidget,
      );
      expect(find.textContaining("'de başladınız"), findsOneWidget);
    });

    testWidgets('onaylı işte ücret emanette değilse mesai düğmesi yok', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        job: assignmentRow(assignmentJson(paymentStatus: 'PENDING_COLLECTION')),
        detail: detailJson(creator: _ayse),
      );

      expect(find.byKey(const ValueKey('work-detail-check-in')), findsNothing);
      final status = find.byKey(const ValueKey('work-detail-payment-status'));
      await tester.scrollUntilVisible(status, 200);
      expect(tester.widget<Text>(status).data, 'Ödeme bekleniyor');
    });

    testWidgets('bekleyen başvuruda menüde geri çekme var', (tester) async {
      await pumpDetail(
        tester,
        job: applicationRow(applicationJson()),
        detail: detailJson(creator: _ayse),
      );

      await tester.tap(find.byKey(const ValueKey('work-detail-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Başvurumu Geri Çek'), findsOneWidget);
      expect(find.text('İşi İptal Et'), findsNothing);
    });

    testWidgets('tamamlanan işte değerlendirme düğmesi /review açar', (
      tester,
    ) async {
      final harness = await pumpDetail(
        tester,
        job: assignmentRow(
          assignmentJson(
            status: 'COMPLETED',
            paymentStatus: 'RELEASED_TO_WORKER',
          ),
        ),
        detail: detailJson(creator: _ayse),
      );

      final button = find.byKey(const ValueKey('work-detail-review'));
      await tester.scrollUntilVisible(button, 200);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(harness.openedReviews, hasLength(1));
      final subject = harness.openedReviews.single as ReviewSubject;
      expect(subject.assignmentId, 'assignment-1');
      expect(subject.side, ReviewSide.worker);
    });

    testWidgets('mesaj kapısı kapalıysa düğme yerine sebep', (tester) async {
      await pumpDetail(
        tester,
        job: assignmentRow(
          assignmentJson(
            paymentStatus: 'PENDING_COLLECTION',
            messagingAvailable: false,
            messagingAvailableReason: 'PAYMENT_REQUIRED',
          ),
        ),
        detail: detailJson(creator: _ayse),
      );

      expect(find.byKey(const ValueKey('work-detail-chat')), findsNothing);
      final note = find.byKey(const ValueKey('work-detail-chat-note'));
      await tester.scrollUntilVisible(note, 200);
      expect(note, findsOneWidget);
    });

    testWidgets('ilan detayı çekilemezse sayfa çalışır, şerit çıkar', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        job: assignmentRow(assignmentJson()),
        detail: null,
      );

      expect(find.textContaining('İlan bilgileri alınamadı'), findsOneWidget);
      expect(find.text('Barista'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Kadıköy/İstanbul'), 200);
      expect(find.text('Kadıköy/İstanbul'), findsOneWidget);
    });
  });

  // Eylemler `WorkActionsPagemodel`'den geliyor; sayfa onları doğru
  // bağlamış mı ve sonucu doğru okuyor mu — diyalog → istek → tazeleme.
  group('eylem akışları', () {
    const conflict = FakeApiResponse(
      statusCode: 409,
      body: {
        'success': false,
        'message': 'Atama bu durumdan cevaplanamaz.',
        'errorCategory': 'DATA_CONFLICT',
        'errorCode': 'ASSIGNMENT_ALREADY_ANSWERED',
      },
    );

    Iterable<String> pathsOf(Harness harness) =>
        harness.api.requests.map((request) => request.path);

    testWidgets('reddet: onay kutusu, /respond accepted=false, tazeleme', (
      tester,
    ) async {
      final harness = await pumpDetail(
        tester,
        job: assignmentRow(
          assignmentJson(
            status: 'PENDING_CONFIRMATION',
            paymentStatus: 'PENDING_COLLECTION',
          ),
        ),
        detail: detailJson(creator: _ayse),
        refreshedAssignment: assignmentJson(
          status: 'REJECTED',
          paymentStatus: 'PENDING_COLLECTION',
        ),
        overrides: {
          '/respond': (_) => dataResponse({'status': 'REJECTED'}),
        },
      );

      await tester.tap(find.byKey(const ValueKey('work-detail-reject')));
      await tester.pumpAndSettle();
      expect(find.text('İşi reddet'), findsOneWidget);
      expect(find.textContaining('size kapanır'), findsOneWidget);

      // Kutunun kendi "Reddet"i; sayfadaki düğme kutunun altında kaldı.
      await tester.tap(find.widgetWithText(TextButton, 'Reddet'));
      await settle(tester);

      final respond = harness.api.requests.singleWhere(
        (request) => request.path.endsWith('/respond'),
      );
      expect(respond.data, {'accepted': false});
      expect(find.text('İşi reddettiniz'), findsOneWidget);
      expect(pathsOf(harness), contains('/job-assignments/assignment-1'));
      expect(find.text('Reddedildi'), findsOneWidget);
      expect(find.byKey(const ValueKey('work-detail-accept')), findsNothing);
    });

    testWidgets('kabulde 409: sunucu mesajı ve kayıt yeniden okunur', (
      tester,
    ) async {
      final harness = await pumpDetail(
        tester,
        job: assignmentRow(
          assignmentJson(
            status: 'PENDING_CONFIRMATION',
            paymentStatus: 'PENDING_COLLECTION',
          ),
        ),
        detail: detailJson(creator: _ayse),
        refreshedAssignment: assignmentJson(
          status: 'CANCELLED',
          paymentStatus: 'REFUNDED',
        ),
        overrides: {'/respond': (_) => conflict},
      );
      final refreshesBefore = pathsOf(
        harness,
      ).where((path) => path == '/job-assignments/assignment-1').length;

      await tester.tap(find.byKey(const ValueKey('work-detail-accept')));
      await settle(tester);

      expect(find.text('Atama bu durumdan cevaplanamaz.'), findsOneWidget);
      expect(
        pathsOf(
          harness,
        ).where((path) => path == '/job-assignments/assignment-1').length,
        greaterThan(refreshesBefore),
      );
      expect(find.text('İptal Edildi'), findsOneWidget);
    });

    testWidgets('iptal: önizleme cancellableNow=false ise kutu açılmaz', (
      tester,
    ) async {
      final harness = await pumpDetail(
        tester,
        job: assignmentRow(assignmentJson()),
        detail: detailJson(creator: _ayse),
        overrides: {
          '/cancellation-preview': (_) => dataResponse({
            'feeRate': '0',
            'feeAmount': '0',
            'refundAmount': '1000.00',
            'noticeMinutes': -30,
            'cancellableNow': false,
          }),
        },
      );

      await tester.tap(find.byKey(const ValueKey('work-detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İşi İptal Et'));
      await settle(tester);

      expect(
        pathsOf(harness),
        contains('/job-assignments/assignment-1/cancellation-preview'),
      );
      expect(find.text('Bu iş artık iptal edilemez'), findsOneWidget);
      expect(find.text('İşi iptal et'), findsNothing);
      expect(
        pathsOf(harness).where((path) => path.endsWith('/cancel')),
        isEmpty,
      );
    });

    testWidgets('iptal: gerekçe kutusu, POST /cancel, sonuç toast', (
      tester,
    ) async {
      final harness = await pumpDetail(
        tester,
        job: assignmentRow(assignmentJson()),
        detail: detailJson(creator: _ayse),
        refreshedAssignment: assignmentJson(
          status: 'CANCELLED',
          paymentStatus: 'REFUNDED',
        ),
        overrides: {
          '/cancellation-preview': (_) => dataResponse({
            'feeRate': '0',
            'feeAmount': '0',
            'refundAmount': '1000.00',
            'noticeMinutes': 300,
            'cancellableNow': true,
          }),
          '/cancel': (_) => dataResponse({
            'id': 'cnc-1',
            'jobAssignmentId': 'assignment-1',
            'cancelledByParty': 'WORKER',
            'reason': 'Hastalandım',
            'feeRate': '0',
            'feeAmount': '0',
            'refundAmount': '1000.00',
            'cancelledAt': '2026-09-09T12:00:00Z',
          }),
        },
      );

      await tester.tap(find.byKey(const ValueKey('work-detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İşi İptal Et'));
      await settle(tester);

      expect(find.text('İşi iptal et'), findsOneWidget);
      expect(
        find.textContaining('sizden kesinti yapılmayacak'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Hastalandım');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'İptal Et'));
      await settle(tester);

      final cancel = harness.api.requests.singleWhere(
        (request) => request.path.endsWith('/cancel'),
      );
      expect(cancel.data, {'reason': 'Hastalandım'});
      // Toast ve tazelenen kaydın çizelge satırı aynı metni taşıyor.
      expect(find.text('İş iptal edildi'), findsWidgets);
      expect(find.text('İptal Edildi'), findsOneWidget);
    });

    testWidgets('başvuruyu geri çek: onay, POST /withdraw, satır güncellenir', (
      tester,
    ) async {
      final harness = await pumpDetail(
        tester,
        job: applicationRow(applicationJson()),
        detail: detailJson(creator: _ayse),
        overrides: {
          '/withdraw': (_) => dataResponse({
            'id': 'application-1',
            'status': 'WITHDRAWN',
            'job': {'id': 'job-2', 'title': 'Garson'},
          }),
        },
        applications: [applicationJson()],
      );
      // Provider listeyi ilk çağrıda çekmiş olmalı ki geri çekme satırı
      // yerinde güncelleyebilsin; sayfa açılışta yüklemiyor.
      await tester.runAsync(
        () => tester
            .element(find.byType(WorkDetailPage))
            .read<ApplyProvider>()
            .load(),
      );
      await settle(tester);
      final loadsBefore = pathsOf(
        harness,
      ).where((path) => path == '/users/me/applications').length;

      await tester.tap(find.byKey(const ValueKey('work-detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Başvurumu Geri Çek'));
      await tester.pumpAndSettle();
      expect(find.text('Başvurunuzu geri çekin'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Geri Çek'));
      await settle(tester);

      expect(
        pathsOf(harness),
        contains('/job-applications/application-1/withdraw'),
      );
      expect(find.text('Başvurunuz geri çekildi'), findsOneWidget);
      expect(find.text('Geri Çektin'), findsOneWidget);
      // Provider satırı yerinde güncelledi; ikinci bir liste yüklemesi yok.
      expect(
        pathsOf(harness).where((path) => path == '/users/me/applications'),
        hasLength(loadsBefore),
      );
      expect(find.byKey(const ValueKey('work-detail-menu')), findsNothing);
    });
  });
}
