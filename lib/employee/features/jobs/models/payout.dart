import 'package:koala/product/network/json_field.dart';

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
      id: JsonField.requiredString(json['id'], 'id'),
      jobAssignmentId: JsonField.requiredString(
        json['jobAssignmentId'],
        'jobAssignmentId',
      ),
      amount: JsonField.rollingDecimalString(json['amount'], 'amount'),
      currency: JsonField.requiredString(json['currency'], 'currency'),
      status: PayoutStatus.fromCode(json['status']),
      failureReason: json['failureReason'] as String?,
      completedAt: JsonField.dateOrNull(json['completedAt']),
      createdAt: JsonField.requiredDate(json['createdAt'], 'createdAt'),
    );
  }
}
