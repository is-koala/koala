import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/product/extensions/date_extensions.dart';

enum MyJobStatus {
  pending, // Başvuruldu, onay bekleniyor
  approved, // Onaylandı, gidilmesi bekleniyor
  completed, // İş bitti, ödeme bekleniyor
  past, // Ödeme alındı, geçmişe taşındı
}

extension MyJobStatusExtension on MyJobStatus {
  String get displayName {
    switch (this) {
      case MyJobStatus.pending:
        return 'Başvuru Bekliyor';
      case MyJobStatus.approved:
        return 'Onaylandı';
      case MyJobStatus.completed:
        return 'Ödeme Bekleniyor';
      case MyJobStatus.past:
        return 'Tamamlandı';
    }
  }

  String get description {
    switch (this) {
      case MyJobStatus.pending:
        return 'Başvurunuz değerlendiriliyor';
      case MyJobStatus.approved:
        return 'İşe gitmeniz bekleniyor';
      case MyJobStatus.completed:
        return 'Ödemeniz işleniyor';
      case MyJobStatus.past:
        return 'Ödeme alındı';
    }
  }
}

class MyJob {
  final String id;
  final String title;
  final String company;
  final String? companyId;
  final String description;
  final String date;
  final double price;
  final MyJobStatus status;

  const MyJob({
    required this.id,
    required this.title,
    required this.company,
    this.companyId,
    required this.description,
    required this.date,
    required this.price,
    required this.status,
  });

  /// Bir atamayı ekranın bildiği [MyJob] durumlarına çevirir.
  ///
  /// İptal edilmiş ve reddedilmiş atamalar için `null` dönüyor.
  /// TODO(backend): Bunların arayüzde karşılığı yok; "Tamamlandı" olarak
  /// göstermek yanlış bilgi olurdu, o yüzden şimdilik listeye hiç
  /// girmiyorlar — tasarıma yeni bir durum eklenmeli.
  static MyJob? fromAssignment(Assignment assignment) {
    final status = switch (assignment.status) {
      AssignmentStatus.pendingConfirmation ||
      AssignmentStatus.confirmed ||
      AssignmentStatus.inProgress => MyJobStatus.approved,
      // İş bitti: para çalışana geçtiyse geçmiş, geçmediyse ödeme bekliyor.
      AssignmentStatus.completed =>
        assignment.paymentStatus.isPaid
            ? MyJobStatus.past
            : MyJobStatus.completed,
      AssignmentStatus.rejected || AssignmentStatus.cancelled => null,
    };

    if (status == null) return null;

    final job = assignment.job;

    return MyJob(
      id: assignment.id,
      title: job.title,
      company: job.company ?? 'Bireysel İlan',
      companyId: null,
      description: job.subtitle,
      date: assignment.assignmentDateTime?.asShortDate ?? '',
      // Çalışanın eline geçecek tutar komisyon düşülmüş hâli; ilandaki ücret
      // değil o gösterilmeli.
      price: assignment.workerPayout ?? job.price,
      status: status,
    );
  }
}
