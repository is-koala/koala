import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/models/pricing_breakdown.dart';

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

enum PaymentStatus {
  pendingCollection('PENDING_COLLECTION', 'Tahsilat Bekleniyor'),
  heldInEscrow('HELD_IN_ESCROW', 'Emanette'),
  releasedToWorker('RELEASED_TO_WORKER', 'Ödendi'),
  failed('FAILED', 'Başarısız'),
  refunded('REFUNDED', 'İade Edildi');

  const PaymentStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  bool get isPaid => this == PaymentStatus.releasedToWorker;

  /// Çalışanın dili ("Ödeme bekleniyor"); [displayName] işverenin ("Tahsilat
  /// Bekleniyor").
  String get workerLabel => switch (this) {
    PaymentStatus.pendingCollection => 'Ödeme bekleniyor',
    PaymentStatus.heldInEscrow => 'Emanette',
    PaymentStatus.releasedToWorker => 'Ödendi',
    PaymentStatus.failed => 'Ödeme alınamadı',
    PaymentStatus.refunded => 'İade edildi',
  };

  String get workerNote => switch (this) {
    PaymentStatus.pendingCollection =>
      'İşveren ücreti henüz güvenceye almadı; mesai o zaman başlayabilir.',
    PaymentStatus.heldInEscrow =>
      'Ücret Koala güvencesinde; iş tamamlanınca size aktarılır.',
    PaymentStatus.releasedToWorker => 'Ücret hesabınıza aktarıldı.',
    PaymentStatus.failed =>
      'İşverenin ödemesi tamamlanamadı; işveren yeniden deneyebilir.',
    PaymentStatus.refunded => 'Ücret işverene iade edildi.',
  };

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

/// Kabul edilmiş başvurunun dönüştüğü iş (`MyAssignmentDto`).
class Assignment {
  const Assignment({
    required this.id,
    required this.job,
    required this.status,
    required this.paymentStatus,
    this.assignmentDateTime,
    this.worker,
    this.actualCompletionDateTime,
    this.workHours = 0,
    this.workerPayout,
    this.totalCharged,
    this.pricing,
    this.messaging = MessagingAvailability.paymentRequired,
    this.createdAt,
    this.confirmedAt,
    this.expectedCompletionDateTime,
    this.paymentSecuredAt,
    this.application,
    this.employer,
    this.company,
    this.cancellation,
    this.payout,
    this.myReview,
    this.counterpartyReviewed = false,
    this.transport,
  });

  final String id;

  final Job job;

  final AssignmentStatus status;
  final PaymentStatus paymentStatus;
  final JobCreator? worker;

  final DateTime? assignmentDateTime;
  final DateTime? actualCompletionDateTime;

  /// İş bitmeden 0.
  final int workHours;

  /// Komisyon düşülmüş tutar; çalışan görünümünde tek fiyat alanı.
  final double? workerPayout;

  /// Yalnız işverene gönderiliyor; çalışanda `null`.
  final double? totalCharged;

  /// Yayımlamada sabitlenen fiyat snapshot'ı; ödeme onayı bunu gösterir. Yalnız
  /// işveren görünümünde dolu; çalışan kabuğu bu alandan satır çizmez.
  final PricingBreakdown? pricing;

  /// Alanlar yoksa kapı kapalı sayılıyor: eski sunucu da ödeme öncesi sohbeti
  /// reddediyor.
  final MessagingAvailability messaging;

  /// Zaman çizelgesi damgaları; hepsi opsiyonel, gelmezse satır çizilmez.
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final DateTime? expectedCompletionDateTime;
  final DateTime? paymentSecuredAt;

  /// Sunucu göndermiyorsa `null`.
  final AssignmentApplication? application;

  /// Bireysel ilanda işveren kartı buradan; yoksa ilan detayının `creator`'ı.
  final JobCreator? employer;

  /// Bireysel ilanda ve eski sunucuda `null`; o zaman [Job.companyId].
  final JobCompany? company;

  /// Liste özeti; ek istek atmadan kartı çizmek için.
  final Cancellation? cancellation;

  final PayoutSummary? payout;

  /// Görüntüleyenin değerlendirmesi; "Değerlendir" düğmesinin kapısı **bu
  /// alan**. Eski sunucuda da `null`: düğme görünür, ikinciyi `409` karşılar.
  final Review? myReview;

  /// Yalnız varlık bilgisi; küçük bir rozetten fazlası çizilmez.
  final bool counterpartyReviewed;

  /// Plan yoksa ya da eski sunucuda `null`.
  final AssignmentTransport? transport;

  bool get isPaidOut =>
      status == AssignmentStatus.completed && paymentStatus.isPaid;

  /// Çalışan kabul etti ama ücret emanete alınmadı: işveren ödeme başlatabilir.
  bool get needsEmployerPayment =>
      status == AssignmentStatus.confirmed &&
      (paymentStatus == PaymentStatus.pendingCollection ||
          paymentStatus == PaymentStatus.failed);

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'];
    return Assignment(
      id: '${json['id']}',
      job: Job.fromJson((json['job'] as Map<String, dynamic>?) ?? const {}),
      status: AssignmentStatus.fromCode(json['status']),
      paymentStatus: PaymentStatus.fromCode(json['paymentStatus']),
      worker: switch (json['worker']) {
        final Map<String, dynamic> value => JobCreator.fromJson(value),
        _ => null,
      },
      assignmentDateTime: _parseDate(json['assignmentDateTime']),
      actualCompletionDateTime: _parseDate(json['actualCompletionDateTime']),
      workHours: (json['workHours'] as num?)?.toInt() ?? 0,
      workerPayout: (json['workerPayout'] as num?)?.toDouble(),
      totalCharged: (json['totalCharged'] as num?)?.toDouble(),
      pricing: switch (pricing) {
        null => null,
        final Map<String, dynamic> value => PricingBreakdown.fromJson(value),
        _ => throw const FormatException('pricing alanı geçersiz.'),
      },
      messaging: MessagingAvailability.fromJson(json),
      createdAt: _parseDate(json['createdAt']),
      confirmedAt: _parseDate(json['confirmedAt']),
      expectedCompletionDateTime: _parseDate(
        json['expectedCompletionDateTime'],
      ),
      paymentSecuredAt: _parseDate(json['paymentSecuredAt']),
      application: switch (json['application']) {
        final Map<String, dynamic> value => AssignmentApplication.fromJson(
          value,
        ),
        _ => null,
      },
      employer: switch (json['employer']) {
        final Map<String, dynamic> value => JobCreator.fromJson(value),
        _ => null,
      },
      company: switch (json['company']) {
        final Map<String, dynamic> value => JobCompany.fromJson(value),
        _ => null,
      },
      cancellation: switch (json['cancellation']) {
        final Map<String, dynamic> value => Cancellation.fromJson(value),
        _ => null,
      },
      payout: switch (json['payout']) {
        final Map<String, dynamic> value => PayoutSummary.fromJson(value),
        _ => null,
      },
      myReview: switch (json['myReview']) {
        final Map<String, dynamic> value => Review.fromJson(value),
        _ => null,
      },
      counterpartyReviewed: json['counterpartyReviewed'] as bool? ?? false,
      transport: AssignmentTransport.parse(json['transport']),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Başvurunun damgaları; atama için yanıt anı kabul anıdır.
class AssignmentApplication {
  const AssignmentApplication({
    required this.id,
    this.applicationDateTime,
    this.answeredDateTime,
  });

  final String id;
  final DateTime? applicationDateTime;
  final DateTime? answeredDateTime;

  factory AssignmentApplication.fromJson(Map<String, dynamic> json) {
    return AssignmentApplication(
      id: '${json['id'] ?? ''}',
      applicationDateTime: Assignment._parseDate(json['applicationDateTime']),
      answeredDateTime: Assignment._parseDate(json['answeredDateTime']),
    );
  }
}

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
