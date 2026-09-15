import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_start_on.dart';

void main() {
  final now = DateTime.parse('2026-09-15T12:00:00+03:00');

  group('JobStartOn.preset etiketleri', () {
    test('çiplerin kullanıcıya görünen adları Türkçe', () {
      expect(JobStartOn.today.label, 'Bugün');
      expect(JobStartOn.tomorrow.label, 'Yarın');
      expect(JobStartOn.weekend.label, 'Hafta sonu');
      expect(JobStartOn.thisWeek.label, 'Bu hafta');
    });
  });

  group('JobStartOn.toWindow', () {
    test('belirli gün İstanbul gün sınırına gider', () {
      final window = JobStartOn.calendarDay(
        DateTime(2026, 9, 20),
      ).toWindow(now: now);

      expect(
        window.startFrom.toUtc().toIso8601String(),
        '2026-09-19T21:00:00.000Z',
      );
      expect(
        window.startTo.toUtc().toIso8601String(),
        '2026-09-20T20:59:59.999Z',
      );
    });

    test('bugün ve yarın o anın Türkiye günü', () {
      expect(
        JobStartOn.today.toWindow(now: now).startFrom.toUtc().toIso8601String(),
        '2026-09-14T21:00:00.000Z',
      );
      expect(
        JobStartOn.today.toWindow(now: now).startTo.toUtc().toIso8601String(),
        '2026-09-15T20:59:59.999Z',
      );
      expect(
        JobStartOn.tomorrow
            .toWindow(now: now)
            .startFrom
            .toUtc()
            .toIso8601String(),
        '2026-09-15T21:00:00.000Z',
      );
      expect(
        JobStartOn.tomorrow
            .toWindow(now: now)
            .startTo
            .toUtc()
            .toIso8601String(),
        '2026-09-16T20:59:59.999Z',
      );
    });

    test('bu hafta Pazartesi–Pazar, hafta sonu Cumartesi–Pazar', () {
      expect(
        JobStartOn.thisWeek
            .toWindow(now: now)
            .startFrom
            .toUtc()
            .toIso8601String(),
        '2026-09-13T21:00:00.000Z',
      );
      expect(
        JobStartOn.thisWeek
            .toWindow(now: now)
            .startTo
            .toUtc()
            .toIso8601String(),
        '2026-09-20T20:59:59.999Z',
      );
      expect(
        JobStartOn.weekend
            .toWindow(now: now)
            .startFrom
            .toUtc()
            .toIso8601String(),
        '2026-09-18T21:00:00.000Z',
      );
      expect(
        JobStartOn.weekend.toWindow(now: now).startTo.toUtc().toIso8601String(),
        '2026-09-20T20:59:59.999Z',
      );
    });

    test('UTC gece yarısından sonra İstanbul günü kaymıyor', () {
      // 15 Eylül 00:30 İstanbul = 14 Eylül 21:30 UTC.
      final justAfterMidnight = DateTime.parse('2026-09-14T21:30:00.000Z');

      expect(
        JobStartOn.today
            .toWindow(now: justAfterMidnight)
            .startFrom
            .toUtc()
            .toIso8601String(),
        '2026-09-14T21:00:00.000Z',
      );
    });
  });

  group('IstanbulCalendar.wallClockOf', () {
    test('UTC Instant İstanbul duvar saatine kayar', () {
      final wall = IstanbulCalendar.wallClockOf(
        DateTime.utc(2026, 9, 10, 9, 5),
      );
      expect(wall.isUtc, isFalse);
      expect(wall.year, 2026);
      expect(wall.month, 9);
      expect(wall.day, 10);
      expect(wall.hour, 12);
      expect(wall.minute, 5);
    });

    test('UTC gece İstanbul ertesi güne taşır', () {
      final wall = IstanbulCalendar.wallClockOf(
        DateTime.utc(2026, 9, 10, 21, 30),
      );
      expect(wall.day, 11);
      expect(wall.hour, 0);
      expect(wall.minute, 30);
    });
  });
}
