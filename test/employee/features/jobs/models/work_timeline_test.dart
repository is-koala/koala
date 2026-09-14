import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/models/work_timeline.dart';

import '../../../../support/work_test_support.dart';

List<String> labelsOf(List<WorkTimelineEntry> entries) =>
    entries.map((entry) => entry.label).toList();

void main() {
  group('WorkTimeline.build', () {
    test('bütün damgalar geldiğinde satırlar zaman sırasında', () {
      final job = MyJob.fromAssignment(
        Assignment.fromJson(
          assignmentJson(
            status: 'COMPLETED',
            paymentStatus: 'RELEASED_TO_WORKER',
            actualCompletionDateTime: '2026-09-10T17:00:00Z',
            extra: timelineFieldsJson,
          ),
        ),
      );

      final entries = WorkTimeline.build(
        job,
        sessions: [WorkSession.fromJson(workSessionJson())],
      );

      expect(labelsOf(entries), [
        'Başvurdunuz',
        'İşveren sizi seçti',
        'İşi kabul ettiniz',
        'Ödeme emanete alındı',
        'Mesaiye başladınız',
        'Mesaiyi bitirdiniz',
        'İş tamamlandı',
        'Hakedişiniz ödendi',
      ]);
      expect(entries[1].at, DateTime.utc(2026, 9, 2, 8));
      expect(entries[5].detail, '7s 45dk');
    });

    // koala-backend#282 gelmeden: yalnız mevcut damgalar, eksik satır yok.
    test('eski sunucuda yalnız mevcut damgalar çizilir', () {
      final job = MyJob.fromAssignment(
        Assignment.fromJson(
          assignmentJson(
            status: 'COMPLETED',
            paymentStatus: 'PENDING_COLLECTION',
            actualCompletionDateTime: '2026-09-10T17:00:00Z',
          ),
        ),
      );

      final entries = WorkTimeline.build(
        job,
        sessions: [WorkSession.fromJson(workSessionJson())],
      );

      expect(labelsOf(entries), [
        'İşveren sizi seçti',
        'Mesaiye başladınız',
        'Mesaiyi bitirdiniz',
        'İş tamamlandı',
      ]);
      // Yanıt damgası yokken atamanın tarihi aynı olayı temsil ediyor.
      expect(entries.first.at, DateTime.utc(2026, 9, 8, 12));
    });

    test('hiç damga yoksa çizelge boş', () {
      final job = MyJob.fromAssignment(
        Assignment.fromJson(
          assignmentJson(
            status: 'PENDING_CONFIRMATION',
            paymentStatus: 'PENDING_COLLECTION',
            assignmentDateTime: null,
          ),
        ),
      );

      expect(WorkTimeline.build(job), isEmpty);
    });

    test('reddedilen başvuruda başvuru ve ret satırları', () {
      final job = MyJob.fromApplication(
        JobApplication.fromJson(
          applicationJson(
            status: 'REJECTED',
            answeredDateTime: '2026-09-03T14:00:00Z',
          ),
        ),
      )!;

      expect(labelsOf(WorkTimeline.build(job)), [
        'Başvurdunuz',
        'İşveren başvurunuzu reddetti',
      ]);
    });

    test('bekleyen başvuruda yalnız başvuru satırı', () {
      final job = MyJob.fromApplication(
        JobApplication.fromJson(applicationJson()),
      )!;

      expect(labelsOf(WorkTimeline.build(job)), ['Başvurdunuz']);
    });

    test('iptal kaydı çekilen tam kayıttan, yoksa atamanın özetinden', () {
      final embedded = MyJob.fromAssignment(
        Assignment.fromJson(
          assignmentJson(
            status: 'CANCELLED',
            paymentStatus: 'REFUNDED',
            extra: const {
              'cancellation': {
                'cancelledByParty': 'WORKER',
                'cancelledAt': '2026-09-09T12:00:00Z',
                'feeRate': '0',
                'feeAmount': '0',
                'refundAmount': '1000.00',
              },
            },
          ),
        ),
      );

      final fromEmbedded = WorkTimeline.build(embedded);
      expect(fromEmbedded.last.label, 'İş iptal edildi');
      expect(fromEmbedded.last.detail, 'Çalışan iptal etti');

      final fetched = Cancellation.fromJson({
        'id': 'cnc-1',
        'jobAssignmentId': 'assignment-1',
        'cancelledByParty': 'EMPLOYER',
        'reason': 'Etkinlik ertelendi',
        'feeRate': '0.25',
        'feeAmount': '250.00',
        'refundAmount': '750.00',
        'cancelledAt': '2026-09-09T13:00:00Z',
      });
      final fromFetched = WorkTimeline.build(embedded, cancellation: fetched);
      expect(fromFetched.last.detail, 'İşveren iptal etti');
      expect(fromFetched.last.at, DateTime.utc(2026, 9, 9, 13));
    });

    test('hakediş yalnız tamamlandığında satır olur', () {
      final job = MyJob.fromAssignment(
        Assignment.fromJson(
          assignmentJson(
            status: 'COMPLETED',
            paymentStatus: 'HELD_IN_ESCROW',
            extra: const {
              'payout': {
                'id': 'payout-1',
                'status': 'PROCESSING',
                'completedAt': null,
              },
            },
          ),
        ),
      );

      expect(
        labelsOf(WorkTimeline.build(job)),
        isNot(contains('Hakedişiniz ödendi')),
      );
    });
  });
}
