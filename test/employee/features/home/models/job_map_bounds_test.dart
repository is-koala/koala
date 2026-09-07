import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';

const _ankara = JobMapBounds(
  minLatitude: 39.8,
  maxLatitude: 40.0,
  minLongitude: 32.7,
  maxLongitude: 32.9,
);

void main() {
  group('JobMapBounds.contains', () {
    test('içindeki kutuyu kapsıyor', () {
      const inner = JobMapBounds(
        minLatitude: 39.85,
        maxLatitude: 39.95,
        minLongitude: 32.75,
        maxLongitude: 32.85,
      );

      expect(_ankara.contains(inner), isTrue);
    });

    test('kendini kapsıyor', () {
      expect(_ankara.contains(_ankara), isTrue);
    });

    test('taşan kutuyu kapsamıyor', () {
      const wider = JobMapBounds(
        minLatitude: 39.8,
        maxLatitude: 40.0,
        minLongitude: 32.6,
        maxLongitude: 32.9,
      );

      expect(_ankara.contains(wider), isFalse);
    });

    test('bambaşka bir kutuyu kapsamıyor', () {
      const istanbul = JobMapBounds(
        minLatitude: 40.9,
        maxLatitude: 41.1,
        minLongitude: 28.9,
        maxLongitude: 29.1,
      );

      expect(_ankara.contains(istanbul), isFalse);
    });

    test('180. meridyeni aşan kutu kapsıyor sayılmıyor', () {
      // Kutu sarınca `min > max` oluyor ve düz karşılaştırma yanlış sonuç
      // veriyor; bu durumda istek atlanmıyor, atılıyor.
      const wrapping = JobMapBounds(
        minLatitude: 39.8,
        maxLatitude: 40.0,
        minLongitude: 179.0,
        maxLongitude: -179.0,
      );

      expect(wrapping.contains(wrapping), isFalse);
      expect(_ankara.contains(wrapping), isFalse);
    });
  });

  group('JobMapBounds sorguya uygulanması', () {
    test('dört alanı da sorguya yazıyor', () {
      final query = _ankara.applyTo(const JobSearchQuery());

      expect(query.toQueryParameters(), {
        'minLatitude': 39.8,
        'maxLatitude': 40.0,
        'minLongitude': 32.7,
        'maxLongitude': 32.9,
      });
    });

    test('sorgunun geri kalanını bozmuyor', () {
      final query = _ankara.applyTo(const JobSearchQuery(query: 'garson'));

      expect(query.query, 'garson');
    });
  });

  group('JobMapBounds eşitliği', () {
    test('aynı köşeler eşit', () {
      expect(
        _ankara,
        const JobMapBounds(
          minLatitude: 39.8,
          maxLatitude: 40.0,
          minLongitude: 32.7,
          maxLongitude: 32.9,
        ),
      );
    });
  });
}
