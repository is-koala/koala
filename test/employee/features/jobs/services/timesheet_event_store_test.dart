import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late String databasePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('koala-timesheet-store-');
    databasePath = '${directory.path}/queue.db';
  });

  tearDown(() async {
    await databaseFactoryFfi.deleteDatabase(databasePath);
    await directory.delete(recursive: true);
  });

  test(
    'gerçek SQLite şeması yeniden açılınca FIFO, kullanıcı bölümü ve metadata korunur',
    () async {
      final first = SqfliteTimesheetEventStore(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final firstForA = _event(
        id: 'event-a-1',
        userId: 'user-a',
        monotonicMicros: 20,
      );
      final forB = _event(
        id: 'event-b-1',
        userId: 'user-b',
        monotonicMicros: 10,
      );
      final secondForA = _event(
        id: 'event-a-2',
        userId: 'user-a',
        monotonicMicros: 5,
      );

      await first.add(firstForA);
      await first.add(forB);
      await first.add(secondForA);
      await first.markRequiresSupport('event-a-2', 'Destek gerekiyor.');
      await first.setLastActiveUser('user-a');

      await expectLater(
        first.add(
          _event(id: 'event-a-1', userId: 'user-b', monotonicMicros: 99),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await first.close();

      final reopened = SqfliteTimesheetEventStore(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final eventsForA = await reopened.readForUser('user-a');

      expect(eventsForA.map((event) => event.clientEventId), [
        'event-a-1',
        'event-a-2',
      ]);
      expect(eventsForA.last.requiresSupport, isTrue);
      expect(eventsForA.last.supportMessage, 'Destek gerekiyor.');
      expect(
        (await reopened.readForUser('user-b')).single.clientEventId,
        'event-b-1',
      );
      expect(await reopened.readLastActiveUser(), 'user-a');

      await reopened.remove('event-a-1');
      expect(
        (await reopened.readForUser('user-a')).single.clientEventId,
        'event-a-2',
      );
      await reopened.setLastActiveUser(null);
      expect(await reopened.readLastActiveUser(), isNull);
      await reopened.close();
    },
  );
}

TimesheetEvent _event({
  required String id,
  required String userId,
  required int monotonicMicros,
}) {
  return TimesheetEvent(
    clientEventId: id,
    userId: userId,
    assignmentId: 'assignment-$userId',
    action: TimesheetEventAction.checkIn,
    capturedAt: DateTime.parse('2026-09-06T10:00:00Z'),
    monotonicMicros: monotonicMicros,
    latitude: 41.0082,
    longitude: 28.9784,
  );
}
