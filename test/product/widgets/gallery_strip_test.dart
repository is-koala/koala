import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/gallery_strip.dart';

import '../../support/pump.dart';

const _images = [
  GalleryImage(
    id: 'img_1',
    url: 'https://cdn.local/1.png',
    isCover: true,
    caption: 'Salon',
  ),
  GalleryImage(id: 'img_2', url: 'https://cdn.local/2.png', sortOrder: 1),
];

void main() {
  group('GalleryStrip', () {
    testWidgets('sunucu sırasını çizer ve tam ekran açar', (tester) async {
      await pumpInApp(tester, const GalleryStrip(images: _images));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text('Salon'), findsOneWidget);

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();

      expect(find.byType(GalleryViewer), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('bozuk görselde yer tutucu gösteriyor', (tester) async {
      await pumpInApp(
        tester,
        const GalleryStrip(
          images: [GalleryImage(id: 'broken', url: 'not-a-url')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppIcon), findsOneWidget);
    });

    testWidgets('koyu temada çiziliyor', (tester) async {
      await pumpInApp(
        tester,
        const GalleryStrip(images: _images),
        brightness: Brightness.dark,
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(2));
    });
  });
}
