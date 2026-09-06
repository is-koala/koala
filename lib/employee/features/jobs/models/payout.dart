/// Çalışana yapılan ödeme çıkışının backend durumu.
enum PayoutStatus {
  pending('PENDING', 'Bekliyor'),
  processing('PROCESSING', 'İşleniyor'),
  completed('COMPLETED', 'Tamamlandı'),
  failed('FAILED', 'Başarısız');

  const PayoutStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  static PayoutStatus fromCode(Object? value) {
    return PayoutStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => PayoutStatus.pending,
    );
  }
}

/// İş arayanın hak ettiği tutarın sağlayıcıya çıkış kaydı.
class Payout {
  const Payout({
    required this.id,
    required this.jobAssignmentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.failureReason,
    this.completedAt,
  });

  final String id;
  final String jobAssignmentId;

  /// Backend'in ondalık değeri. İkili kayan noktaya çevrilmeden taşınır.
  final String amount;

  final String currency;
  final PayoutStatus status;
  final String? failureReason;
  final DateTime? completedAt;
  final DateTime createdAt;

  factory Payout.fromJson(Map<String, dynamic> json) {
    return Payout(
      id: _requiredString(json['id'], 'id'),
      jobAssignmentId: _requiredString(
        json['jobAssignmentId'],
        'jobAssignmentId',
      ),
      amount: _requiredString(json['amount'], 'amount'),
      currency: _requiredString(json['currency'], 'currency'),
      status: PayoutStatus.fromCode(json['status']),
      failureReason: json['failureReason'] as String?,
      completedAt: _dateOrNull(json['completedAt']),
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
    );
  }

  static String _requiredString(Object? value, String field) {
    if (value is String && value.isNotEmpty) return value;
    if (value is num) return value.toString();
    throw FormatException('$field alanı eksik.');
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime _requiredDate(Object? value, String field) {
    final parsed = _dateOrNull(value);
    if (parsed != null) return parsed;
    throw FormatException('$field alanı eksik.');
  }
}
