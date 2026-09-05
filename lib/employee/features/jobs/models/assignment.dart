import 'package:koala/employee/features/home/models/job.dart';

/// Atamanın durumu. Backend `AssignmentStatus` karşılığı.
enum AssignmentStatus {
  pendingConfirmation('PENDING_CONFIRMATION', 'Onay Bekleniyor'),
  confirmed('CONFIRMED', 'Onaylandı'),
  inProgress('IN_PROGRESS', 'Devam Ediyor'),
  completed('COMPLETED', 'Tamamlandı'),
  rejected('REJECTED', 'Reddedildi'),
  cancelled('CANCELLED', 'İptal Edildi');

  const AssignmentStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  static AssignmentStatus fromCode(Object? value) {
    return AssignmentStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => AssignmentStatus.confirmed,
    );
  }
}

/// Ödemenin durumu. Backend `PaymentStatus` karşılığı.
enum PaymentStatus {
  pendingCollection('PENDING_COLLECTION', 'Tahsilat Bekleniyor'),
  heldInEscrow('HELD_IN_ESCROW', 'Emanette'),
  releasedToWorker('RELEASED_TO_WORKER', 'Ödendi'),
  failed('FAILED', 'Başarısız'),
  refunded('REFUNDED', 'İade Edildi');

  const PaymentStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Para çalışana geçti mi.
  bool get isPaid => this == PaymentStatus.releasedToWorker;

  /// Tahsilat emanet hesaba geçti mi veya çalışana ödendi mi.
  bool get isSecured =>
      this == PaymentStatus.heldInEscrow ||
      this == PaymentStatus.releasedToWorker;

  static PaymentStatus fromCode(Object? value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => PaymentStatus.pendingCollection,
    );
  }
}

/// Kabul edilmiş bir başvurunun dönüştüğü iş.
///
/// `GET /users/me/assignments` yanıtındaki `MyAssignmentDto` karşılığı.
/// Başvuru kabul edilene kadar iş bir [JobApplication]; kabul edildikten
/// sonrası burada izleniyor.
class Assignment {
  const Assignment({
    required this.id,
    required this.job,
    required this.status,
    required this.paymentStatus,
    this.assignmentDateTime,
    this.actualCompletionDateTime,
    this.workHours = 0,
    this.workerPayout,
    this.totalCharged,
  });

  final String id;

  /// Atamanın bağlı olduğu ilanın özeti.
  final Job job;

  final AssignmentStatus status;
  final PaymentStatus paymentStatus;

  final DateTime? assignmentDateTime;
  final DateTime? actualCompletionDateTime;

  /// Çalışılan saat. İş bitmeden 0.
  final int workHours;

  /// Çalışanın eline geçecek tutar (komisyon düşülmüş).
  final double? workerPayout;

  /// İşverenden tahsil edilen toplam.
  final double? totalCharged;

  /// İş bitti ve para çalışana geçti mi.
  bool get isPaidOut =>
      status == AssignmentStatus.completed && paymentStatus.isPaid;

  /// Çalışan atamayı kabul etti ama ücret henüz emanete alınmadıysa işveren
  /// checkout'u başlatabilir. Bekleyen çalışan cevabında ödeme alınmaz.
  bool get needsEmployerPayment =>
      status == AssignmentStatus.confirmed &&
      (paymentStatus == PaymentStatus.pendingCollection ||
          paymentStatus == PaymentStatus.failed);

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: '${json['id']}',
      job: Job.fromJson((json['job'] as Map<String, dynamic>?) ?? const {}),
      status: AssignmentStatus.fromCode(json['status']),
      paymentStatus: PaymentStatus.fromCode(json['paymentStatus']),
      assignmentDateTime: _parseDate(json['assignmentDateTime']),
      actualCompletionDateTime: _parseDate(json['actualCompletionDateTime']),
      workHours: (json['workHours'] as num?)?.toInt() ?? 0,
      workerPayout: (json['workerPayout'] as num?)?.toDouble(),
      totalCharged: (json['totalCharged'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Sayfalı atama yanıtı.
class AssignmentPage {
  const AssignmentPage({
    this.assignments = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<Assignment> assignments;
  final int page;
  final int totalElements;
  final bool last;

  factory AssignmentPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return AssignmentPage(
      assignments: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(Assignment.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
