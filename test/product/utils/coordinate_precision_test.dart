import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/utils/coordinate_precision.dart';

void main() {
  group('CoordinatePrecision.round6', () {
    test('ham harita koordinatını altı ondalığa yuvarlar', () {
      expect(CoordinatePrecision.round6(41.01234567891), 41.012346);
      expect(CoordinatePrecision.round6(28.97654321098), 28.976543);
    });

    test('negatif değeri de altı ondalığa yuvarlar', () {
      expect(CoordinatePrecision.round6(-28.97654321098), -28.976543);
      expect(CoordinatePrecision.round6(-41.01234567891), -41.012346);
    });

    test('sıfıra yuvarlanan negatif -0.0 değil 0.0 döner', () {
      final rounded = CoordinatePrecision.round6(-0.0000004);

      expect(rounded, 0.0);
      expect(rounded.isNegative, isFalse);
      expect(CoordinatePrecision.round6(-0.0).isNegative, isFalse);
    });

    test('zaten altı ondalıklı değer aynen kalır', () {
      expect(CoordinatePrecision.round6(40.982512), 40.982512);
      expect(CoordinatePrecision.round6(29.025411), 29.025411);
      expect(CoordinatePrecision.round6(41.0), 41.0);
    });

    test('yedinci ondalığa göre aşağı ya da yukarı yuvarlar', () {
      expect(CoordinatePrecision.round6(40.9825126), 40.982513);
      expect(CoordinatePrecision.round6(40.9825124), 40.982512);
    });
  });
}
