import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/product/extensions/date_extensions.dart';

class WorkTimelineEntry {
  const WorkTimelineEntry({required this.label, required this.at, this.detail});

  final String label;
  final DateTime at;
  final String? detail;
}

/// İşin zaman çizelgesi. **Yalnız damgası olan olay çizilir**; eski sunucuda
/// yeni alanlar yoksa o satırlar gizli. Sıra damgalardan gelir.
abstract final class WorkTimeline {
  static List<WorkTimelineEntry> build(
    MyJob job, {
    List<WorkSession> sessions = const [],
    Cancellation? cancellation,
  }) {
    final assignment = job.assignment;
    final entries = <WorkTimelineEntry>[];

    void add(String label, DateTime? at, {String? detail}) {
      if (at == null) return;
      entries.add(WorkTimelineEntry(label: label, at: at, detail: detail));
    }

    add('Başvurdunuz', job.applicationDateTime);

    // Yanıt damgası yoksa atamanın açıldığı an aynı olayı temsil eder.
    if (job.status == MyJobStatus.applicationRejected) {
      add('İşveren başvurunuzu reddetti', job.answeredDateTime);
    } else if (assignment != null) {
      add(
        'İşveren sizi seçti',
        job.answeredDateTime ??
            assignment.createdAt ??
            assignment.assignmentDateTime,
      );
    }

    add('İşi kabul ettiniz', assignment?.confirmedAt);
    add('Ödeme emanete alındı', assignment?.paymentSecuredAt);

    for (final session in sessions) {
      add('Mesaiye başladınız', session.checkInAt);
      add(
        'Mesaiyi bitirdiniz',
        session.checkOutAt,
        detail: session.elapsed.asWorkDuration,
      );
    }

    add('İş tamamlandı', assignment?.actualCompletionDateTime);

    final record = cancellation ?? assignment?.cancellation;
    if (record != null) {
      add(
        'İş iptal edildi',
        record.cancelledAt,
        detail: '${record.cancelledByParty.displayName} iptal etti',
      );
    }

    final payout = assignment?.payout;
    if (payout != null && payout.status == PayoutStatus.completed) {
      add('Hakedişiniz ödendi', payout.completedAt);
    }

    // Aynı ana düşen olaylar eklenme sırasını korusun.
    final indexed = entries.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.at.compareTo(b.$2.at);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return indexed.map((pair) => pair.$2).toList(growable: false);
  }
}
