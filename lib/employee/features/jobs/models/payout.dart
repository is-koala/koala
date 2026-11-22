import 'package:koala/product/network/json_field.dart';

/// Ödeme çıkışının durumu. "Hesabınıza geçti" **yalnız** `COMPLETED`'da (banka
/// ekstresiyle doğrulanmış); öncesinde para yolda.
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

  final String displayName;

  final String description;

  /// Ekstreyle doğrulanmış tek durum.
  bool get isSettled => this == PayoutStatus.completed;

  static PayoutStatus fromCode(Object? value) {
    return PayoutStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => PayoutStatus.pending,
    );
  }
}

/// Hakedişin çıkış kaydı (`PayoutDto`). Hesap ve zaman alanları opsiyonel: eski
/// sunucu göndermiyor, hesap silinmişse de `null`.
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
    this.providerReference,
    this.releasedAt,
    this.settledAt,
    this.failureReason,
    this.completedAt,
  });

  final String id;
  final String jobAssignmentId;

  /// İkili kayan noktaya çevrilmeden taşınır.
  final String amount;

  final String currency;
  final PayoutStatus status;

  final String? jobTitle;

  final String? companyName;

  /// Çıkış anındaki birincil hesap; tam IBAN hiçbir yanıtta gelmez.
  final String? maskedIban;

  /// `PENDING`'de ya da referans dönmediyse `null`.
  final String? providerReference;

  final DateTime? releasedAt;

  /// Yalnız `COMPLETED`'da dolu.
  final DateTime? settledAt;

  final String? failureReason;
  final DateTime? completedAt;
  final DateTime createdAt;

  /// Son dört hane; maske sunucudan.
  String? get ibanTail {
    final iban = maskedIban;
    if (iban == null || iban.isEmpty) return null;
    return iban.length <= 4 ? iban : iban.substring(iban.length - 4);
  }

  DateTime get releasedAtOrCreated => releasedAt ?? createdAt;

  /// Tamamlanmamışta `null`.
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
      providerReference: _optionalString(json['providerReference']),
      releasedAt: JsonField.dateOrNull(json['releasedAt']),
      settledAt: JsonField.dateOrNull(json['settledAt']),
      failureReason: json['failureReason'] as String?,
      completedAt: JsonField.dateOrNull(json['completedAt']),
      createdAt: JsonField.requiredDate(json['createdAt'], 'createdAt'),
    );
  }

  /// Boş dize "yok"; ekranda `—`.
  static String? _optionalString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}

/// Atamadaki hakediş özeti: kimlik, durum, tamamlanma. Tutar [Payout]'ta.
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
