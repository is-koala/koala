import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';

Map<String, dynamic> sessionBody({
  String? checkOutAt = '2026-03-10T17:30:00Z',
  int? minutes = 480,
}) {
  return {
    'id': 'ws_1',
    'jobAssignmentId': 'asg_1',
    'checkInAt': '2026-03-10T09:30:00Z',
    'checkOutAt': checkOutAt,
    'checkInLatitude': 39.92,
    'checkInLongitude': 32.85,
    'minutes': minutes,
  };
}

void main() {
  group('WorkSession', () {
    test('sunucu gövdesi modele çevrilir', () {
      final session = WorkSession.fromJson(sessionBody());

      expect(session.id, 'ws_1');
      expect(session.assignmentId, 'asg_1');
      expect(session.minutes, 480);
      expect(session.checkInLatitude, 39.92);
    });

    // Konum isteğe bağlı; sunucu gövdesiz isteği de kabul ediyor.
    test('konumsuz oturumda koordinatlar null', () {
      final body = sessionBody()
        ..remove('checkInLatitude')
        ..remove('checkInLongitude');

      final session = WorkSession.fromJson(body);

      expect(session.checkInLatitude, isNull);
      expect(session.checkInLongitude, isNull);
    });

    // Açık oturum: sıradaki eylem çıkış.
    test('çıkışı olmayan oturum açık sayılır', () {
      expect(
        WorkSession.fromJson(sessionBody(checkOutAt: null)).isOpen,
        isTrue,
      );
    });

    test('çıkışı olan oturum kapalı sayılır', () {
      expect(WorkSession.fromJson(sessionBody()).isOpen, isFalse);
    });

    // Kapalı oturumda süre sunucunun yazdığı dakikadan geliyor.
    test('kapalı oturumun süresi sunucunun dakikası', () {
      expect(
        WorkSession.fromJson(sessionBody()).elapsed,
        const Duration(minutes: 480),
      );
    });

    test('dakika gelmezse süre giriş ve çıkış farkından hesaplanır', () {
      final session = WorkSession.fromJson(sessionBody(minutes: null));

      expect(session.elapsed, const Duration(hours: 8));
    });

    // Açık oturumda saat işliyor: süre o an hesaplanmalı, donuk kalmamalı.
    test('açık oturumun süresi o anki zamandan hesaplanır', () {
      final body = sessionBody(checkOutAt: null, minutes: null)
        ..['checkInAt'] = DateTime.now()
            .subtract(const Duration(minutes: 30))
            .toUtc()
            .toIso8601String();

      final session = WorkSession.fromJson(body);

      expect(session.elapsed.inMinutes, closeTo(30, 1));
    });

    test('girişi olmayan oturumun süresi sıfır', () {
      final body = sessionBody()..remove('checkInAt');

      expect(WorkSession.fromJson(body).elapsed, Duration.zero);
    });
  });
}
