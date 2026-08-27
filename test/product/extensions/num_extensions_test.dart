import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/extensions/num_extensions.dart';

void main() {
  group('asPrice', () {
    test('binlik ayracı koyar', () {
      expect(1500.asPrice, '1.500');
      expect(15000.asPrice, '15.000');
      expect(150000.asPrice, '150.000');
      expect(1500000.asPrice, '1.500.000');
    });

    test('dört basamağın altına ayraç koymaz', () {
      expect(0.asPrice, '0');
      expect(5.asPrice, '5');
      expect(99.asPrice, '99');
      expect(999.asPrice, '999');
    });

    test('kuruşu yuvarlayıp atar', () {
      expect(1500.4.asPrice, '1.500');
      expect(1500.5.asPrice, '1.501');
      expect(800.99.asPrice, '801');
    });

    test('double ve int aynı sonucu verir', () {
      expect(2000.asPrice, 2000.0.asPrice);
    });

    // Ücretler negatif olmamalı ama biçimlendirici yine de doğru davranıyor;
    // eksi işareti ayracı bozmuyor.
    test('negatif değeri de doğru ayırır', () {
      expect((-1500).asPrice, '-1.500');
      expect((-15000).asPrice, '-15.000');
    });
  });
}
