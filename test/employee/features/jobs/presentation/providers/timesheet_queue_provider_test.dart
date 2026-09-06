import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_gateway.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_store.dart';
import 'package:koala/employee/features/jobs/services/timesheet_retry_trigger.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> markRequiresSupport(String clientEventId, String message) async {
    final index = records.indexWhere(
      (event) => event.clientEventId == clientEventId,
    );
    records[index] = records[index].copyWith(
      status: TimesheetEventStatus.requiresSupport,
      supportMessage: message,
    );
  }

  @override
  Future<String?> readLastActiveUser() async => lastActiveUserId;

  @override
  Future<void> setLastActiveUser(String? userId) async {
    lastActiveUserId = userId;
  }
}

class _FakeGateway implements TimesheetEventGateway {
  bool isOffline = false;
  bool failAfterServerAck = false;
  ApiException? sendError;
  Completer<void>? sendGate;
  final List<TimesheetEvent> sent = [];
  final Set<String> serverEventIds = {};
  List<WorkSession> sessions = [];
  int activeSends = 0;
  int maximumActiveSends = 0;

  @override
  Future<WorkSession> send(TimesheetEvent event) async {
    sent.add(event);
    activeSends++;
    if (activeSends > maximumActiveSends) maximumActiveSends = activeSends;
    try {
      final gate = sendGate;
      if (gate != null) await gate.future;
      if (isOffline) {
        throw const ApiException(
          message: 'Çevrimdışı',
          type: ApiErrorType.network,
        );
      }
      final error = sendError;
      if (error != null) throw error;
      final isFirstDelivery = serverEventIds.add(event.clientEventId);
      if (failAfterServerAck && isFirstDelivery) {
        throw const ApiException(
          message: 'Yanıt alınamadı',
          type: ApiErrorType.timeout,
        );
      }
      return _sessionFor(event);
    } finally {
      activeSends--;
    }
  }

  @override
  Future<List<WorkSession>> fetchSessions(String assignmentId) async =>
      sessions;
}

class _ManualRetryTrigger implements TimesheetRetryTrigger {
  final StreamController<void> controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onNetworkAvailable => controller.stream;
}

WorkSession _sessionFor(TimesheetEvent event) {
  return WorkSession(
    id: 'session-1',
    assignmentId: event.assignmentId,
    checkInClientEventId: event.action == TimesheetEventAction.checkIn
        ? event.clientEventId
        : null,
    checkOutClientEventId: event.action == TimesheetEventAction.checkOut
        ? event.clientEventId
        : null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uçak modunda çıkış kalıcı bekleyen kayıt olarak görünür', () async {
    final store = _MemoryStore();
    final gateway = _FakeGateway()..isOffline = true;
    final retryTrigger = _ManualRetryTrigger();
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: retryTrigger,
      utcNow: () => DateTime.parse('2026-09-06T10:00:00Z'),
      monotonicNow: () => 42000,
      eventIdFactory: () => 'event-1',
    );

    await provider.startForUser('user-a');
    final result = await provider.recordCheckOut(assignmentId: 'assignment-a');

    expect(result, TimesheetSubmission.pending);
    expect(provider.events, hasLength(1));
    expect(provider.events.single.status, TimesheetEventStatus.pending);
    expect(store.records, hasLength(1));
    expect(gateway.sent.single.clientEventId, 'event-1');
    await provider.disposeAsync();
  });

  test(
    'uygulama yeniden kurulduğunda kullanıcının bekleyen kaydı yüklenir',
    () async {
      final store = _MemoryStore();
      final firstGateway = _FakeGateway()..isOffline = true;
      final firstTrigger = _ManualRetryTrigger();
      final first = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: firstGateway,
        retryTrigger: firstTrigger,
        eventIdFactory: () => 'event-restart',
      );
      await first.startForUser('user-a');
      await first.recordCheckIn(assignmentId: 'assignment-a');
      await first.disposeAsync();

      final secondGateway = _FakeGateway()..isOffline = true;
      final secondTrigger = _ManualRetryTrigger();
      final restarted = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: secondGateway,
        retryTrigger: secondTrigger,
      );
      await restarted.resumeLastUser();

      expect(restarted.events.single.clientEventId, 'event-restart');
      expect(restarted.events.single.userId, 'user-a');
      await restarted.disposeAsync();
    },
  );

  test(
    'belirsiz yanıttan sonraki tekrar sunucuda ikinci kayıt oluşturmaz',
    () async {
      final store = _MemoryStore();
      final gateway = _FakeGateway()..failAfterServerAck = true;
      final trigger = _ManualRetryTrigger();
      final provider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: gateway,
        retryTrigger: trigger,
        eventIdFactory: () => 'event-idempotent',
      );
      await provider.startForUser('user-a');

      expect(
        await provider.recordCheckOut(assignmentId: 'assignment-a'),
        TimesheetSubmission.pending,
      );
      gateway.failAfterServerAck = false;
      trigger.controller.add(null);
      while (provider.events.isNotEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(gateway.sent, hasLength(2));
      expect(gateway.sent.map((event) => event.clientEventId).toSet(), {
        'event-idempotent',
      });
      expect(gateway.serverEventIds, {'event-idempotent'});
      expect(provider.events, isEmpty);
      expect(provider.lastDeliveredEvent?.clientEventId, 'event-idempotent');
      await provider.disposeAsync();
    },
  );

  test('bağlantı sinyali başarı sayılmaz, ağ hatasında kayıt kalır', () async {
    final store = _MemoryStore();
    final gateway = _FakeGateway()..isOffline = true;
    final trigger = _ManualRetryTrigger();
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: trigger,
      eventIdFactory: () => 'event-still-offline',
    );
    await provider.startForUser('user-a');
    await provider.recordCheckIn(assignmentId: 'assignment-a');

    trigger.controller.add(null);
    await Future<void>.delayed(Duration.zero);
    await provider.flush();

    expect(provider.events.single.clientEventId, 'event-still-offline');
    await provider.disposeAsync();
  });

  test('uygulama devam ettiğinde bekleyen kayıt yeniden gönderilir', () async {
    final store = _MemoryStore();
    final gateway = _FakeGateway()..isOffline = true;
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: _ManualRetryTrigger(),
      eventIdFactory: () => 'event-resume',
    );
    await provider.startForUser('user-a');
    await provider.recordCheckIn(assignmentId: 'assignment-a');
    gateway.isOffline = false;

    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    for (
      var attempt = 0;
      attempt < 10 && provider.events.isNotEmpty;
      attempt++
    ) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(provider.events, isEmpty);
    expect(gateway.sent, hasLength(2));
    await provider.disposeAsync();
  });

  test('aynı atamadaki olaylar bağlantı gelince FIFO gönderilir', () async {
    final ids = ['event-in', 'event-out'].iterator;
    final store = _MemoryStore();
    final gateway = _FakeGateway()..isOffline = true;
    final trigger = _ManualRetryTrigger();
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: trigger,
      eventIdFactory: () {
        ids.moveNext();
        return ids.current;
      },
    );
    await provider.startForUser('user-a');
    await provider.recordCheckIn(assignmentId: 'assignment-a');
    await provider.recordCheckOut(assignmentId: 'assignment-a');

    gateway
      ..sent.clear()
      ..isOffline = false;
    await provider.flush();

    expect(gateway.sent.map((event) => event.action), [
      TimesheetEventAction.checkIn,
      TimesheetEventAction.checkOut,
    ]);
    expect(provider.events, isEmpty);
    await provider.disposeAsync();
  });

  test(
    'destek bekleyen ilk olay aynı atamadaki sonrakini bloke eder',
    () async {
      final store = _MemoryStore()
        ..records.addAll([
          TimesheetEvent(
            clientEventId: 'event-in-support',
            userId: 'user-a',
            assignmentId: 'assignment-a',
            action: TimesheetEventAction.checkIn,
            capturedAt: DateTime.parse('2026-09-06T10:00:00Z'),
            monotonicMicros: 1,
            status: TimesheetEventStatus.requiresSupport,
            supportMessage: 'Destek gerekiyor.',
          ),
          TimesheetEvent(
            clientEventId: 'event-out-pending',
            userId: 'user-a',
            assignmentId: 'assignment-a',
            action: TimesheetEventAction.checkOut,
            capturedAt: DateTime.parse('2026-09-06T18:00:00Z'),
            monotonicMicros: 2,
          ),
        ]);
      final gateway = _FakeGateway();
      final trigger = _ManualRetryTrigger();
      final provider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: gateway,
        retryTrigger: trigger,
      );

      await provider.startForUser('user-a');

      expect(gateway.sent, isEmpty);
      expect(provider.events, hasLength(2));
      await provider.disposeAsync();
    },
  );

  test('401 ve 5xx hatalarında olay yeniden denemek için tutulur', () async {
    for (final errorType in [ApiErrorType.unauthorized, ApiErrorType.server]) {
      final store = _MemoryStore();
      final gateway = _FakeGateway()
        ..sendError = ApiException(message: 'Geçici hata', type: errorType);
      final trigger = _ManualRetryTrigger();
      final provider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: gateway,
        retryTrigger: trigger,
        eventIdFactory: () => 'event-${errorType.name}',
      );
      await provider.startForUser('user-a');

      expect(
        await provider.recordCheckIn(assignmentId: 'assignment-a'),
        TimesheetSubmission.pending,
      );
      expect(provider.events, hasLength(1));
      await provider.disposeAsync();
    }
  });

  test(
    'kalıcı 404 hatası tekrar döngüsü yerine destek durumuna alınır',
    () async {
      final store = _MemoryStore();
      final gateway = _FakeGateway()
        ..sendError = const ApiException(
          message: 'Atama bulunamadı',
          type: ApiErrorType.notFound,
          statusCode: 404,
        );
      final trigger = _ManualRetryTrigger();
      final provider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: gateway,
        retryTrigger: trigger,
        eventIdFactory: () => 'event-not-found',
      );
      await provider.startForUser('user-a');

      expect(
        await provider.recordCheckOut(assignmentId: 'assignment-a'),
        TimesheetSubmission.requiresSupport,
      );
      await provider.flush();

      expect(gateway.sent, hasLength(1));
      expect(provider.events.single.requiresSupport, isTrue);
      await provider.disposeAsync();
    },
  );

  test('uzlaştırılamayan 409 olayı kalıcı destek durumuna alınır', () async {
    final store = _MemoryStore();
    final gateway = _FakeGateway()
      ..sendError = const ApiException(
        message: 'Çakışma',
        type: ApiErrorType.conflict,
        statusCode: 409,
        errorCode: 'TIMESHEET_IDEMPOTENCY_CONFLICT',
      );
    final trigger = _ManualRetryTrigger();
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: trigger,
      eventIdFactory: () => 'event-conflict',
    );
    await provider.startForUser('user-a');

    expect(
      await provider.recordCheckIn(assignmentId: 'assignment-a'),
      TimesheetSubmission.requiresSupport,
    );
    expect(provider.events.single.requiresSupport, isTrue);
    expect(provider.events.single.supportMessage, contains('Destek'));
    await provider.disposeAsync();
  });

  test(
    'sunucuda aynı kimlikle bulunan 409 olayı teslim edilmiş sayılır',
    () async {
      final store = _MemoryStore();
      final gateway = _FakeGateway()
        ..sendError = const ApiException(
          message: 'Çakışma',
          type: ApiErrorType.conflict,
        )
        ..sessions = const [
          WorkSession(
            id: 'session-a',
            assignmentId: 'assignment-a',
            checkInClientEventId: 'event-existing',
          ),
        ];
      final trigger = _ManualRetryTrigger();
      final provider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: gateway,
        retryTrigger: trigger,
        eventIdFactory: () => 'event-existing',
      );
      await provider.startForUser('user-a');

      expect(
        await provider.recordCheckIn(assignmentId: 'assignment-a'),
        TimesheetSubmission.sent,
      );
      expect(provider.events, isEmpty);
      await provider.disposeAsync();
    },
  );

  test(
    'makullük bayraklı ack tekrar gönderilmeden destek durumuna alınır',
    () async {
      final store = _MemoryStore();
      final gateway = _FakeGateway();
      final reviewGateway = _ReviewGateway(gateway);
      final reviewTrigger = _ManualRetryTrigger();
      final reviewProvider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: reviewGateway,
        retryTrigger: reviewTrigger,
        eventIdFactory: () => 'event-review',
      );
      await reviewProvider.startForUser('user-a');
      expect(
        await reviewProvider.recordCheckOut(assignmentId: 'assignment-a'),
        TimesheetSubmission.requiresSupport,
      );
      await reviewProvider.flush();

      expect(reviewGateway.sentCount, 1);
      expect(reviewProvider.events.single.requiresSupport, isTrue);
      await reviewProvider.disposeAsync();
    },
  );

  test('aktif kullanıcı yalnız kendi kuyruk bölümünü görür', () async {
    final store = _MemoryStore()
      ..records.addAll([
        TimesheetEvent(
          clientEventId: 'event-a',
          userId: 'user-a',
          assignmentId: 'assignment-a',
          action: TimesheetEventAction.checkIn,
          capturedAt: DateTime.parse('2026-09-06T10:00:00Z'),
          monotonicMicros: 1,
        ),
        TimesheetEvent(
          clientEventId: 'event-b',
          userId: 'user-b',
          assignmentId: 'assignment-b',
          action: TimesheetEventAction.checkIn,
          capturedAt: DateTime.parse('2026-09-06T10:01:00Z'),
          monotonicMicros: 2,
        ),
      ]);
    final gateway = _FakeGateway()..isOffline = true;
    final trigger = _ManualRetryTrigger();
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: trigger,
    );

    await provider.startForUser('user-b');

    expect(provider.events.map((event) => event.clientEventId), ['event-b']);
    expect(gateway.sent.map((event) => event.clientEventId), ['event-b']);
    await provider.disposeAsync();
  });

  test('oturum sona erince etkin kullanıcı işaretçisi temizlenir', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final session = SessionManager.withTokenStorage(
      TokenStorage.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://queue-session.example.test',
      ),
    );
    await session.start(
      accessToken: 'access',
      refreshToken: 'refresh',
      isEmployer: false,
    );
    final store = _MemoryStore();
    final trigger = _ManualRetryTrigger();
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: _FakeGateway()..isOffline = true,
      retryTrigger: trigger,
      sessionManager: session,
    );
    await provider.startForUser('user-a');

    await session.end();
    while (provider.activeUserId != null) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(store.lastActiveUserId, isNull);
    expect(provider.events, isEmpty);
    await provider.disposeAsync();
  });

  test(
    'oturum diski yüklendiğinde kalıcı kullanıcı bölümü gönderilir',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final session = SessionManager.withTokenStorage(
        TokenStorage.withStorage(
          const FlutterSecureStorage(),
          apiOrigin: 'https://queue-startup.example.test',
        ),
      );
      await session.start(
        accessToken: 'access',
        refreshToken: 'refresh',
        isEmployer: false,
      );
      final store = _MemoryStore()
        ..lastActiveUserId = 'user-a'
        ..records.add(
          TimesheetEvent(
            clientEventId: 'event-startup',
            userId: 'user-a',
            assignmentId: 'assignment-a',
            action: TimesheetEventAction.checkIn,
            capturedAt: DateTime.parse('2026-09-06T10:00:00Z'),
            monotonicMicros: 1,
          ),
        );
      final gateway = _FakeGateway();
      final provider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: gateway,
        retryTrigger: _ManualRetryTrigger(),
        sessionManager: session,
      );

      await session.load();
      for (var attempt = 0; attempt < 10 && gateway.sent.isEmpty; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(gateway.sent.single.clientEventId, 'event-startup');
      expect(provider.events, isEmpty);
      await provider.disposeAsync();
    },
  );

  test('eşzamanlı tetikler tek flush çalıştırır', () async {
    final store = _MemoryStore();
    final gateway = _FakeGateway()..sendGate = Completer<void>();
    final trigger = _ManualRetryTrigger();
    final provider = TimesheetQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: trigger,
      eventIdFactory: () => 'event-single-flight',
    );
    await provider.startForUser('user-a');

    final recording = provider.recordCheckIn(assignmentId: 'assignment-a');
    while (gateway.sent.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final firstFlush = provider.flush();
    final secondFlush = provider.flush();
    gateway.sendGate!.complete();
    await Future.wait([recording, firstFlush, secondFlush]);

    expect(gateway.maximumActiveSends, 1);
    expect(gateway.sent, hasLength(1));
    await provider.disposeAsync();
  });

  test(
    'flush sırasında kullanıcı değişirse yeni bölüm de gönderilir',
    () async {
      final store = _MemoryStore()
        ..records.addAll([
          TimesheetEvent(
            clientEventId: 'event-a',
            userId: 'user-a',
            assignmentId: 'assignment-a',
            action: TimesheetEventAction.checkIn,
            capturedAt: DateTime.parse('2026-09-06T10:00:00Z'),
            monotonicMicros: 1,
          ),
          TimesheetEvent(
            clientEventId: 'event-b',
            userId: 'user-b',
            assignmentId: 'assignment-b',
            action: TimesheetEventAction.checkIn,
            capturedAt: DateTime.parse('2026-09-06T10:01:00Z'),
            monotonicMicros: 2,
          ),
        ]);
      final gateway = _FakeGateway()..sendGate = Completer<void>();
      final provider = TimesheetQueueProvider.withAdapters(
        store: store,
        gateway: gateway,
        retryTrigger: _ManualRetryTrigger(),
      );

      final firstStart = provider.startForUser('user-a');
      while (gateway.sent.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final secondStart = provider.startForUser('user-b');
      gateway.sendGate!.complete();
      await Future.wait([firstStart, secondStart]);

      expect(gateway.sent.map((event) => event.clientEventId), [
        'event-a',
        'event-b',
      ]);
      expect(provider.activeUserId, 'user-b');
      expect(provider.events, isEmpty);
      await provider.disposeAsync();
    },
  );
}

class _ReviewGateway implements TimesheetEventGateway {
  _ReviewGateway(this.delegate);

  final _FakeGateway delegate;
  int sentCount = 0;

  @override
  Future<List<WorkSession>> fetchSessions(String assignmentId) {
    return delegate.fetchSessions(assignmentId);
  }

  @override
  Future<WorkSession> send(TimesheetEvent event) async {
    sentCount++;
    return WorkSession(
      id: 'session-review',
      assignmentId: event.assignmentId,
      checkOutClientEventId: event.clientEventId,
      checkOutPlausibilityFlags: const {
        TimesheetPlausibility.deviceTimeImplausible,
      },
    );
  }
}
