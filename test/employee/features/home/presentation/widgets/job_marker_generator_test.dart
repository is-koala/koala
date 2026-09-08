import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';

import '../../../../../support/fixtures.dart';

/// İşverenin gördüğü koordinat: sunucu `EXACT` yanıtta kesin değeri yazıyor,
/// yuvarlama yok. Fikstürlerin **tam hassasiyetli** olması şart — yuvarlanmış
/// bir koordinatla kurulan `EXACT` durumu, yalnız o dalda sızdıran bir hatayı
/// göremezdi.
const double _exactLatitude = 41.015137;
const double _exactLongitude = 28.979530;

/// Yetkisiz görüntüleyenin gördüğü koordinat: sunucu iki ondalığa yuvarlıyor.
const double _roundedLatitude = 41.02;
const double _roundedLongitude = 28.98;

Job _employerView() => buildJob(
  id: 'job_ayni',
  latitude: _exactLatitude,
  longitude: _exactLongitude,
  addressPrecision: AddressPrecision.exact,
);

Job _assignedWorkerView() => buildJob(
  id: 'job_ayni',
  latitude: _exactLatitude,
  longitude: _exactLongitude,
  addressPrecision: AddressPrecision.exact,
);

Job _otherUserView() => buildJob(
  id: 'job_ayni',
  latitude: _roundedLatitude,
  longitude: _roundedLongitude,
  addressPrecision: AddressPrecision.approximate,
);

Job _anonymousView() => buildJob(
  id: 'job_ayni',
  latitude: _roundedLatitude,
  longitude: _roundedLongitude,
  addressPrecision: AddressPrecision.approximate,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Belirsizlik dairesi dört aktör için', () {
    test('işverene daire çizilmiyor', () {
      expect(
        JobMarkerGenerator.generateAreas(jobs: [_employerView()]),
        isEmpty,
      );
    });

    test('atanmış çalışana daire çizilmiyor', () {
      expect(
        JobMarkerGenerator.generateAreas(jobs: [_assignedWorkerView()]),
        isEmpty,
      );
    });

    test('diğer kullanıcıya daire çiziliyor', () {
      final areas = JobMarkerGenerator.generateAreas(jobs: [_otherUserView()]);

      expect(areas, hasLength(1));
      expect(
        areas.single.center,
        const LatLng(_roundedLatitude, _roundedLongitude),
      );
      expect(areas.single.radius, greaterThan(0));
    });

    test('anonim ziyaretçiye daire çiziliyor', () {
      final areas = JobMarkerGenerator.generateAreas(jobs: [_anonymousView()]);

      expect(areas, hasLength(1));
      expect(
        areas.single.center,
        const LatLng(_roundedLatitude, _roundedLongitude),
      );
    });

    test('koordinatsız ilana daire de pin de çizilmiyor', () {
      final job = buildJob(latitude: null, longitude: null);

      expect(JobMarkerGenerator.generateAreas(jobs: [job]), isEmpty);
    });

    test('daire yarıçapı yuvarlama hatasını kapsıyor', () {
      // Sunucu ±0.005° yuvarlıyor; en kötü sapma enlem ve boylam hatalarının
      // köşegeni. Daire bundan küçük olsaydı gerçek konumu dışarıda bırakır,
      // yani yine kesin bir alan iddia ederdi.
      final areas = JobMarkerGenerator.generateAreas(jobs: [_otherUserView()]);

      const worstCaseLatitudeErrorInMeters = 0.005 * 111320;
      expect(
        areas.single.radius,
        greaterThanOrEqualTo(worstCaseLatitudeErrorInMeters),
      );
    });
  });

  group('Pin bağlanma noktası', () {
    test('kesin konumda pin ucundan bağlanıyor', () {
      expect(
        JobMarkerGenerator.anchorFor(AddressPrecision.exact),
        const Offset(0.5, 1.0),
      );
    });

    test('yaklaşık konumda pin ortasından bağlanıyor', () {
      expect(
        JobMarkerGenerator.anchorFor(AddressPrecision.approximate),
        const Offset(0.5, 0.5),
      );
    });

    test('üretilen marker bağlanma noktasını kesinliğe göre alıyor', () async {
      final markers = await JobMarkerGenerator.generateMarkers(
        jobs: [_employerView(), _otherUserView()],
        onMarkerTap: (_) {},
      );

      final exact = markers[JobMarkerGenerator.cacheKeyFor(_employerView())]!;
      final approximate =
          markers[JobMarkerGenerator.cacheKeyFor(_otherUserView())]!;

      expect(exact.anchor, const Offset(0.5, 1.0));
      expect(approximate.anchor, const Offset(0.5, 0.5));
    });

    test(
      'marker sunucunun gönderdiği koordinatı olduğu gibi kullanıyor',
      () async {
        // İstemcide yuvarlama yok: yaklaşıklığı sunucu üretiyor
        // (`docs/research/location-and-map.md`), istemci yalnız gösteriyor.
        final markers = await JobMarkerGenerator.generateMarkers(
          jobs: [_employerView()],
          onMarkerTap: (_) {},
        );

        expect(
          markers.values.single.position,
          const LatLng(_exactLatitude, _exactLongitude),
        );
      },
    );
  });

  group('Önbellek anahtarı yetki değişimini taşıyor', () {
    test('aynı ilan kesinliği değişince farklı anahtar alıyor', () {
      expect(
        JobMarkerGenerator.cacheKeyFor(_assignedWorkerView()),
        isNot(JobMarkerGenerator.cacheKeyFor(_otherUserView())),
      );
    });

    test('terminal durumda önbellekteki kesin pin düşüyor', () {
      // Çalışan atanmışken kesin pini görmüştü; iş bitince aynı ilan
      // `APPROXIMATE` ve yuvarlanmış koordinatla geri geliyor.
      final assigned = _assignedWorkerView();
      final afterCompletion = _otherUserView();

      final cache = {
        JobMarkerGenerator.cacheKeyFor(assigned): Marker(
          markerId: MarkerId(assigned.id),
          position: LatLng(assigned.latitude!, assigned.longitude!),
        ),
      };

      JobMarkerGenerator.evictStale(cache, [afterCompletion]);

      expect(cache, isEmpty);
    });

    test('kesinliği değişmeyen ilan önbellekte kalıyor', () {
      final job = _otherUserView();
      final cache = {
        JobMarkerGenerator.cacheKeyFor(job): Marker(markerId: MarkerId(job.id)),
      };

      JobMarkerGenerator.evictStale(cache, [job]);

      expect(cache, hasLength(1));
    });

    test('görünen alandan çıkan ilan önbellekten düşüyor', () {
      final job = _otherUserView();
      final cache = {
        JobMarkerGenerator.cacheKeyFor(job): Marker(markerId: MarkerId(job.id)),
      };

      JobMarkerGenerator.evictStale(cache, []);

      expect(cache, isEmpty);
    });
  });
}
