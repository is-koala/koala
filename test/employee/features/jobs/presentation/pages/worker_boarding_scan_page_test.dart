import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/jobs/models/pending_boarding.dart';
import 'package:koala/employee/features/jobs/presentation/pages/worker_boarding_scan_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/employee/features/jobs/services/boarding_queue_store.dart';
import 'package:koala/employee/features/jobs/services/timesheet_retry_trigger.dart';
import 'package:koala/employee/features/jobs/services/worker_boarding_submitter.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_result_panel.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/device_location_source.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/fake_boarding_camera.dart';
import '../../../../../support/pump.dart';
import '../../../../../support/work_test_support.dart';

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

class _Gateway implements BoardingGateway {
  Object response = BoardingEvent.fromJson(boardingEventJson());
  final List<PendingBoarding> sent = [];

  @override
  Future<BoardingEvent> send(PendingBoarding entry) async {
    sent.add(entry);
    final next = response;
    if (next is ApiException) throw next;
    return next as BoardingEvent;
  }
}

class _NoNetwork implements TimesheetRetryTrigger {
  @override
  Stream<void> get onNetworkAvailable => const Stream.empty();
}

void main() {
  late FakeBoardingCamera camera;
  late _MemoryStore store;
  late _Gateway gateway;
  late FakeDeviceLocationSource location;

  setUp(() {
    camera = FakeBoardingCamera();
    store = _MemoryStore();
    gateway = _Gateway();
    location = FakeDeviceLocationSource(granted: const LatLng(40.98, 29.02));
  });

  Future<BoardingQueueProvider> pump(
    WidgetTester tester, {
    String? expectedShuttleId,
    Brightness brightness = Brightness.light,
  }) async {
    final users = (await tester.runAsync(loadedWorkerProvider))!;
    addTearDown(users.dispose);
    final queue = BoardingQueueProvider.withAdapters(
      store: store,
      gateway: gateway,
      retryTrigger: _NoNetwork(),
      eventIdFactory: () => 'cid-1',
    );
    addTearDown(queue.dispose);

    await pumpInApp(
      tester,
      WorkerBoardingScanPage(
        assignmentId: 'asg-1',
        direction: ShuttleDirection.outbound,
        expectedShuttleId: expectedShuttleId,
        submitter: WorkerBoardingSubmitter(
          queue: queue,
          users: users,
          location: location,
        ),
        cameraBuilder: camera.build,
        permissionProbe: FakeCameraPermissionProbe(),
        appScheme: 'koala-staging',
      ),
      brightness: brightness,
    );
    return queue;
  }

  String link(String token) => 'koala-staging://board?t=$token';

  for (final brightness in Brightness.values) {
    testWidgets('okutma kaydedilir, kamera kapanır (${brightness.name})', (
      tester,
    ) async {
      await pump(tester, brightness: brightness);

      camera.scan(link(shuttleTokenValue));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('boarding-result-success')), findsOne);
      expect(find.text('Binişiniz kaydedildi.'), findsOne);
      expect(find.byKey(const ValueKey('fake-boarding-camera')), findsNothing);

      final sent = gateway.sent.single;
      expect(sent.shuttleId, shuttleUuid);
      expect(sent.assignmentId, 'asg-1');
      expect(sent.latitude, 40.98);
      expect(location.requestCalls, 0, reason: 'izin diyaloğu açılmamalı');
      expect(store.entries, isEmpty);
    });
  }

  testWidgets('bağlantı yoksa okutma cihazda saklanır', (tester) async {
    gateway.response = offlineError;
    final queue = await pump(tester);

    camera.scan(link(shuttleTokenValue));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('boarding-result-queued')), findsOne);
    expect(queue.entriesFor('asg-1', ShuttleDirection.outbound), hasLength(1));
  });

  testWidgets('sunucu reddederse neden yazılır, kamera açık kalır', (
    tester,
  ) async {
    gateway.response = boardingError(
      TransportErrorCodes.tokenExpired,
      type: ApiErrorType.validation,
      statusCode: 400,
    );
    await pump(tester);

    camera.scan(link(shuttleTokenValue));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('boarding-result-failure')), findsOne);
    expect(
      find.text(BoardingFailure.tokenExpired.message(BoardingActor.worker)),
      findsOne,
    );
    expect(find.byKey(const ValueKey('fake-boarding-camera')), findsOne);
    expect(store.entries, isEmpty);
  });

  testWidgets('başka servisin QR\'ı çevrimdışı da gönderilmeden reddedilir', (
    tester,
  ) async {
    await pump(
      tester,
      expectedShuttleId: 'aaaaaaaa-0000-4000-8000-000000000000',
    );

    camera.scan(link(shuttleTokenValue));
    await tester.pumpAndSettle();

    expect(
      find.text(BoardingFailure.wrongShuttle.message(BoardingActor.worker)),
      findsOne,
    );
    expect(gateway.sent, isEmpty);
  });

  test('sonuç cümleleri: replayed başarı, kuyruk, ret', () {
    final replayed = WorkerBoardingScanPage.resultFor(
      BoardingRecorded(
        BoardingEvent.fromJson(boardingEventJson(replayed: true)),
      ),
    );
    expect(replayed.tone, BoardingResultTone.success);
    expect(replayed.detail, contains('zaten kayıtlıydı'));
    expect(
      WorkerBoardingScanPage.resultFor(const BoardingQueued()).tone,
      BoardingResultTone.queued,
    );
    expect(
      WorkerBoardingScanPage.resultFor(
        const BoardingRejected(BoardingFailure.seatNotSelected),
      ).tone,
      BoardingResultTone.failure,
    );
  });
}
