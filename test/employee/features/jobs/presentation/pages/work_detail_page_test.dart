import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/employer_type_badge.dart';
import 'package:koala/employee/core/widgets/job_location_card.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/work_transport_card.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/review_fixtures.dart';
import '../../../../../support/transport_fixtures.dart';
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
  Map<String, Object?>? position,
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
    'position': ?position,
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
  List<Uri> openedUrls,
});

/// Moda'nın koordinatı; `EXACT` detayın `address.position` alanı.
const Map<String, Object?> _modaPosition = {
  'latitude': 40.98765432,
  'longitude': 29.02612345,
  'source': 'USER_CONFIRMED_PIN',
};

/// Detaydaki Moda koordinatının bağlantıya yazılan hâli.
const String _modaCoordinate = '40.987654,29.026123';

/// "Yol tarifi al" düğmesi.
final _directionsButton = find.byKey(const ValueKey('job-location-directions'));

/// Onaylı, ödemesi henüz alınmamış atama: alt çubuk yok, kart tıklanabilir
/// (600 px'lik test penceresinde alt çubuk kartın üstüne biniyordu).
final MyJob _confirmedRow = assignmentRow(
  assignmentJson(paymentStatus: 'PENDING_COLLECTION'),
);

/// Özetinde koordinat taşıyan atama; `JobSummaryDto.latitude/longitude`
/// detaydan farklı ki bağlantının hangisini taşıdığı ayırt edilsin.
MyJob _rowWithSummaryCoordinate(String precision) => assignmentRow(
  assignmentJson(
    paymentStatus: 'PENDING_COLLECTION',
    job: jobSummaryJson()
      ..['latitude'] = 41.0
      ..['longitude'] = 29.0
      ..['addressPrecision'] = precision,
  ),
);

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
  bool Function(Uri url)? openUrl,
  Map<String, Object?>? transport,
  bool seatDropped = false,
}) async {
  final openedCompanies = <Object?>[];
  final openedReviews = <Object?>[];
  final openedUrls = <Uri>[];

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
      // Ulaşım görünümü: verilmediyse planı olmayan ilan (`404`).
      if (path.endsWith('/transport')) {
        return transport == null
            ? const FakeApiResponse(
                statusCode: 404,
                body: {
                  'success': false,
                  'message': 'Ulaşım planı bulunamadı.',
                  'errorCategory': 'RESOURCE_NOT_FOUND',
                  'errorCode': 'TRANSPORT_PLAN_NOT_FOUND',
                },
              )
            : dataResponse(transport);
      }
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
            transportService: TransportService.withClient(api.client),
            seatDropped: seatDropped,
            openExternalUrl: (url) async {
              openedUrls.add(url);
              return openUrl?.call(url) ?? true;
            },
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
    openedUrls: openedUrls,
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

  // is-koala/koala#188: yol tarifi yalnız EXACT'te; hedef koordinat
  // bağlantıda, kullanıcının konumu değil.
  for (final brightness in Brightness.values) {
    group('yol tarifi / ${brightness.name}', () {
      testWidgets('EXACT + koordinat: düğme ve başlangıç notu var', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy',
            position: _modaPosition,
            creator: _ayse,
          )..['startDateTime'] = '2026-09-10T09:00:00',
        );

        expect(_directionsButton, findsOneWidget);
        expect(find.text('Yol tarifi al'), findsOneWidget);
        expect(
          find.text(JobLocationCard.directionsNote(DateTime(2026, 9, 10, 9))),
          findsOneWidget,
        );
      });

      testWidgets('APPROXIMATE: koordinat gelse de düğme yok', (tester) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: applicationRow(applicationJson()),
          detail: detailJson(
            precision: 'APPROXIMATE',
            displayAddress: 'Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy',
            position: _modaPosition,
            creator: _ayse,
          ),
        );

        expect(_directionsButton, findsNothing);
        expect(find.text('Yol tarifi al'), findsNothing);
      });

      // Detay `EXACT` ama `address.position` göndermiyor: koordinat özetten.
      testWidgets('EXACT + detayda koordinat yok: özetin EXACT koordinatı', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _rowWithSummaryCoordinate('EXACT'),
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            creator: _ayse,
          ),
        );

        expect(_directionsButton, findsOneWidget);
        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pumpAndSettle();

        expect(
          harness.openedUrls.single.queryParameters['destination'],
          '41.000000,29.000000',
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      // Sızıntı kilidi: detay `EXACT` derken özet `APPROXIMATE` — özetin
      // koordinatı yuvarlanmış; ona rota, olmayan bir kapıya götürür.
      testWidgets(
        'EXACT + detayda koordinat yok + özet APPROXIMATE: düğme yok',
        (tester) async {
          await pumpDetail(
            tester,
            brightness: brightness,
            job: _rowWithSummaryCoordinate('APPROXIMATE'),
            detail: detailJson(
              precision: 'EXACT',
              displayAddress: 'Moda',
              creator: _ayse,
            ),
          );

          expect(_directionsButton, findsNothing);
        },
      );

      testWidgets('EXACT ama koordinat yok: düğme yok', (tester) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy',
            creator: _ayse,
          ),
        );

        expect(_directionsButton, findsNothing);
      });

      testWidgets('Android: seçim yok, doğrudan Google web bağlantısı', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            position: _modaPosition,
            creator: _ayse,
          ),
        );

        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pumpAndSettle();

        expect(find.text('Yol tarifini nerede açalım?'), findsNothing);
        expect(harness.openedUrls.map((url) => url.toString()), [
          'https://www.google.com/maps/dir/?api=1'
              '&destination=$_modaCoordinate&travelmode=transit',
        ]);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('iOS: seçim sayfası; Apple Haritalar maps:// açar', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            position: _modaPosition,
            creator: _ayse,
          ),
        );

        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pumpAndSettle();

        expect(find.text('Yol tarifini nerede açalım?'), findsOneWidget);
        expect(find.text('Apple Haritalar'), findsOneWidget);
        expect(find.text('Google Haritalar'), findsOneWidget);
        expect(harness.openedUrls, isEmpty);

        await tester.tap(find.text('Apple Haritalar'));
        await tester.pumpAndSettle();

        expect(harness.openedUrls.map((url) => url.toString()), [
          'maps://?daddr=$_modaCoordinate&dirflg=r',
        ]);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('iOS: Google uygulaması yoksa web bağlantısına düşer', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            position: _modaPosition,
            creator: _ayse,
          ),
          openUrl: (url) => url.scheme != 'comgooglemaps',
        );

        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Google Haritalar'));
        await tester.pumpAndSettle();

        expect(harness.openedUrls.map((url) => url.toString()), [
          'comgooglemaps://?daddr=$_modaCoordinate&directionsmode=transit',
          'https://www.google.com/maps/dir/?api=1'
              '&destination=$_modaCoordinate&travelmode=transit',
        ]);
        expect(find.text('Harita uygulaması açılamadı'), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      // Android'de işleyicisi olmayan şema `PlatformException` fırlatıyor;
      // yedek bağlantıya geçiş bunu da "açılamadı" saymalı.
      testWidgets('iOS: Google uygulaması PlatformException fırlatırsa web '
          'yedeği', (tester) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            position: _modaPosition,
            creator: _ayse,
          ),
          openUrl: (url) {
            if (url.scheme == 'comgooglemaps') {
              throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
            }
            return true;
          },
        );

        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Google Haritalar'));
        await tester.pumpAndSettle();

        expect(harness.openedUrls.map((url) => url.scheme), [
          'comgooglemaps',
          'https',
        ]);
        expect(find.text('Harita uygulaması açılamadı'), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('iOS: Google uygulaması varsa web bağlantısı açılmaz', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            position: _modaPosition,
            creator: _ayse,
          ),
        );

        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Google Haritalar'));
        await tester.pumpAndSettle();

        expect(harness.openedUrls.map((url) => url.scheme), ['comgooglemaps']);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('hiçbir bağlantı açılamazsa toast', (tester) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            position: _modaPosition,
            creator: _ayse,
          ),
          openUrl: (_) => false,
        );

        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Harita uygulaması açılamadı'), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      // Kullanıcının konumu hiçbir bağlantıya yazılmıyor; bağlantı yalnız
      // sunucunun verdiği hedefi taşıyor.
      testWidgets('bağlantıda başlangıç noktası yok', (tester) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(
            precision: 'EXACT',
            displayAddress: 'Moda',
            position: _modaPosition,
            creator: _ayse,
          ),
        );

        await tester.ensureVisible(_directionsButton);
        await tester.tap(_directionsButton);
        await tester.pumpAndSettle();

        final url = harness.openedUrls.single;
        expect(url.queryParameters.keys, isNot(contains('origin')));
        expect(url.queryParameters.keys, isNot(contains('saddr')));
        expect(url.queryParameters['destination'], _modaCoordinate);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
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

  // Değerlendirme durumu sunucudan (`myReview`, `counterpartyReviewed`;
  // is-koala/koala#189). Cihazda kayıt yok, `GET /users/{id}/reviews`e
  // gidilmiyor.
  for (final brightness in Brightness.values) {
    group('değerlendirme durumu / ${brightness.name}', () {
      final button = find.byKey(const ValueKey('work-detail-review'));
      final badge = find.byKey(const ValueKey('review-counterparty-badge'));

      testWidgets('myReview dolu: içerik yazılır, düğme yok', (tester) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              status: 'COMPLETED',
              paymentStatus: 'RELEASED_TO_WORKER',
              extra: {
                'myReview': myReviewJson(rating: 4, comment: 'Dakik'),
                'counterpartyReviewed': false,
              },
            ),
          ),
          detail: detailJson(creator: _ayse),
        );

        final text = find.text('Değerlendirdiniz: ★4 · "Dakik"');
        await tester.scrollUntilVisible(text, 200);
        expect(text, findsOneWidget);
        expect(button, findsNothing);
        expect(badge, findsNothing);
        expect(
          harness.api.requests.map((request) => request.path),
          isNot(contains(contains('/reviews'))),
        );
      });

      testWidgets('myReview null: düğme var, karşı taraf rozeti var', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              status: 'COMPLETED',
              paymentStatus: 'HELD_IN_ESCROW',
              extra: {'myReview': null, 'counterpartyReviewed': true},
            ),
          ),
          detail: detailJson(creator: _ayse),
        );

        await tester.scrollUntilVisible(button, 200);
        expect(button, findsOneWidget);
        expect(find.text('İşvereni henüz değerlendirmediniz.'), findsOneWidget);
        expect(badge, findsOneWidget);
        expect(find.text('Karşı taraf sizi değerlendirdi'), findsOneWidget);
      });

      // Oturum belleği iki fetch arasındaki boşluğu kapatıyor: gönderim
      // biter bitmez satır döner; yeniden çekimde sunucunun `myReview`'ı esas.
      testWidgets('POST sonrası satır anında döner, yeniden çekimde sunucu '
          'esas', (tester) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              status: 'COMPLETED',
              paymentStatus: 'RELEASED_TO_WORKER',
              extra: {'myReview': null, 'counterpartyReviewed': false},
            ),
          ),
          detail: detailJson(creator: _ayse),
          refreshedAssignment: assignmentJson(
            status: 'COMPLETED',
            paymentStatus: 'RELEASED_TO_WORKER',
            extra: {
              'myReview': myReviewJson(rating: 3, comment: 'Sunucudan'),
              'counterpartyReviewed': true,
            },
          ),
          overrides: {
            '/reviews': (_) => reviewCreatedResponse(
              reviewDtoJson(
                rating: 5,
                comment: 'Harika',
                jobAssignmentId: 'assignment-1',
              ),
            ),
          },
        );

        await tester.scrollUntilVisible(button, 200);
        expect(button, findsOneWidget);

        final provider = tester.element(button).read<ReviewProvider>();
        // Sahte HTTP gerçek olay döngüsünde; test zamanında beklense
        // tamamlanmaz.
        final sent = await tester.runAsync(
          () => provider.submitReview(
            assignmentId: 'assignment-1',
            rating: 5,
            comment: 'Harika',
          ),
        );
        await tester.pumpAndSettle();

        expect(sent, isTrue);
        expect(find.text('Değerlendirdiniz: ★5 · "Harika"'), findsOneWidget);
        expect(button, findsNothing);
        expect(badge, findsNothing);

        // Aşağı çekince atama yeniden okunuyor (`GET /job-assignments/{id}`);
        // sunucunun kaydı oturumdakinin önüne geçiyor, rozet de geliyor.
        // Liste aşağı kaydırılmış durumda; jest yerine göstergenin kendisi
        // tetikleniyor, aynı `onRefresh` çalışıyor.
        unawaited(
          tester
              .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
              .show(),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await settle(tester);

        expect(
          harness.api.requests.map((request) => request.path),
          contains('/job-assignments/assignment-1'),
        );
        expect(find.text('Değerlendirdiniz: ★3 · "Sunucudan"'), findsOneWidget);
        expect(find.text('Değerlendirdiniz: ★5 · "Harika"'), findsNothing);
        expect(badge, findsOneWidget);
      });

      // Eski sunucu alanları göndermiyor: düğme görünür, rozet yok.
      testWidgets('eski sunucu: düğme var, rozet yok', (tester) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              status: 'COMPLETED',
              paymentStatus: 'RELEASED_TO_WORKER',
            ),
          ),
          detail: detailJson(creator: _ayse),
        );

        await tester.scrollUntilVisible(button, 200);
        expect(button, findsOneWidget);
        expect(badge, findsNothing);
      });
    });

    // Çalışan yalnız kendi kazancını görür (is-koala/koala#189 B). Sunucu
    // `pricing`i artık göndermiyor; gönderse de (eski sunucu) hizmet bedeli
    // ve işveren toplamı çizilmiyor.
    group('kazanç kartı / ${brightness.name}', () {
      testWidgets('pricing null: yalnız "Kazancınız" ve workerPayout', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow({
            ...assignmentJson(status: 'COMPLETED'),
            'pricing': null,
            'totalCharged': null,
          }),
          detail: detailJson(creator: _ayse),
        );

        expect(find.text('Kazancınız'), findsOneWidget);
        expect(find.text('950,00 ₺'), findsOneWidget);
        expect(find.textContaining('Hizmet bedeli'), findsNothing);
        expect(find.textContaining('İşverenin ödediği'), findsNothing);
        expect(find.text('1.000,00 ₺'), findsNothing);
      });

      testWidgets('pricing gelse de komisyon satırları çizilmez', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(assignmentJson(status: 'COMPLETED')),
          detail: detailJson(creator: _ayse),
        );

        expect(find.text('Kazancınız'), findsOneWidget);
        expect(find.text('950,00 ₺'), findsOneWidget);
        expect(find.textContaining('Hizmet bedeli'), findsNothing);
        expect(find.textContaining('İşverenin ödediği'), findsNothing);
        expect(find.text('50,00 ₺'), findsNothing);
        expect(find.text('1.000,00 ₺'), findsNothing);
      });
    });

    group('ulaşım kartı / ${brightness.name}', () {
      final selectOutbound = find.byKey(
        const ValueKey('work-transport-select-OUTBOUND'),
      );
      final seatRow = find.byKey(const ValueKey('seat-picker-stop-stop-1'));
      final card = find.byKey(const ValueKey('work-transport-card'));

      testWidgets('plan yoksa (404) kart çizilmez', (tester) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(creator: _ayse),
        );

        expect(card, findsNothing);
      });

      testWidgets('eski sunucu: görünüm ucu atamayı döndürse de kart yok', (
        tester,
      ) async {
        // Eski sunucu `/transport` yolunu tanımıyor; yanıt yöntemsiz.
        await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(creator: _ayse),
          overrides: {'/transport': (_) => dataResponse(assignmentJson())},
        );

        expect(card, findsNothing);
      });

      testWidgets('koltuk seçimi 200: sunucunun görünümü karta yazılır', (
        tester,
      ) async {
        final seatRequests = <Object?>[];
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(creator: _ayse),
          transport: assignmentTransportJson(),
          overrides: {
            '/transport/seat': (request) {
              seatRequests.add(request.data);
              return dataResponse(assignmentTransportJson(seats: [seatJson()]));
            },
          },
        );

        await tester.scrollUntilVisible(card, 200);
        expect(find.text('Henüz koltuk seçmediniz.'), findsOneWidget);
        expect(find.text('Plaka: 34 ABC 12'), findsNothing);

        await tester.scrollUntilVisible(selectOutbound, 200);
        await tester.pumpAndSettle();
        await tester.tap(selectOutbound);
        await tester.pumpAndSettle();
        expect(find.text('Gidiş için koltuk seçin'), findsOneWidget);

        await tester.tap(seatRow);
        await settle(tester);

        expect(seatRequests, [
          {'shuttleId': 'shuttle-1', 'stopId': 'stop-1'},
        ]);
        expect(
          harness.api.requests
              .where((r) => r.path.endsWith('/transport/seat'))
              .single
              .method,
          'PUT',
        );
        expect(find.text('Koltuk seçiminiz kaydedildi.'), findsOneWidget);
        expect(find.text('Plaka: 34 ABC 12'), findsOneWidget);
        expect(find.text('Şoför: Mehmet Usta'), findsOneWidget);
        expect(find.text('Değiştir'), findsOneWidget);
      });

      testWidgets(
        'koltuk seçimi 409: sunucu mesajı ve görünüm yeniden okunur',
        (tester) async {
          var transportReads = 0;
          final harness = await pumpDetail(
            tester,
            brightness: brightness,
            job: _confirmedRow,
            detail: detailJson(creator: _ayse),
            overrides: {
              '/transport/seat': (_) => const FakeApiResponse(
                statusCode: 409,
                body: {
                  'success': false,
                  'message': 'Servisin kapasitesi dolu.',
                  'errorCategory': 'DATA_CONFLICT',
                  'errorCode': 'TRANSPORT_SHUTTLE_FULL',
                },
              ),
              '/transport': (_) {
                transportReads++;
                // İlk okuma boş servis; ikincisi (409 sonrası) dolu servis.
                return dataResponse(
                  assignmentTransportJson(
                    shuttles: [
                      shuttleJson(
                        capacity: 4,
                        seatsTaken: transportReads == 1 ? 3 : 4,
                      ),
                    ],
                  ),
                );
              },
            },
          );

          await tester.scrollUntilVisible(selectOutbound, 200);
          await tester.pumpAndSettle();
          await tester.tap(selectOutbound);
          await tester.pumpAndSettle();
          await tester.tap(seatRow);
          await settle(tester);

          expect(find.text('Servisin kapasitesi dolu.'), findsOneWidget);
          expect(transportReads, 2);
          expect(find.text('Henüz koltuk seçmediniz.'), findsOneWidget);
          expect(
            harness.api.requests.where((r) => r.path.endsWith('/seat')),
            hasLength(1),
          );

          // Yeniden okunan görünümde servis dolu: seçici artık dokundurmuyor.
          await tester.scrollUntilVisible(selectOutbound, 200);
          await tester.pumpAndSettle();
          await tester.tap(selectOutbound);
          await tester.pumpAndSettle();
          expect(find.text('Dolu · 4/4 dolu'), findsOneWidget);
        },
      );

      testWidgets('SEAT_DROPPED bağlamıyla açılınca uyarı çizilir', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(creator: _ayse),
          transport: assignmentTransportJson(),
          seatDropped: true,
        );

        await tester.scrollUntilVisible(
          find.text(WorkTransportCard.seatDroppedText),
          200,
        );
        expect(find.text(WorkTransportCard.seatDroppedText), findsOneWidget);
        expect(selectOutbound, findsOneWidget);
      });

      testWidgets('tamamlanmış atamada kart satırın görünümüyle, düğmesiz', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: assignmentRow(
            assignmentJson(
              status: 'COMPLETED',
              paymentStatus: 'RELEASED_TO_WORKER',
              extra: {
                'transport': assignmentTransportJson(seats: [seatJson()]),
              },
            ),
          ),
          detail: detailJson(creator: _ayse),
        );

        await tester.scrollUntilVisible(card, 200);
        expect(find.text('Plaka: 34 ABC 12'), findsOneWidget);
        expect(find.text('Değiştir'), findsNothing);
        expect(selectOutbound, findsNothing);
        // Kapanmış atamada görünüm ucu hiç çağrılmıyor.
        expect(
          harness.api.requests.where((r) => r.path.endsWith('/transport')),
          isEmpty,
        );
      });

      testWidgets('durağa yol tarifi durağın koordinatını taşır', (
        tester,
      ) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(creator: _ayse),
          transport: assignmentTransportJson(seats: [seatJson()]),
        );

        final directions = find.byKey(
          const ValueKey('work-transport-directions-OUTBOUND'),
        );
        await tester.scrollUntilVisible(directions, 200);
        await tester.pumpAndSettle();
        await tester.tap(directions);
        await tester.pumpAndSettle();

        expect(harness.openedUrls, hasLength(1));
        expect(
          harness.openedUrls.single.queryParameters['destination'],
          _modaCoordinate,
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('şoför telefonu tel: bağlantısıyla açılır', (tester) async {
        final harness = await pumpDetail(
          tester,
          brightness: brightness,
          job: _confirmedRow,
          detail: detailJson(creator: _ayse),
          transport: assignmentTransportJson(seats: [seatJson()]),
        );

        final call = find.byKey(const ValueKey('work-transport-call-OUTBOUND'));
        await tester.scrollUntilVisible(call, 200);
        await tester.pumpAndSettle();
        await tester.tap(call);
        await tester.pumpAndSettle();

        expect(harness.openedUrls, hasLength(1));
        expect(harness.openedUrls.single.toString(), 'tel:+905551112233');
      });
    });
  }
}
