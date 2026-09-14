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

  /// Hizmet bedeli oranının yüzde etiketi: `0.075` → `7,5`.
  ///
  /// İki kabuk da aynı etiketi yazıyor (işverenin fiyat dökümü kartı ve
  /// çalışanın iş detayı); biçim tek yerde dursun diye burada.
  String get serviceFeePercentLabel => percentLabel(serviceFeeRate);

  /// Backend'in oran dizesini yalnızca yüzde etiketi için ondalık noktası iki
  /// basamak sağa kaydırarak biçimler. Ücret veya hizmet bedeli hesaplamaz.
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
