import 'package:koala/business/features/home/models/b_pricing_breakdown.dart';
import 'package:koala/product/network/json_field.dart';

/// Tek bir ödeme denemesinin backend durumu.
enum BPaymentAttemptStatus {
  initiated('INITIATED', 'Başlatıldı'),
  inReview('IN_REVIEW', 'İnceleniyor'),
  succeeded('SUCCEEDED', 'Başarılı'),
  failed('FAILED', 'Başarısız');

  const BPaymentAttemptStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  static BPaymentAttemptStatus fromCode(Object? value) {
    return BPaymentAttemptStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => BPaymentAttemptStatus.initiated,
    );
  }
}

/// İşverenin atama için başlattığı tek ödeme girişimi.
class BPaymentAttempt {
  const BPaymentAttempt({
    required this.id,
    required this.status,
    required this.currency,
    required this.workerPayout,
    required this.commissionAmount,
    required this.commissionRate,
    required this.totalCharged,
    required this.createdAt,
    this.pricing,
    this.failureReason,
    this.completedAt,
  });

  final String id;
  final BPaymentAttemptStatus status;
  final String currency;

  /// Backend ondalıkları; hesap yapılmadan dize olarak korunur.
  final String workerPayout;
  final String commissionAmount;
  final String commissionRate;
  final String totalCharged;

  final BPricingBreakdown? pricing;
  final String? failureReason;
  final DateTime? completedAt;
  final DateTime createdAt;

  factory BPaymentAttempt.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'];
    return BPaymentAttempt(
      id: JsonField.requiredString(json['id'], 'id'),
      status: BPaymentAttemptStatus.fromCode(json['status']),
      currency: JsonField.requiredString(json['currency'], 'currency'),
      workerPayout: JsonField.requiredString(
        json['workerPayout'],
        'workerPayout',
      ),
      commissionAmount: JsonField.requiredString(
        json['commissionAmount'],
        'commissionAmount',
      ),
      commissionRate: JsonField.requiredString(
        json['commissionRate'],
        'commissionRate',
      ),
      totalCharged: JsonField.requiredString(
        json['totalCharged'],
        'totalCharged',
      ),
      pricing: switch (pricing) {
        null => null,
        final Map<String, dynamic> value => BPricingBreakdown.fromJson(value),
        _ => throw const FormatException('pricing alanı geçersiz.'),
      },
      failureReason: json['failureReason'] as String?,
      completedAt: JsonField.dateOrNull(json['completedAt']),
      createdAt: JsonField.requiredDate(json['createdAt'], 'createdAt'),
    );
  }
}
