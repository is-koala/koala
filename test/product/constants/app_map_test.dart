import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_map.dart';

void main() {
  group('AppMap harita varsayılanları', () {
    test('varsayılan merkez İstanbul hizmet alanının içindedir', () {
      expect(AppMap.istanbulBounds.contains(AppMap.istanbulCenter), isTrue);
    });

    test('varsayılan merkez Ankara değildir', () {
      // Ankara Kızılay; hizmet alanı dışında kaldığı için harita orada
      // açılırsa hiçbir İstanbul ilanı ekranda görünmez.
      const ankara = LatLng(39.925533, 32.866287);
      expect(AppMap.istanbulBounds.contains(ankara), isFalse);
      expect(AppMap.istanbulCenter, isNot(ankara));
    });

    test('sınırlar İstanbul boylam/enlem aralığını kapsar', () {
      expect(AppMap.istanbulBounds.southwest.latitude, lessThan(41.0));
      expect(AppMap.istanbulBounds.northeast.latitude, greaterThan(41.0));
      expect(AppMap.istanbulBounds.southwest.longitude, lessThan(28.98));
      expect(AppMap.istanbulBounds.northeast.longitude, greaterThan(28.98));
    });
  });
}
