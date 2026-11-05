import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/pending_boarding.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/employee/features/jobs/services/boarding_queue_store.dart';
import 'package:koala/employee/features/jobs/services/timesheet_retry_trigger.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/boarding_fixtures.dart';

class _MemoryStore implements BoardingQueueStore {
  List<PendingBoarding> entries = [];
  String? lastUser;

  @override
  Future<List<PendingBoarding>> readAll() async => List.of(entries);

  @override
  Future<void> writeAll(List<PendingBoarding> entries) async =>
      this.entries = List.of(entries);

  @override
  Future<String?> readLastActiveUser() async => lastUser;

  @override
  Future<void> setLastActiveUser(String? userId) async => lastUser = userId;
}

/// Sırayla verilen sonuçları döndürür; sonuç bir `ApiException` ise atar.
class _ScriptedGateway implements BoardingGateway {
  final List<Object> responses = [];
  final List<PendingBoarding> sent = [];

  @override
  Future<BoardingEvent> send(PendingBoarding entry) async {
    sent.add(entry);
    final next = responses.isEmpty
        ? BoardingEvent.fromJson(boardingEventJson())
        : responses.removeAt(0);
    if (next is ApiException) throw next;
    return next as BoardingEvent;
  }
}

class _ManualTrigger implements TimesheetRetryTrigger {
  final StreamController<void> controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onNetworkAvailable => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryStore store;
  late _ScriptedGateway gateway;
  late _ManualTrigger trigger;
  late BoardingQueueProvider queue;
  var idCounter = 0;
  final now = DateTime.utc(2026, 9, 20, 3, 41);

  final token = BoardingToken.fromValue(shuttleTokenValue)!;

  setUp(() async {
    store = _MemoryStore();
    gateway = _ScriptedGateway();
    trigger = _ManualTrigger();
    idCounter = 0;
    queue = BoardingQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: trigger,
      utcNow: () => now,
      eventIdFactory: () => 'cid-${++idCounter}',
    );
    await queue.startForUser('worker-1');
  });

  tearDown(() async {
    queue.dispose();
    await trigger.controller.close();
  });

  Future<BoardingSubmission> submit() => queue.submit(
    token: token,
    capturedAt: now,
    latitude: 40.98,
    longitude: 29.02,
    assignmentId: 'asg-1',
    direction: ShuttleDirection.outbound,
  );

  test('çevrimiçi okutma hemen kaydedilir, kuyrukta kalmaz', () async {
    final result = await submit();

    expect(result, isA<BoardingRecorded>());
    expect(store.entries, isEmpty);
    final sent = gateway.sent.single;
    expect(sent.shuttleId, shuttleUuid);
    expect(sent.token, shuttleTokenValue);
    expect(sent.clientEventId, 'cid-1');
    expect(sent.capturedAt, now);
  });

  test('replayed yanıt da başarıdır', () async {
    gateway.responses.add(
      BoardingEvent.fromJson(boardingEventJson(replayed: true)),
    );

    final result = await submit();

    expect(result, isA<BoardingRecorded>());
    expect((result as BoardingRecorded).event.replayed, isTrue);
  });

  test(
    'bağlantı yoksa saklanır; ağ dönünce aynı gövdeyle gönderilir',
    () async {
      gateway.responses.add(offlineError);

      final result = await submit();

      expect(result, isA<BoardingQueued>());
      expect(
        queue.entriesFor('asg-1', ShuttleDirection.outbound),
        hasLength(1),
      );

      // LATE_SYNC bayrağıyla kabul: istemci için yalnız başarı.
      gateway.responses.add(
        BoardingEvent.fromJson(boardingEventJson(flags: ['LATE_SYNC'])),
      );
      final revision = queue.deliveryRevision;
      trigger.controller.add(null);
      await pumpEventQueue();

      expect(store.entries, isEmpty);
      expect(queue.deliveryRevision, revision + 1);
      expect(gateway.sent, hasLength(2));
      expect(gateway.sent[1].clientEventId, gateway.sent[0].clientEventId);
      expect(gateway.sent[1].capturedAt, gateway.sent[0].capturedAt);
      expect(gateway.sent[1].latitude, gateway.sent[0].latitude);
    },
  );

  test('çevrimiçi ret kuyrukta tutulmaz, nedeni döner', () async {
    gateway.responses.add(boardingError(TransportErrorCodes.wrongShuttle));

    final result = await submit();

    expect(result, isA<BoardingRejected>());
    expect((result as BoardingRejected).failure, BoardingFailure.wrongShuttle);
    expect(store.entries, isEmpty);
  });

  test(
    'kuyruktaki okutmayı sunucu sonradan reddederse uyarı olarak kalır',
    () async {
      gateway.responses.add(offlineError);
      await submit();

      gateway.responses.add(
        boardingError(
          TransportErrorCodes.tokenExpired,
          type: ApiErrorType.validation,
          statusCode: 400,
        ),
      );
      await queue.flush();

      final entry = queue.entriesFor('asg-1', ShuttleDirection.outbound).single;
      expect(entry.isFailed, isTrue);
      expect(entry.failure, BoardingFailure.tokenExpired);

      // Reddedilen kayıt bir daha gönderilmez.
      await queue.flush();
      expect(gateway.sent, hasLength(2));

      await queue.dismiss(entry.clientEventId);
      expect(store.entries, isEmpty);
    },
  );

  test('sunucu hatası ve oturum yenilenemedi geçici sayılır', () async {
    gateway.responses.add(
      const ApiException(message: 'x', type: ApiErrorType.server),
    );
    expect(await submit(), isA<BoardingQueued>());

    gateway.responses.add(
      const ApiException(message: 'x', type: ApiErrorType.unauthenticated),
    );
    await queue.flush();
    expect(store.entries.single.isFailed, isFalse);
  });

  test('oturum duraklayınca görünüm boşalır, kayıt diskte kalır', () async {
    gateway.responses.add(offlineError);
    await submit();

    await queue.pause();

    expect(queue.entries, isEmpty);
    expect(store.entries, hasLength(1));
    expect(store.lastUser, isNull);

    gateway.responses.add(BoardingEvent.fromJson(boardingEventJson()));
    await queue.startForUser('worker-1');
    expect(store.entries, isEmpty);
  });

  test('başka kullanıcının kaydı gösterilmez ve gönderilmez', () async {
    gateway.responses.add(offlineError);
    await submit();

    await queue.startForUser('worker-2');

    expect(queue.entries, isEmpty);
    expect(gateway.sent, hasLength(1));
    expect(store.entries.single.userId, 'worker-1');
  });

  test('72 saatten eski kayıt açılışta atılır', () async {
    store.entries = [
      PendingBoarding(
        clientEventId: 'old',
        userId: 'worker-1',
        shuttleId: shuttleUuid,
        token: shuttleTokenValue,
        capturedAt: now.subtract(const Duration(hours: 73)),
      ),
    ];

    await queue.startForUser('worker-1');

    expect(store.entries, isEmpty);
    expect(gateway.sent, isEmpty);
  });

  test(
    'SharedPreferences deposu JSON\'u geri okur, bozuk satırı atlar',
    () async {
      SharedPreferences.setMockInitialValues({});
      const real = SharedPreferencesBoardingQueueStore();
      final entry = PendingBoarding(
        clientEventId: 'cid-9',
        userId: 'worker-1',
        shuttleId: shuttleUuid,
        token: shuttleTokenValue,
        capturedAt: now,
        latitude: 40.98,
        longitude: 29.02,
        assignmentId: 'asg-1',
        direction: ShuttleDirection.returnTrip,
      ).asFailed(BoardingFailure.retryConflict);

      await real.writeAll([entry]);
      await real.setLastActiveUser('worker-1');
      final read = await real.readAll();

      expect(read.single.clientEventId, 'cid-9');
      expect(read.single.direction, ShuttleDirection.returnTrip);
      expect(read.single.failure, BoardingFailure.retryConflict);
      expect(read.single.capturedAt, now);
      expect(await real.readLastActiveUser(), 'worker-1');
      expect(entry.toString(), isNot(contains(shuttleTokenValue)));

      expect(PendingBoarding.fromJson({'clientEventId': 'x'}), isNull);
    },
  );
}
