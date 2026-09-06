import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/timesheet_queue_status.dart';

import '../../../../../support/pump.dart';

TimesheetEvent event({
  TimesheetEventStatus status = TimesheetEventStatus.pending,
}) {
  return TimesheetEvent(
    clientEventId: 'event-1',
    userId: 'user-a',
    assignmentId: 'assignment-a',
    action: TimesheetEventAction.checkOut,
    capturedAt: DateTime.parse('2026-09-06T10:00:00Z'),
    monotonicMicros: 42,
    status: status,
    supportMessage: status == TimesheetEventStatus.requiresSupport
        ? 'Mesai kaydı uzlaştırılamadı.'
        : null,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('bekleyen kayıt ${brightness.name} temada dar ekrana sığar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpInApp(
        tester,
        TimesheetQueueStatus(events: [event()]),
        brightness: brightness,
      );

      expect(find.text('Kaydedildi, gönderilmeyi bekliyor.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('destek gereken kayıt destek eylemini açar', (tester) async {
    var supportOpened = false;
    await pumpInApp(
      tester,
      TimesheetQueueStatus(
        events: [event(status: TimesheetEventStatus.requiresSupport)],
        onSupport: () => supportOpened = true,
      ),
    );

    expect(find.text('Mesai kaydı uzlaştırılamadı.'), findsOneWidget);
    await tester.tap(find.text('Destek Al'));
    expect(supportOpened, isTrue);
  });
}
