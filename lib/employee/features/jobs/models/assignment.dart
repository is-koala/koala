import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/product/models/pricing_breakdown.dart';

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

  /// İş detayında çalışana yazılan başlık: "Ödeme bekleniyor / Emanette /
  /// Ödendi / İade edildi". [displayName] işveren tarafının dili
  /// ("Tahsilat Bekleniyor"); çalışan tahsilat yapmıyor, ödeme bekliyor.
  String get workerLabel => switch (this) {
    PaymentStatus.pendingCollection => 'Ödeme bekleniyor',
    PaymentStatus.heldInEscrow => 'Emanette',
    PaymentStatus.releasedToWorker => 'Ödendi',
    PaymentStatus.failed => 'Ödeme alınamadı',
    PaymentStatus.refunded => 'İade edildi',
  };

  /// Başlığın altındaki tek cümlelik açıklama.
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
  });

  final String id;

  /// Atamanın bağlı olduğu ilanın özeti.
  final Job job;

  final AssignmentStatus status;
  final PaymentStatus paymentStatus;
  final JobCreator? worker;

  final DateTime? assignmentDateTime;
  final DateTime? actualCompletionDateTime;

  /// Çalışılan saat. İş bitmeden 0.
  final int workHours;

  /// Çalışanın eline geçecek tutar (komisyon düşülmüş). İki tarafa da
  /// geliyor; çalışan görünümünde tek fiyat alanı bu.
  final double? workerPayout;

  /// İşverenden tahsil edilen toplam. Sunucu yalnız işverene gönderiyor;
  /// görüntüleyen çalışansa `null` (koala-backend#294).
  final double? totalCharged;

  /// İlan yayımlanırken backend'in atamaya sabitlediği fiyat snapshot'ı.
  /// Ödeme onayı bu değeri gösterir; güncel komisyon tarifesiyle yenilenmez.
  ///
  /// Yalnız işveren görünümünde dolu: hizmet bedeli ve işveren toplamı
  /// çalışanın işi değil, sunucu ona `null` gönderiyor. Çalışan kabuğu bu
  /// alandan satır çizmez — gelse bile (eski sunucu) çizmez.
  final PricingBreakdown? pricing;

  /// Bu atama üzerinden sohbet açılabilir mi ve açılamıyorsa neden.
  ///
  /// `messagingAvailable` + `messagingAvailableReason` alanlarından geliyor.
  /// Alanlar yoksa kapı kapalı sayılıyor: eski sunucu da ödeme öncesi sohbeti
  /// reddediyor, düğme onu önceden gizliyor.
  final MessagingAvailability messaging;

  /// Zaman çizelgesinin sunucudan gelen damgaları (koala-backend#282).
  ///
  /// Hepsi **opsiyonel**: bu alanları göndermeyen sunucuda `null` kalıyor ve
  /// çizelge o satırı hiç çizmiyor. Eski damgalar ([assignmentDateTime],
  /// [actualCompletionDateTime]) değişmedi; yenileri onların arasını
  /// dolduruyor — atamanın açıldığı an, çalışanın onayı, ödemenin emanete
  /// alındığı an ve planlanan bitiş.
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final DateTime? expectedCompletionDateTime;
  final DateTime? paymentSecuredAt;

  /// Atamanın türediği başvuru: ne zaman başvurulduğu ve ne zaman kabul
  /// edildiği. Sunucu göndermiyorsa `null`.
  final AssignmentApplication? application;

  /// İlanı açan kişi (`SafeUserDto`). Bireysel ilanda işveren kartında adı
  /// ve fotoğrafı bu alandan geliyor; sunucu göndermiyorsa ilan detayının
  /// `creator` alanı yedek.
  final JobCreator? employer;

  /// İlanı açan şirket: kimlik, ad ve logo. Şirket ilanında dolu; bireysel
  /// ilanda ve eski sunucuda `null` — o zaman [Job.companyId] ve
  /// [Job.company] kullanılıyor.
  final JobCompany? company;

  /// Atama iptal edildiyse kaydın özeti. `GET .../cancellation` tam kaydı
  /// döndürüyor; buradaki, sunucu listeyle birlikte gönderdiğinde ek istek
  /// atmadan kartı çizmeye yarıyor.
  final Cancellation? cancellation;

  /// Hakediş özeti: sunucu ödeme çıkışı açtıysa durumu ve tamamlanma anı.
  final PayoutSummary? payout;

  /// Görüntüleyenin bu atamaya yazdığı değerlendirme; yazmadıysa `null`
  /// (koala-backend#293). "Değerlendir" düğmesinin kapısı **bu alan**:
  /// doluysa düğme yok, içerik doğrudan buradan yazılıyor. Alanı hiç
  /// göndermeyen eski sunucuda da `null` — düğme görünür, ikinci denemeyi
  /// sunucunun `409`u karşılar.
  final Review? myReview;

  /// Karşı taraf bu atamayı değerlendirdi mi. Yalnız varlık bilgisi; içerik
  /// ve yazar taşınmıyor, ekranda küçük bir rozetten fazlası çizilmiyor.
  /// Alan yoksa `false`.
  final bool counterpartyReviewed;

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
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Atamanın türediği başvurunun damgaları.
///
/// `MyAssignmentDto.application` (koala-backend#282): başvurunun kimliği,
/// başvuru anı ve işverenin yanıt anı — atama açısından yanıt anı kabul
/// anıdır. Zaman çizelgesinin ilk iki satırı buradan geliyor.
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
