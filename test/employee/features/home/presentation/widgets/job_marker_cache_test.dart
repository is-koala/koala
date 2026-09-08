import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_cache.dart';

import '../../../../../support/fixtures.dart';

/// Kesinlik testleri için **koordinatı sabit** çift.
///
/// Fikstürlerin koordinatı bilerek aynı: bayraktan başka hiçbir şey
/// değişmiyor. Koordinatı da değiştiren bir çift, anahtardan kesinlik alanı
/// düşürülse bile iddiayı ayakta tutardı — iki durum yine farklı anahtar
/// alırdı, ama bunu kesinlik değil koordinat farkı sağlardı. Sızıntının
/// gerçekte ortaya çıktığı durum ise sunucunun aynı noktayı iki farklı
/// kesinlikle vermesi.
Job _sameSpot(AddressPrecision precision) => buildJob(
  id: 'job_ayni',
  latitude: roundedLatitude,
  longitude: roundedLongitude,
  addressPrecision: precision,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Önbellek yetki değişimini taşıyor', () {
    test('kesinlik değişince pin yeniden üretiliyor', () async {
      // Koordinat aynı, yalnız bayrak dönüyor. Kesinliği anahtarında
      // taşımayan bir önbellek eski **kesin** pini geri verirdi: uçtan
      // bağlanan pin "iş tam burada" demeye devam ederdi.
      final cache = JobMarkerCache();

      final before = await cache.markersFor(
        jobs: [_sameSpot(AddressPrecision.exact)],
        onMarkerTap: (_) {},
      );
      expect(before.single.anchor, const Offset(0.5, 1.0));

      final after = await cache.markersFor(
        jobs: [_sameSpot(AddressPrecision.approximate)],
        onMarkerTap: (_) {},
      );

      expect(after, hasLength(1));
      expect(after.single.anchor, const Offset(0.5, 0.5));
    });

    test('terminal durumda önbellekteki kesin pin düşüyor', () async {
      // Çalışan atanmışken kesin pini görmüştü; iş bitince aynı ilan
      // `APPROXIMATE` ve yuvarlanmış koordinatla geri geliyor.
      final cache = JobMarkerCache();

      await cache.markersFor(jobs: [exactView()], onMarkerTap: (_) {});
      final after = await cache.markersFor(
        jobs: [maskedView()],
        onMarkerTap: (_) {},
      );

      expect(cache.length, 1);
      expect(after, hasLength(1));
      expect(
        after.single.position,
        const LatLng(roundedLatitude, roundedLongitude),
      );
    });

    test('kesinliği değişmeyen ilanın pini korunuyor', () async {
      final cache = JobMarkerCache();

      final first = await cache.markersFor(
        jobs: [maskedView()],
        onMarkerTap: (_) {},
      );
      final second = await cache.markersFor(
        jobs: [maskedView()],
        onMarkerTap: (_) {},
      );

      expect(cache.length, 1);
      expect(second.single.position, first.single.position);
    });

    test('görünen alandan çıkan ilan önbellekten düşüyor', () async {
      final cache = JobMarkerCache();

      await cache.markersFor(jobs: [maskedView()], onMarkerTap: (_) {});
      final after = await cache.markersFor(jobs: [], onMarkerTap: (_) {});

      expect(after, isEmpty);
      expect(cache.length, 0);
    });

    test('koordinatsız ilan önbelleğe girmiyor', () async {
      final cache = JobMarkerCache();

      final markers = await cache.markersFor(
        jobs: [buildJob(latitude: null, longitude: null)],
        onMarkerTap: (_) {},
      );

      expect(markers, isEmpty);
      expect(cache.length, 0);
    });

    test('pine dokunulunca ilanın kendisi geri veriliyor', () async {
      final cache = JobMarkerCache();
      Job? tapped;

      final markers = await cache.markersFor(
        jobs: [maskedView()],
        onMarkerTap: (job) => tapped = job,
      );
      markers.single.onTap!();

      expect(tapped?.id, 'job_ayni');
    });
  });
}
