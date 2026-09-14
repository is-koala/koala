import 'package:koala/product/network/json_field.dart';

/// Çalışana yapılan ödeme çıkışının backend durumu.
///
/// Sözlük sunucunun `PayoutDto` açıklamasından (koala-backend#294):
/// `PENDING` çıkışa alındı ve sağlayıcı onayı bekleniyor, `PROCESSING`
/// sağlayıcı onayladı ve banka transferi yolda, `COMPLETED` banka
/// ekstresiyle doğrulandı, `FAILED` çıkış başarısız. "Hesabınıza geçti"
/// gibi kesin bir ifade **yalnız** `COMPLETED`'da yazılıyor; öncesinde para
/// yolda, henüz hesapta değil.
enum PayoutStatus {
  pending(
    'PENDING',
    'Çıkışa alındı',
    'Çıkışa alındı — sağlayıcı onayı bekleniyor',
  ),
  processing(
    'PROCESSING',
    'Transfer yolda',
    'Onaylandı — banka transferi yolda',
  ),
  completed(
    'COMPLETED',
    'Hesabınıza geçti',
    'Hesabınıza geçti (ekstre ile doğrulandı)',
  ),
  failed('FAILED', 'Başarısız', 'Çıkış başarısız');

  const PayoutStatus(this.code, this.displayName, this.description);

  final String code;

  /// Rozet metni; kısa.
  final String displayName;

  /// Satırın ve detayın tek cümlelik açıklaması.
  final String description;

  /// Para çalışanın hesabına geçti mi — ekstreyle doğrulanmış tek durum.
  bool get isSettled => this == PayoutStatus.completed;

  static PayoutStatus fromCode(Object? value) {
    return PayoutStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => PayoutStatus.pending,
    );
  }
}

/// İş arayanın hak ettiği tutarın sağlayıcıya çıkış kaydı.
///
/// `GET /users/me/payouts` yanıtındaki `PayoutDto`. Hesap ve zaman alanları
/// (koala-backend#294) hepsi opsiyonel: eski sunucu göndermiyor, yeni sunucu
/// da hesap silinmişse ya da sağlayıcı referans dönmediyse `null` bırakıyor.
class Payout {
  const Payout({
    required this.id,
    required this.jobAssignmentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.jobTitle,
    this.companyName,
    this.maskedIban,
    this.bankAccountId,
    this.providerReference,
    this.releasedAt,
    this.settledAt,
    this.failureReason,
    this.completedAt,
  });

  final String id;
  final String jobAssignmentId;

  /// Backend'in ondalık değeri. İkili kayan noktaya çevrilmeden taşınır.
  final String amount;

  final String currency;
  final PayoutStatus status;

  /// Hakedişin ait olduğu ilanın başlığı; eski sunucuda `null`.
  final String? jobTitle;

  /// İlanı açan şirketin adı; bireysel ilanda ve eski sunucuda `null`.
  final String? companyName;

  /// Hakedişin gittiği hesabın maskeli IBAN'ı (`TR18***2315`): çıkış
  /// anındaki birincil hesap, sonradan değişmiyor. Tam IBAN hiçbir yanıtta
  /// gelmiyor. Hesap kaydı yoksa ya da sonradan silindiyse `null`.
  final String? maskedIban;

  /// Hakedişin gittiği banka hesabının kimliği; hesap yoksa `null`.
  final String? bankAccountId;

  /// Sağlayıcının (Iyzico) çıkış talimatını onaylarken verdiği işlem
  /// referansı; `PENDING`'de ya da referans dönmediyse `null`.
  final String? providerReference;

  /// Emanetten çıkışa alındığı an (`createdAt` ile aynı değer).
  final DateTime? releasedAt;

  /// Banka ekstresiyle doğrulanan gerçekleşme anı; yalnız `COMPLETED`'da
  /// dolu (`completedAt` ile aynı değer).
  final DateTime? settledAt;

  final String? failureReason;
  final DateTime? completedAt;
  final DateTime createdAt;

  /// Satırdaki kısa hesap etiketi: IBAN'ın son dört hanesi. Maske sunucudan
  /// geliyor; burada yalnız kuyruğu alınıyor.
  String? get ibanTail {
    final iban = maskedIban;
    if (iban == null || iban.isEmpty) return null;
    return iban.length <= 4 ? iban : iban.substring(iban.length - 4);
  }

  /// Çıkışa alınma anı: yeni alan, yoksa kayıt zamanı (aynı değer).
  DateTime get releasedAtOrCreated => releasedAt ?? createdAt;

  /// Mutabakat anı: yeni alan, yoksa `COMPLETED` kaydın `completedAt`'i.
  /// Tamamlanmamış çıkışta `null` — henüz doğrulanmış bir an yok.
  DateTime? get settledAtOrCompleted =>
      settledAt ?? (status.isSettled ? completedAt : null);

  factory Payout.fromJson(Map<String, dynamic> json) {
    return Payout(
      id: JsonField.requiredString(json['id'], 'id'),
      jobAssignmentId: JsonField.requiredString(
        json['jobAssignmentId'],
        'jobAssignmentId',
      ),
      amount: JsonField.rollingDecimalString(json['amount'], 'amount'),
      currency: JsonField.requiredString(json['currency'], 'currency'),
      status: PayoutStatus.fromCode(json['status']),
      jobTitle: _optionalString(json['jobTitle']),
      companyName: _optionalString(json['companyName']),
      maskedIban: _optionalString(json['maskedIban']),
      bankAccountId: _optionalString(json['bankAccountId']),
      providerReference: _optionalString(json['providerReference']),
      releasedAt: JsonField.dateOrNull(json['releasedAt']),
      settledAt: JsonField.dateOrNull(json['settledAt']),
      failureReason: json['failureReason'] as String?,
      completedAt: JsonField.dateOrNull(json['completedAt']),
      createdAt: JsonField.requiredDate(json['createdAt'], 'createdAt'),
    );
  }

  /// Boş dize de "yok" sayılıyor; ekranda `—` onun yerine geçiyor.
  static String? _optionalString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}

/// Atamanın içinde gelen hakediş özeti.
///
/// `MyAssignmentDto.payout` (koala-backend#282) yalnızca kimlik, durum ve
/// tamamlanma anını taşıyor; tutar ve para birimi [Payout]'ta,
/// `/users/me/payouts` ucunda. Zaman çizelgesinin "hakediş" satırı ve
/// ödeme durumu metni buna bakıyor.
class PayoutSummary {
  const PayoutSummary({
    required this.id,
    required this.status,
    this.completedAt,
  });

  final String id;
  final PayoutStatus status;
  final DateTime? completedAt;

  factory PayoutSummary.fromJson(Map<String, dynamic> json) {
    return PayoutSummary(
      id: '${json['id'] ?? ''}',
      status: PayoutStatus.fromCode(json['status']),
      completedAt: JsonField.dateOrNull(json['completedAt']),
    );
  }
}
