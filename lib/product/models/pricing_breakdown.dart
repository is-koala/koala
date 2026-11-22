import 'package:koala/product/network/json_field.dart';

/// Backend'in hesapladığı fiyat dökümü (formda güncel teklif, atamada
/// sabitlenmiş snapshot). Ondalıklar dize; istemci yeniden hesaplamaz.
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

  /// `0.075` → `7,5`.
  String get serviceFeePercentLabel => percentLabel(serviceFeeRate);

  /// Oranı yalnız etiket için iki basamak kaydırır; hesap yapmaz.
  static String percentLabel(String rate) {
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(rate);
    if (match == null) return rate.replaceAll('.', ',');

    final sign = match.group(1) ?? '';
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    var digits = '$whole$fraction';
    var decimalPosition = whole.length + 2;

    if (decimalPosition >= digits.length) {
      digits = digits.padRight(decimalPosition, '0');
    } else if (decimalPosition <= 0) {
      digits = digits.padLeft(digits.length - decimalPosition, '0');
      decimalPosition = 1;
    }

    var percentWhole = digits.substring(0, decimalPosition);
    var percentFraction = digits.substring(decimalPosition);
    percentWhole = percentWhole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    percentFraction = percentFraction.replaceFirst(RegExp(r'0+$'), '');

    return percentFraction.isEmpty
        ? '$sign$percentWhole'
        : '$sign$percentWhole,$percentFraction';
  }
}
