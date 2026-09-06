/// Backend'in hesaplayıp döndürdüğü fiyat dökümü.
///
/// Bütün ondalıklar dize olarak kalır. Mobil yalnızca gösterir; hizmet bedeli
/// veya işveren toplamını yeniden hesaplamaz.
class BPricingBreakdown {
  const BPricingBreakdown({
    required this.pricingVersion,
    required this.currency,
    required this.workerPayout,
    required this.serviceFeeRate,
    required this.serviceFeeAmount,
    required this.employerTotal,
  });

  final String pricingVersion;
  final String currency;
  final String workerPayout;
  final String serviceFeeRate;
  final String serviceFeeAmount;
  final String employerTotal;

  factory BPricingBreakdown.fromJson(Map<String, dynamic> json) {
    return BPricingBreakdown(
      pricingVersion: _requiredString(json['pricingVersion'], 'pricingVersion'),
      currency: _requiredString(json['currency'], 'currency'),
      workerPayout: _requiredString(json['workerPayout'], 'workerPayout'),
      serviceFeeRate: _requiredString(json['serviceFeeRate'], 'serviceFeeRate'),
      serviceFeeAmount: _requiredString(
        json['serviceFeeAmount'],
        'serviceFeeAmount',
      ),
      employerTotal: _requiredString(json['employerTotal'], 'employerTotal'),
    );
  }

  static String _requiredString(Object? value, String field) {
    if (value is String && value.isNotEmpty) return value;
    if (value is num) return value.toString();
    throw FormatException('$field alanı eksik.');
  }
}
