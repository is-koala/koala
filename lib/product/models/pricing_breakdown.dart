import 'package:koala/product/network/json_field.dart';

/// Backend'in hesapladığı fiyat dökümü.
///
/// İlan formunda güncel quote yanıtını, atamada ise yayımlanırken sabitlenen
/// snapshot'ı taşır. Bütün ondalıklar dize olarak kalır; istemci hizmet
/// bedelini veya işveren toplamını yeniden hesaplamaz.
class PricingBreakdown {
  const PricingBreakdown({
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

  factory PricingBreakdown.fromJson(Map<String, dynamic> json) {
    return PricingBreakdown(
      pricingVersion: JsonField.requiredString(
        json['pricingVersion'],
        'pricingVersion',
      ),
      currency: JsonField.requiredString(json['currency'], 'currency'),
      workerPayout: JsonField.requiredDecimalString(
        json['workerPayout'],
        'workerPayout',
      ),
      serviceFeeRate: JsonField.requiredDecimalString(
        json['serviceFeeRate'],
        'serviceFeeRate',
      ),
      serviceFeeAmount: JsonField.requiredDecimalString(
        json['serviceFeeAmount'],
        'serviceFeeAmount',
      ),
      employerTotal: JsonField.requiredDecimalString(
        json['employerTotal'],
        'employerTotal',
      ),
    );
  }
}
