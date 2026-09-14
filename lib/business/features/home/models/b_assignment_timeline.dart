import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/product/network/json_field.dart';

/// Atamanın zaman çizelgesi damgaları, işverenin gördüğü hâliyle.
///
/// `MyAssignmentDto`'nun koala-backend#282 ile gelen alanları
/// (`application`, `createdAt`, `confirmedAt`, `paymentSecuredAt`,
/// `expectedCompletionDateTime`, `payout`) burada okunuyor. Hepsi
/// **opsiyonel**: bu alanları göndermeyen sunucuda `null` kalıyor ve panel o
/// değerin yerine "—" yazıyor.
///
/// [Assignment] modeline eklenmedi: aynı alanlar çalışan tarafı için ayrı bir
/// değişiklikte oraya giriyor (is-koala/koala#177). İki değişiklik aynı
/// dosyaya dokunmasın diye işveren paneli kendi okuyucusunu taşıyor; çalışan
/// tarafı yerleşince bu sınıf oradaki alanlardan beslenebilir.
class BAssignmentTimeline {
  const BAssignmentTimeline({
    this.appliedAt,
    this.acceptedAt,
    this.createdAt,
    this.confirmedAt,
    this.paymentSecuredAt,
    this.expectedCompletionAt,
    this.payout,
  });

  /// Damga taşımayan sunucu yanıtı için boş çizelge.
  static const BAssignmentTimeline empty = BAssignmentTimeline();

  /// Çalışanın başvurduğu an (`application.applicationDateTime`).
  final DateTime? appliedAt;

  /// İşverenin başvuruyu kabul ettiği an (`application.answeredDateTime`).
  /// Sözleşmeye göre kabul anı budur; `assignmentDateTime` değil.
  final DateTime? acceptedAt;

  /// Atama kaydının açıldığı an.
  final DateTime? createdAt;

  /// Çalışanın atamayı onayladığı an; henüz cevaplanmadıysa `null`.
  final DateTime? confirmedAt;

  /// Ödemenin emanete alındığı an: ilk başarılı ödeme denemesinin bitişi.
  final DateTime? paymentSecuredAt;

  /// Planlanan bitiş; belirlenmediyse `null`.
  final DateTime? expectedCompletionAt;

  /// Hakediş özeti; emanet çıkışa verilmediyse `null`.
  final BAssignmentPayout? payout;

  factory BAssignmentTimeline.fromJson(Map<String, dynamic> json) {
    final application = json['application'];
    final payout = json['payout'];

    return BAssignmentTimeline(
      appliedAt: application is Map<String, dynamic>
          ? JsonField.dateOrNull(application['applicationDateTime'])
          : null,
      acceptedAt: application is Map<String, dynamic>
          ? JsonField.dateOrNull(application['answeredDateTime'])
          : null,
      createdAt: JsonField.dateOrNull(json['createdAt']),
      confirmedAt: JsonField.dateOrNull(json['confirmedAt']),
      paymentSecuredAt: JsonField.dateOrNull(json['paymentSecuredAt']),
      expectedCompletionAt: JsonField.dateOrNull(
        json['expectedCompletionDateTime'],
      ),
      payout: payout is Map<String, dynamic>
          ? BAssignmentPayout.fromJson(payout)
          : null,
    );
  }
}

/// Atamanın hakediş kaydı (`AssignmentPayoutDto`): kimlik, durum kodu ve
/// paranın çalışanın hesabına ulaştığı doğrulanan an.
class BAssignmentPayout {
  const BAssignmentPayout({required this.id, this.status, this.completedAt});

  final String id;

  /// Backend `PayoutStatus` kodu, olduğu gibi. Bu ekran duruma göre karar
  /// vermiyor, yalnızca [completedAt] dolunca "hesaba geçti" yazıyor.
  final String? status;

  final DateTime? completedAt;

  factory BAssignmentPayout.fromJson(Map<String, dynamic> json) {
    return BAssignmentPayout(
      id: '${json['id']}',
      status: json['status'] as String?,
      completedAt: JsonField.dateOrNull(json['completedAt']),
    );
  }
}

/// İşverenin atama listesindeki tek satır: paylaşılan [Assignment] ve ona
/// eşlik eden zaman çizelgesi, aynı JSON'dan birlikte okunuyor.
class BEmployerAssignment {
  const BEmployerAssignment({
    required this.assignment,
    this.timeline = BAssignmentTimeline.empty,
  });

  final Assignment assignment;
  final BAssignmentTimeline timeline;

  factory BEmployerAssignment.fromJson(Map<String, dynamic> json) {
    return BEmployerAssignment(
      assignment: Assignment.fromJson(json),
      timeline: BAssignmentTimeline.fromJson(json),
    );
  }
}

/// `GET /jobs/{jobId}/assignments` ve `GET /users/me/assignments` sayfası,
/// işveren okuyucusuyla.
class BEmployerAssignmentPage {
  const BEmployerAssignmentPage({
    this.entries = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<BEmployerAssignment> entries;
  final int page;
  final int totalElements;
  final bool last;

  factory BEmployerAssignmentPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return BEmployerAssignmentPage(
      entries: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(BEmployerAssignment.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
