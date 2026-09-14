import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/presentation/pages/my_jobs_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_gateway.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_store.dart';
import 'package:koala/employee/features/jobs/services/timesheet_retry_trigger.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const _me = 'worker-1';

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

/// Onaylanmış atama; kapı alanları isteğe bağlı ki eski sunucu (alan yok)
/// da denenebilsin.
Map<String, Object?> assignmentJson({
  String paymentStatus = 'HELD_IN_ESCROW',
  bool? messagingAvailable,
  String? messagingAvailableReason,
}) => {
  'id': 'assignment-1',
  'status': 'CONFIRMED',
  'paymentStatus': paymentStatus,
  'assignmentDateTime': '2026-09-10T09:00:00Z',
  'workerPayout': 950,
  'job': _jobJson,
  'messagingAvailable': ?messagingAvailable,
  'messagingAvailableReason': ?messagingAvailableReason,
};

final _pendingApplicationJson = {
  'id': 'application-1',
  'status': 'APPLIED',
  'applicationDateTime': '2026-09-08T10:00:00Z',
  'job': {..._jobJson, 'id': 'job-2', 'title': 'Garson'},
};

FakeApiResponse _page(List<Map<String, Object?>> content) => FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': {'content': content},
  },
);

const _emptyList = FakeApiResponse(
  statusCode: 200,
  body: {'success': true, 'data': []},
);

class _MemoryStore implements TimesheetEventStore {
  final List<TimesheetEvent> records = [];
  String? lastActiveUserId;

  @override
  Future<void> add(TimesheetEvent event) async => records.add(event);

  @override
  Future<List<TimesheetEvent>> readForUser(String userId) async =>
      records.where((event) => event.userId == userId).toList(growable: false);

  @override
  Future<void> remove(String clientEventId) async {
    records.removeWhere((event) => event.clientEventId == clientEventId);
  }

  @override
  Future<void> markRequiresSupport(
    String clientEventId,
    String message,
  ) async {}

  @override
  Future<String?> readLastActiveUser() async => lastActiveUserId;

  @override
  Future<void> setLastActiveUser(String? userId) async {
    lastActiveUserId = userId;
  }
}

class _IdleGateway implements TimesheetEventGateway {
  @override
  Future<WorkSession> send(TimesheetEvent event) =>
      throw UnimplementedError('Bu testte mesai gönderilmiyor.');

  @override
  Future<List<WorkSession>> fetchSessions(String assignmentId) async => [];
}

class _ManualRetryTrigger implements TimesheetRetryTrigger {
  final StreamController<void> controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onNetworkAvailable => controller.stream;
}

Future<UserProvider> _loadedWorker() async {
  final api = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': _me,
          'firstName': 'Yakup',
          'lastName': 'Kahraman',
          'email': 'yakup@example.com',
          'isEmployer': false,
        },
      },
    ),
  );
  final provider = UserProvider(
    userService: UserService.withClient(api.client),
  );
  await provider.load();
  return provider;
}

Future<({FakeApi assignmentApi, FakeApi chatApi})> pumpPage(
  WidgetTester tester, {
  required List<Map<String, Object?>> assignments,
  List<Map<String, Object?>> applications = const [],
  FakeApiResponse Function()? chatResponse,
  Brightness brightness = Brightness.light,
}) async {
  final assignmentApi = FakeApi(
    handler: (request) => request.path.endsWith('/work-sessions')
        ? _emptyList
        : _page(assignments),
  );
  final applicationApi = FakeApi(handler: (_) => _page(applications));
  final chatApi = FakeApi(
    handler: (_) =>
        chatResponse?.call() ??
        const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': {}},
        ),
  );
  final notificationApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'notifications': {'content': [], 'page': 0, 'last': true},
          'unreadCount': 0,
        },
      },
    ),
  );
  final retryTrigger = _ManualRetryTrigger();
  final queue = TimesheetQueueProvider.withAdapters(
    store: _MemoryStore(),
    gateway: _IdleGateway(),
    retryTrigger: retryTrigger,
  );
  final userProvider = (await tester.runAsync(_loadedWorker))!;
  addTearDown(() => retryTrigger.controller.close());
  addTearDown(userProvider.dispose);

  await pumpInApp(
    tester,
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
      child: MyJobsPage(
        assignmentService: AssignmentService.withClient(assignmentApi.client),
        chatService: ChatService.withClient(chatApi.client),
      ),
    ),
    brightness: brightness,
  );
  // Yükleme birden çok async servis katmanından geçiyor; olay döngüsü sabit
  // sayıda kareyle ilerletiliyor (bkz. b_job_detail harness).
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();

  return (assignmentApi: assignmentApi, chatApi: chatApi);
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
            assignmentJson(
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
            assignmentJson(
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
            assignmentJson(
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
          assignments: [assignmentJson()],
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
        assignmentJson(
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
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

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
        assignmentJson(
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
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

    expect(find.text('Bu sohbet kapandı'), findsOneWidget);
    expect(find.text('Bu iş için mesajlaşma süresi doldu.'), findsNothing);
  });
}
