import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';

void main() {
  group('TurkishMoneyFormatter.format', () {
    test('TRY tutarını Türkçe binlik ve ondalık ayraçlarla gösterir', () {
      expect(TurkishMoneyFormatter.format('1050.11', 'TRY'), '1.050,11 ₺');
    });

    test('büyük tutarlarda her binlik grubu ayırır', () {
      expect(
        TurkishMoneyFormatter.format(
          '123456789012345678901234567890.00',
          'TRY',
        ),
        '123.456.789.012.345.678.901.234.567.890,00 ₺',
      );
    });

    test('backend ondalık basamaklarını ve sondaki sıfırları korur', () {
      expect(TurkishMoneyFormatter.format('0.0500', 'TRY'), '0,0500 ₺');
      expect(TurkishMoneyFormatter.format('10', 'TRY'), '10 ₺');
    });

    test('negatif işareti tutarın başında korur', () {
      expect(TurkishMoneyFormatter.format('-1234.50', 'TRY'), '-1.234,50 ₺');
    });

    test('TRY dışındaki para birimlerinde kanonik kodu gösterir', () {
      expect(TurkishMoneyFormatter.format('1050.11', 'EUR'), '1.050,11 EUR');
    });

    test('ondalık dize sözleşmesine uymayan girdileri reddeder', () {
      for (final amount in ['', 'NaN', '1,25', '1.', '.25', '1e3']) {
        expect(
          () => TurkishMoneyFormatter.format(amount, 'TRY'),
          throwsFormatException,
          reason: amount,
        );
      }
    });
  });
}
