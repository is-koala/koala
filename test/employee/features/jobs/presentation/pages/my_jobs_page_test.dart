import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/employer_type_badge.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/pages/my_jobs_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/review_fixtures.dart';
import '../../../../../support/work_test_support.dart';

/// Onaylanmış atama; kapı alanları isteğe bağlı ki eski sunucu (alan yok)
/// da denenebilsin. Ortak gövde `work_test_support.dart`'ta.
Map<String, Object?> _assignment({
  String status = 'CONFIRMED',
  String paymentStatus = 'HELD_IN_ESCROW',
  bool? messagingAvailable,
  String? messagingAvailableReason,
}) => assignmentJson(
  status: status,
  paymentStatus: paymentStatus,
  assignmentDateTime: '2026-09-10T09:00:00Z',
  messagingAvailable: messagingAvailable,
  messagingAvailableReason: messagingAvailableReason,
);

final _pendingApplicationJson = applicationJson();

typedef Harness = ({
  FakeApi assignmentApi,
  FakeApi chatApi,
  List<MyJob> openedDetails,
});

/// Sayfayı gerçek temada, sahte sunucuya bağlı ve sahte bir `/work-detail`
/// rotasıyla çizer; satırın hangi kaydı açtığı [Harness.openedDetails]'e
/// düşüyor.
Future<Harness> pumpPage(
  WidgetTester tester, {
  required List<Map<String, Object?>> assignments,
  List<Map<String, Object?>> applications = const [],
  FakeApiResponse Function()? chatResponse,
  Brightness brightness = Brightness.light,
}) async {
  final assignmentApi = FakeApi(
    handler: (request) => request.path.endsWith('/work-sessions')
        ? dataResponse(const [])
        : pageResponse(assignments),
  );
  final applicationApi = FakeApi(handler: (_) => pageResponse(applications));
  final chatApi = FakeApi(
    handler: (_) => chatResponse?.call() ?? dataResponse(const {}),
  );
  final notificationApi = FakeApi(
    handler: (_) => dataResponse(const {
      'notifications': {'content': [], 'page': 0, 'last': true},
      'unreadCount': 0,
    }),
  );
  final queue = idleTimesheetQueue();
  final userProvider = (await tester.runAsync(loadedWorkerProvider))!;
  addTearDown(userProvider.dispose);
  final openedDetails = <MyJob>[];

  final router = GoRouter(
    initialLocation: '/jobs',
    routes: [
      GoRoute(
        path: '/jobs',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: MyJobsPage(
            assignmentService: AssignmentService.withClient(
              assignmentApi.client,
            ),
            chatService: ChatService.withClient(chatApi.client),
          ),
        ),
      ),
      stubWorkDetailRoute(onOpened: openedDetails.add),
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
            service: JobApplicationService.withClient(applicationApi.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewProvider(
            service: ReviewService.withClient(assignmentApi.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(
            service: NotificationService.withClient(notificationApi.client),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);

  return (
    assignmentApi: assignmentApi,
    chatApi: chatApi,
    openedDetails: openedDetails,
  );
}

/// Yükleme birden çok async servis katmanından geçiyor; olay döngüsü sabit
/// sayıda kareyle ilerletiliyor (bkz. b_job_detail harness).
Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

final _chatButton = find.byKey(const ValueKey('job-chat-job-1'));
final _chatNote = find.byKey(const ValueKey('job-chat-note-job-1'));

const _workerNote = 'Mesajlaşma, işveren ödemeyi tamamladığında açılır.';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    group('İşlerim sohbet düğmesi / ${brightness.name}', () {
      testWidgets('AVAILABLE: düğme çizilir', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [
            _assignment(
              messagingAvailable: true,
              messagingAvailableReason: 'AVAILABLE',
            ),
          ],
        );

        expect(_chatButton, findsOneWidget);
        expect(_chatNote, findsNothing);
      });

      testWidgets('PAYMENT_REQUIRED: düğme yerine açıklama', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [
            _assignment(
              paymentStatus: 'PENDING_COLLECTION',
              messagingAvailable: false,
              messagingAvailableReason: 'PAYMENT_REQUIRED',
            ),
          ],
        );

        expect(_chatButton, findsNothing);
        expect(_chatNote, findsOneWidget);
        expect(find.text(_workerNote), findsOneWidget);
      });

      testWidgets('CLOSED: "Bu sohbet kapandı"', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [
            _assignment(
              messagingAvailable: false,
              messagingAvailableReason: 'CLOSED',
            ),
          ],
        );

        expect(_chatButton, findsNothing);
        expect(find.text('Bu sohbet kapandı'), findsOneWidget);
      });

      // Backend PR 261 öncesi sunucu alanları göndermiyor; düğme gizli kalır.
      testWidgets('eski sunucu (alan yok): düğme gizli', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [_assignment()],
        );

        expect(_chatButton, findsNothing);
        expect(find.text(_workerNote), findsOneWidget);
      });

      // Başvurunun ataması yok; sunucu ödeme öncesi sohbeti reddediyor.
      testWidgets('bekleyen başvuruda düğme yok, açıklama var', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: const [],
          applications: [_pendingApplicationJson],
        );

        expect(find.byKey(const ValueKey('job-chat-job-2')), findsNothing);
        expect(
          find.byKey(const ValueKey('job-chat-note-job-2')),
          findsOneWidget,
        );
        expect(find.text(_workerNote), findsOneWidget);
      });
    });
  }

  testWidgets('403 MESSAGING_PAYMENT_REQUIRED metni gösterir ve listeyi '
      'yeniler', (tester) async {
    final harness = await pumpPage(
      tester,
      assignments: [
        _assignment(
          messagingAvailable: true,
          messagingAvailableReason: 'AVAILABLE',
        ),
      ],
      chatResponse: () => const FakeApiResponse(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
          'errorCode': 'MESSAGING_PAYMENT_REQUIRED',
          'errorCategory': 'ACCESS_DENIED',
        },
      ),
    );
    int assignmentFetches() => harness.assignmentApi.requests
        .where((request) => request.path == '/users/me/assignments')
        .length;
    final fetchesBefore = assignmentFetches();
    expect(fetchesBefore, greaterThan(0));

    await tester.tap(_chatButton);
    await _settle(tester);

    expect(
      harness.chatApi.requests.map((r) => r.path),
      contains('/jobs/job-1/conversation'),
    );
    expect(find.text(_workerNote), findsWidgets);
    expect(assignmentFetches(), greaterThan(fetchesBefore));
  });

  testWidgets('409 MESSAGING_WINDOW_CLOSED "Bu sohbet kapandı" der', (
    tester,
  ) async {
    await pumpPage(
      tester,
      assignments: [
        _assignment(
          messagingAvailable: true,
          messagingAvailableReason: 'AVAILABLE',
        ),
      ],
      chatResponse: () => const FakeApiResponse(
        statusCode: 409,
        body: {
          'success': false,
          'message': 'Bu iş için mesajlaşma süresi doldu.',
          'errorCode': 'MESSAGING_WINDOW_CLOSED',
          'errorCategory': 'DATA_CONFLICT',
        },
      ),
    );

    await tester.tap(_chatButton);
    await _settle(tester);

    expect(find.text('Bu sohbet kapandı'), findsOneWidget);
    expect(find.text('Bu iş için mesajlaşma süresi doldu.'), findsNothing);
  });

  // Satırların hiçbirinde `onTap` yoktu: kabul edilmiş işin adresi, işvereni
  // ve çizelgesi mobilde ulaşılamazdı (is-koala/koala#177). Her durumun
  // satırı detayı açmalı ve kaynağını (atama / başvuru) taşımalı.
  group('satır → iş detayı', () {
    for (final (status, paymentStatus, expected) in const [
      (
        'PENDING_CONFIRMATION',
        'PENDING_COLLECTION',
        MyJobStatus.awaitingApproval,
      ),
      ('CONFIRMED', 'HELD_IN_ESCROW', MyJobStatus.approved),
      ('IN_PROGRESS', 'HELD_IN_ESCROW', MyJobStatus.inProgress),
      ('COMPLETED', 'HELD_IN_ESCROW', MyJobStatus.completed),
      ('COMPLETED', 'RELEASED_TO_WORKER', MyJobStatus.past),
      ('CANCELLED', 'REFUNDED', MyJobStatus.cancelled),
      ('REJECTED', 'PENDING_COLLECTION', MyJobStatus.rejected),
    ]) {
      testWidgets('atama $status/$paymentStatus → ${expected.name}', (
        tester,
      ) async {
        final harness = await pumpPage(
          tester,
          assignments: [
            _assignment(status: status, paymentStatus: paymentStatus),
          ],
        );

        // Başlık ve kategori satırı aynı metni taşıyor; başlığa dokunulur.
        await tester.tap(find.text('Barista').first);
        await tester.pumpAndSettle();

        expect(find.text(workDetailStubTitle), findsOneWidget);
        final opened = harness.openedDetails.single;
        expect(opened.status, expected);
        expect(opened.assignment, isNotNull);
        expect(opened.assignmentId, 'assignment-1');
      });
    }

    for (final (status, expected) in const [
      ('APPLIED', MyJobStatus.pending),
      ('REJECTED', MyJobStatus.applicationRejected),
      ('WITHDRAWN', MyJobStatus.withdrawn),
    ]) {
      testWidgets('başvuru $status → ${expected.name}', (tester) async {
        final harness = await pumpPage(
          tester,
          assignments: const [],
          applications: [
            applicationJson(
              status: status,
              answeredDateTime: status == 'REJECTED'
                  ? '2026-09-03T14:00:00Z'
                  : null,
            ),
          ],
        );

        await tester.tap(find.text('Garson'));
        await tester.pumpAndSettle();

        expect(find.text(workDetailStubTitle), findsOneWidget);
        final opened = harness.openedDetails.single;
        expect(opened.status, expected);
        expect(opened.application, isNotNull);
        expect(opened.assignment, isNull);
      });
    }
  });

  for (final brightness in Brightness.values) {
    group('satır rozetleri / ${brightness.name}', () {
      testWidgets('işveren türü rozeti: bireysel ve kurumsal', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [
            _assignment(),
            assignmentJson(
              id: 'assignment-2',
              status: 'CONFIRMED',
              job: jobSummaryJson(
                id: 'job-9',
                title: 'Kasiyer',
                employerType: 'COMPANY',
                companyName: 'Koala Market',
                companyId: 'comp-9',
              ),
            ),
          ],
        );

        final badges = find.byType(EmployerTypeBadge);
        expect(badges, findsNWidgets(2));
        expect(
          badges.evaluate().map((e) => (e.widget as EmployerTypeBadge).type),
          containsAll([JobEmployerType.individual, JobEmployerType.company]),
        );
      });

      testWidgets('yanıtlanmış başvuru satırında yanıt tarihi yazılır', (
        tester,
      ) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: const [],
          applications: [
            applicationJson(
              status: 'REJECTED',
              answeredDateTime: '2026-09-03T14:00:00Z',
              rejectionReason: 'Kadro doldu',
            ),
          ],
        );

        final answered = find.byKey(
          const ValueKey('job-answered-application-1'),
        );
        expect(answered, findsOneWidget);
        expect(
          tester.widget<Text>(answered).data,
          'Yanıtlandı: ${DateTime.utc(2026, 9, 3, 14).toLocal().asShortDate}',
        );
      });

      testWidgets('bekleyen başvuruda yanıt tarihi yok', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: const [],
          applications: [_pendingApplicationJson],
        );

        expect(
          find.byKey(const ValueKey('job-answered-application-1')),
          findsNothing,
        );
      });
    });
  }

  // "Değerlendirildi" rozeti ve "Değerlendir" düğmesi sunucunun `myReview`
  // alanına bakıyor (is-koala/koala#189); cihazda kayıt yok.
  group('İşlerim değerlendirme durumu', () {
    Map<String, Object?> completed({
      required String paymentStatus,
      Map<String, Object?>? myReview,
    }) => {
      ..._assignment(status: 'COMPLETED', paymentStatus: paymentStatus),
      'myReview': myReview,
      'counterpartyReviewed': false,
    };

    testWidgets('ödeme bekleyen işte myReview dolu → rozet, düğme yok', (
      tester,
    ) async {
      await pumpPage(
        tester,
        assignments: [
          completed(
            paymentStatus: 'HELD_IN_ESCROW',
            myReview: myReviewJson(rating: 4),
          ),
        ],
      );

      expect(find.text('Değerlendirildi'), findsOneWidget);
      expect(find.text('Değerlendir'), findsNothing);
    });

    testWidgets('ödeme bekleyen işte myReview null → düğme', (tester) async {
      await pumpPage(
        tester,
        assignments: [completed(paymentStatus: 'HELD_IN_ESCROW')],
      );

      expect(find.text('Değerlendir'), findsOneWidget);
      expect(find.text('Değerlendirildi'), findsNothing);
    });

    testWidgets('geçmiş işte myReview dolu → düğme yok', (tester) async {
      await pumpPage(
        tester,
        assignments: [
          completed(
            paymentStatus: 'RELEASED_TO_WORKER',
            myReview: myReviewJson(rating: 5),
          ),
        ],
      );

      expect(find.text('Değerlendir'), findsNothing);
    });

    testWidgets('geçmiş işte myReview null → düğme', (tester) async {
      await pumpPage(
        tester,
        assignments: [completed(paymentStatus: 'RELEASED_TO_WORKER')],
      );

      expect(find.text('Değerlendir'), findsOneWidget);
    });
  });
}
