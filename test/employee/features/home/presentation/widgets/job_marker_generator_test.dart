import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_cluster.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:reicon_flutter/reicon_flutter.dart';

import '../../../../../support/fixtures.dart';

/// Uygulamanın artwork'ü olmayan bir kategori kodu.
const _unknownCategory = JobCategory(
  id: 'seed-bilinmeyen',
  name: 'Bilinmeyen',
  code: 'UNKNOWN_CODE',
);

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pin görseli', () {
    final categories = [...JobCategorySeeds.all, _unknownCategory];

    for (final category in categories) {
      test('${category.code} pini kendi rengini ve Filled ikonunu taşır', () {
        final iconPaths = Reicon.filled[category.icon];
        expect(
          iconPaths,
          isNotNull,
          reason: '${category.icon} ikonunun Filled karşılığı yok',
        );

        final svg = JobMarkerGenerator.pinSvg(category);
        expect(svg, contains('fill="${_hex(category.color)}"'));
        expect(svg, contains(iconPaths!.replaceAll('currentColor', '#ffffff')));
        // İkon beyaza boyanmış olmalı; çözülmemiş renk siyah çizilir.
        expect(svg, isNot(contains('currentColor')));
      });
    }

    test('bütün pinler aynı şekil ve kenarla çizilir', () {
      final shapes = {
        for (final category in categories)
          JobMarkerGenerator.pinSvg(
            category,
          ).split('<g ').first.replaceAll(_hex(category.color), ''),
      };
      expect(shapes, hasLength(1));
    });

    test('tanınmayan kategori nötr ikon ve marka rengiyle çizilir', () {
      final svg = JobMarkerGenerator.pinSvg(_unknownCategory);
      expect(_unknownCategory.icon, AppIcons.briefcase);
      expect(svg, contains('fill="${_hex(AppColors.primaryColor)}"'));
    });

    testWidgets('her kategori için pin görüntüsü üretilir', (tester) async {
      JobMarkerGenerator.clearCache();
      for (final category in categories) {
        final marker = await tester.runAsync(
          () => JobMarkerGenerator.markerFor(
            buildJob(id: category.code, category: category),
            (_) {},
          ),
        );
        expect(marker, isNotNull, reason: category.code);
        expect(marker!.icon, isA<BytesMapBitmap>(), reason: category.code);
      }
    });

    testWidgets('pin ekran yoğunluğunda çizilir, harita 1x saymaz', (
      tester,
    ) async {
      JobMarkerGenerator.clearCache();
      final marker = await tester.runAsync(
        () => JobMarkerGenerator.markerFor(buildJob(), (_) {}),
      );
      final icon = marker!.icon as BytesMapBitmap;
      final ratio = tester.view.devicePixelRatio;
      expect(icon.imagePixelRatio, ratio);

      // Görüntünün piksel yüksekliği mantıksal yükseklik × yoğunluk olmalı;
      // oran ile çözünürlük birlikte değişmezse pin ya bulanık ya da dev olur.
      final image = await tester.runAsync(
        () => decodeImageFromList(icon.byteData),
      );
      expect(image!.height, (70 * ratio).round());
    });
  });

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

  group('Grup pini', () {
    test('rozet sayıyı yazar, 99 üstünü kısaltır', () {
      expect(JobMarkerGenerator.clusterLabel(2), '2');
      expect(JobMarkerGenerator.clusterLabel(99), '99');
      expect(JobMarkerGenerator.clusterLabel(100), '99+');
    });

    testWidgets('grup pini ortasından bağlanır, tek pinlerin üstünde durur', (
      tester,
    ) async {
      JobMarkerGenerator.clearCache();
      final cluster = JobClusterer.cluster([
        buildJob(id: 'a', latitude: 41.0, longitude: 29.0),
        buildJob(id: 'b', latitude: 41.0, longitude: 29.0),
      ], zoom: 15).single;
      JobCluster? tapped;

      final marker = await tester.runAsync(
        () => JobMarkerGenerator.clusterMarkerFor(cluster, (c) => tapped = c),
      );

      expect(marker!.markerId.value, 'cluster:a,b');
      expect(marker.anchor, const Offset(0.5, 0.5));
      expect(marker.zIndexInt, greaterThan(0));
      expect(marker.icon, isA<BytesMapBitmap>());
      expect(
        (marker.icon as BytesMapBitmap).imagePixelRatio,
        tester.view.devicePixelRatio,
      );

      marker.onTap!();
      expect(tapped, same(cluster));
    });
  });
}
