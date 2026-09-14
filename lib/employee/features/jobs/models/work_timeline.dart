import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/product/extensions/date_extensions.dart';

/// Zaman çizelgesinin bir satırı: ne oldu, ne zaman, varsa kısa bir ayrıntı.
class WorkTimelineEntry {
  const WorkTimelineEntry({required this.label, required this.at, this.detail});

  final String label;
  final DateTime at;
  final String? detail;
}

/// Bir işin zaman çizelgesi: başvurudan hakedişe kadar damgalanmış her an.
///
/// **Yalnızca damgası olan olay çiziliyor.** Sunucu bir alanı göndermiyorsa
/// (koala-backend#282 henüz gelmediyse `application`, `createdAt`,
/// `confirmedAt`, `paymentSecuredAt`, `payout` yok) o satır gizli; mevcut
/// damgalar — `assignmentDateTime`, mesai oturumları,
/// `actualCompletionDateTime`, iptal kaydı — kendi başlarına çalışıyor.
/// Satırlar zamana göre sıralanıyor, ekranda hangi sırayla yazılacağına
/// burası değil damgalar karar veriyor.
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

    // İşverenin yanıtı: atamada kabul anı; reddedilen başvuruda ret anı.
    // Yanıt damgası yoksa atamanın açıldığı an aynı olayı temsil ediyor.
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

    // Aynı ana düşen iki olay (kabul ve atamanın açılması gibi) eklenme
    // sırasını korusun diye kararlı sıralama.
    final indexed = entries.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.at.compareTo(b.$2.at);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return indexed.map((pair) => pair.$2).toList(growable: false);
  }
}
