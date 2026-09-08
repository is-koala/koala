import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';

import '../../../../../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Belirsizlik dairesi', () {
    test('kesin konumda daire çizilmiyor', () {
      expect(JobMarkerGenerator.generateAreas(jobs: [exactView()]), isEmpty);
    });

    test('yaklaşık konumda daire çiziliyor', () {
      final areas = JobMarkerGenerator.generateAreas(jobs: [maskedView()]);

      expect(areas, hasLength(1));
      expect(
        areas.single.center,
        const LatLng(roundedLatitude, roundedLongitude),
      );
    });

    test('koordinatsız ilana daire de pin de çizilmiyor', () {
      final job = buildJob(latitude: null, longitude: null);

      expect(JobMarkerGenerator.generateAreas(jobs: [job]), isEmpty);
    });

    test('daire yarıçapı iki eksenin hatasını birden kapsıyor', () {
      // Sunucu her eksende ±0.005° yuvarlıyor; en kötü sapma enlem ve boylam
      // hatalarının köşegeni. Yalnız enlem bacağını ölçmek yetmez: boylam
      // terimini sıfırlayan bir hata tam olarak o bacağı üretir ve iddianın
      // altından geçerdi. Köşegen bacaktan **büyük**, iki bacak da eşit
      // olsaydı ulaşacağı tavandan (bacak × √2, ekvatorda) küçük olmalı.
      final areas = JobMarkerGenerator.generateAreas(jobs: [maskedView()]);

      const latitudeLegInMeters = 0.005 * 111320;
      expect(areas.single.radius, greaterThan(latitudeLegInMeters));
      expect(areas.single.radius, lessThan(latitudeLegInMeters * sqrt2));
    });

    test('daire ilanın kendi belirsizliğini taşıyor', () {
      final job = maskedView();

      expect(
        JobMarkerGenerator.generateAreas(jobs: [job]).single.radius,
        job.approximateRadiusInMeters,
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
      final exact = await JobMarkerGenerator.markerFor(exactView(), (_) {});
      final approximate = await JobMarkerGenerator.markerFor(
        maskedView(),
        (_) {},
      );

      expect(exact.anchor, const Offset(0.5, 1.0));
      expect(approximate.anchor, const Offset(0.5, 0.5));
    });

    test(
      'marker sunucunun gönderdiği koordinatı olduğu gibi kullanıyor',
      () async {
        // İstemcide yuvarlama yok: yaklaşıklığı sunucu üretiyor
        // (`docs/research/location-and-map.md`), istemci yalnız gösteriyor.
        final marker = await JobMarkerGenerator.markerFor(exactView(), (_) {});

        expect(marker.position, const LatLng(exactLatitude, exactLongitude));
      },
    );
  });
}
