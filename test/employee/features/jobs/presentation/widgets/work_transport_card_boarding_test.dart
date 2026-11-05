import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/pending_boarding.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/work_transport_card.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/pump.dart';
import '../../../../../support/transport_fixtures.dart';

AssignmentTransport _transport({Map<String, Object?>? boarding}) =>
    AssignmentTransport.parse(
      assignmentTransportJson(
        seats: [
          {...seatJson(), 'boarding': ?boarding},
        ],
      ),
    )!;

PendingBoarding _pending({bool failed = false}) {
  final entry = PendingBoarding(
    clientEventId: 'cid-1',
    userId: 'worker-1',
    shuttleId: shuttleUuid,
    token: shuttleTokenValue,
    capturedAt: DateTime.utc(2026, 9, 20, 3, 41),
    assignmentId: 'asg-1',
    direction: ShuttleDirection.outbound,
  );
  return failed ? entry.asFailed(BoardingFailure.tokenExpired) : entry;
}

void main() {
  late List<ShuttleDirection> scans;
  late List<ShuttleDirection> qrs;
  late List<String> dismissed;

  setUp(() {
    scans = [];
    qrs = [];
    dismissed = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    required AssignmentTransport transport,
    bool canBoard = true,
    List<PendingBoarding> pending = const [],
    Brightness brightness = Brightness.light,
  }) => pumpInApp(
    tester,
    SingleChildScrollView(
      child: WorkTransportCard(
        transport: transport,
        canSelectSeat: true,
        canBoard: canBoard,
        onScanShuttleQr: scans.add,
        onShowMyQr: qrs.add,
        pendingBoardings: {ShuttleDirection.outbound: pending},
        onDismissBoarding: dismissed.add,
      ),
    ),
    brightness: brightness,
  );

  for (final brightness in Brightness.values) {
    testWidgets('binilmemiş koltukta iki biniş yolu (${brightness.name})', (
      tester,
    ) async {
      await pump(tester, transport: _transport(), brightness: brightness);

      final scan = find.byKey(const ValueKey('work-transport-scan-OUTBOUND'));
      final myQr = find.byKey(const ValueKey('work-transport-my-qr-OUTBOUND'));
      await tester.ensureVisible(scan);
      await tester.tap(scan);
      await tester.ensureVisible(myQr);
      await tester.tap(myQr);

      expect(scans, [ShuttleDirection.outbound]);
      expect(qrs, [ShuttleDirection.outbound]);
    });
  }

  testWidgets('binilmiş koltukta saat yazılır, düğme yok', (tester) async {
    await pump(
      tester,
      transport: _transport(
        boarding: {'kind': 'BOARDED', 'occurredAt': '2026-09-20T03:41:00Z'},
      ),
    );

    expect(
      find.byKey(const ValueKey('work-transport-boarded-OUTBOUND')),
      findsOne,
    );
    expect(
      find.text(
        WorkTransportCard.boardedLine(DateTime.utc(2026, 9, 20, 3, 41)),
      ),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('work-transport-scan-OUTBOUND')),
      findsNothing,
    );
  });

  testWidgets('işveren binmedi dediyse uyarı ve yeniden okutma yolu', (
    tester,
  ) async {
    await pump(
      tester,
      transport: _transport(
        boarding: {'kind': 'NO_SHOW', 'occurredAt': '2026-09-20T03:50:00Z'},
      ),
    );

    expect(find.text(WorkTransportCard.noShowText), findsOne);
    expect(
      find.byKey(const ValueKey('work-transport-scan-OUTBOUND')),
      findsOne,
    );
  });

  testWidgets('bekleyen okutma bilgisi düğmelerin yerini alır', (tester) async {
    await pump(tester, transport: _transport(), pending: [_pending()]);

    expect(find.text(WorkTransportCard.boardingQueuedText), findsOne);
    expect(
      find.byKey(const ValueKey('work-transport-scan-OUTBOUND')),
      findsNothing,
    );
  });

  testWidgets('reddedilen okutma işverenden işaret istemeyi söyler', (
    tester,
  ) async {
    await pump(
      tester,
      transport: _transport(),
      pending: [_pending(failed: true)],
    );

    expect(
      find.text(
        BoardingFailure.tokenExpired.message(
          BoardingActor.worker,
          queued: true,
        ),
      ),
      findsOne,
    );
    await tester.ensureVisible(find.text('Tamam'));
    await tester.tap(find.text('Tamam'));
    expect(dismissed, ['cid-1']);
  });

  testWidgets('kapanmış atamada biniş düğmesi yok', (tester) async {
    await pump(tester, transport: _transport(), canBoard: false);

    expect(
      find.byKey(const ValueKey('work-transport-scan-OUTBOUND')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('work-transport-my-qr-OUTBOUND')),
      findsNothing,
    );
  });
}
