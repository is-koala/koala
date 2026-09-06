import 'package:koala/business/features/home/models/b_pricing_breakdown.dart';

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
      id: _requiredString(json['id'], 'id'),
      status: BPaymentAttemptStatus.fromCode(json['status']),
      currency: _requiredString(json['currency'], 'currency'),
      workerPayout: _requiredString(json['workerPayout'], 'workerPayout'),
      commissionAmount: _requiredString(
        json['commissionAmount'],
        'commissionAmount',
      ),
      commissionRate: _requiredString(json['commissionRate'], 'commissionRate'),
      totalCharged: _requiredString(json['totalCharged'], 'totalCharged'),
      pricing: pricing is Map<String, dynamic>
          ? BPricingBreakdown.fromJson(pricing)
          : null,
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
