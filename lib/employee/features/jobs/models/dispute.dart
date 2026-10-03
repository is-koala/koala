import 'package:koala/employee/features/home/models/job_detail.dart';

/// Uyuşmazlığın durumu. Backend `DisputeStatus` karşılığı.
enum DisputeStatus {
  open('OPEN', 'Açık'),
  underReview('UNDER_REVIEW', 'İnceleniyor'),
  resolved('RESOLVED', 'Sonuçlandı');

  const DisputeStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  static DisputeStatus fromCode(Object? value) {
    return DisputeStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => DisputeStatus.open,
    );
  }
}

/// Uyuşmazlığın sonucu. Backend `DisputeResolution` karşılığı.
enum DisputeResolution {
  releaseToWorker('RELEASE_TO_WORKER', 'Ücret çalışana ödendi'),
  refundEmployer('REFUND_EMPLOYER', 'Ücret işverene iade edildi'),
  dismissed('DISMISSED', 'Talep reddedildi');

  const DisputeResolution(this.code, this.displayName);

  final String code;
  final String displayName;

  static DisputeResolution? fromCode(Object? value) {
    if (value == null) return null;

    for (final resolution in DisputeResolution.values) {
      if (resolution.code == value) return resolution;
    }
    return null;
  }
}

/// Bir atama üzerindeki uyuşmazlık.
///
/// Backend `DisputeDto` karşılığı. Yalnızca para emanetteyken açılabiliyor
/// ve atama başına aynı anda tek açık uyuşmazlık oluyor. Açık uyuşmazlık
/// emanetteki parayı donduruyor: çalışana ödeme yapılmıyor ve sunucunun
/// kendiliğinden tamamlaması duruyor.
class Dispute {
  const Dispute({
    required this.id,
    required this.assignmentId,
    required this.status,
    this.openedBy,
    this.reason,
    this.resolution,
    this.resolutionNote,
    this.resolvedAt,
    this.createdAt,
  });

  final String id;

  final String assignmentId;

  final DisputeStatus status;

  /// Uyuşmazlığı açan taraf. Backend `SafeUserDto` döndürüyor.
  final JobCreator? openedBy;

  /// Açılış gerekçesi; sunucu zorunlu tutuyor, en fazla 2000 karakter.
  final String? reason;

  /// Sonuç ve destek ekibinin notu; sonuçlanmamış uyuşmazlıkta `null`.
  final DisputeResolution? resolution;
  final String? resolutionNote;

  final DateTime? resolvedAt;
  final DateTime? createdAt;

  /// Hâlâ sürüyor mu. Süren uyuşmazlık ikinci bir uyuşmazlığı engelliyor.
  bool get isOpen => status != DisputeStatus.resolved;

  /// En yeni önde; tarihi olmayan en sona, eşitlikte sunucunun sırası.
  ///
  /// Uyuşmazlık özetini (iş detayı) ve ekranı (kanıtlar) sıralayan tek yer:
  /// ikisi kendi karşılaştırıcısını yazdığında eşitlikte ayrı sırayla
  /// diziliyordu. `List.sort` kararlı olmadığı için sunucu sırası dizinle
  /// korunuyor.
  static List<Dispute> newestFirst(Iterable<Dispute> disputes) {
    final ordered = [
      for (final (index, dispute) in disputes.indexed)
        (index: index, dispute: dispute),
    ];
    ordered.sort((a, b) {
      final left = a.dispute.createdAt;
      final right = b.dispute.createdAt;
      if (left == null && right == null) return a.index.compareTo(b.index);
      if (left == null) return 1;
      if (right == null) return -1;
      final byDate = right.compareTo(left);
      return byDate != 0 ? byDate : a.index.compareTo(b.index);
    });
    return [for (final entry in ordered) entry.dispute];
  }

  factory Dispute.fromJson(Map<String, dynamic> json) {
    final openedBy = json['openedBy'];

    return Dispute(
      id: '${json['id']}',
      assignmentId: '${json['jobAssignmentId']}',
      status: DisputeStatus.fromCode(json['status']),
      openedBy: openedBy is Map<String, dynamic>
          ? JobCreator.fromJson(openedBy)
          : null,
      reason: json['reason'] as String?,
      resolution: DisputeResolution.fromCode(json['resolution']),
      resolutionNote: json['resolutionNote'] as String?,
      resolvedAt: _parseDate(json['resolvedAt']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
