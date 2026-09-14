import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/pricing_breakdown.dart';

PricingBreakdown _breakdown(String rate) => PricingBreakdown(
  pricingVersion: 'v1',
  currency: 'TRY',
  workerPayout: '950.00',
  serviceFeeRate: rate,
  serviceFeeAmount: '50.00',
  employerTotal: '1000.00',
);

void main() {
  group('PricingBreakdown.serviceFeePercentLabel', () {
    // İki kabuk da bu etiketi yazıyor; biçim ikili kayan noktaya çevrilmeden,
    // dizenin ondalığını iki basamak kaydırarak kuruluyor.
    for (final (rate, label) in const [
      ('0.075', '7,5'),
      ('0.05', '5'),
      ('0.1', '10'),
      ('0', '0'),
      ('0.125', '12,5'),
      ('1', '100'),
      ('0.0075', '0,75'),
    ]) {
      test('$rate → %$label', () {
        expect(_breakdown(rate).serviceFeePercentLabel, label);
      });
    }

    test('tanınmayan biçim olduğu gibi, virgülle döner', () {
      expect(PricingBreakdown.percentLabel('abc'), 'abc');
      expect(PricingBreakdown.percentLabel('1e-2'), '1e-2');
    });
  });
}
