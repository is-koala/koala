import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/company_detail/models/company_image.dart';
import 'package:koala/employee/features/company_detail/presentation/widgets/company_gallery_strip.dart';

import '../../../../../support/pump.dart';

const _images = [
  CompanyImage(
    id: 'img_1',
    url: 'https://cdn.local/1.png',
    isCover: true,
    caption: 'Salon',
  ),
  CompanyImage(id: 'img_2', url: 'https://cdn.local/2.png', sortOrder: 1),
];

void main() {
  group('CompanyGalleryStrip', () {
    testWidgets('sunucudan gelen sırayla çiziyor', (tester) async {
      await pumpInApp(tester, const CompanyGalleryStrip(images: _images));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(2));
      // Başlığı olan görselin başlığı şeridin üstünde duruyor.
      expect(find.text('Salon'), findsOneWidget);
    });

    testWidgets('görsele dokununca tam ekran açılıyor', (tester) async {
      await pumpInApp(tester, const CompanyGalleryStrip(images: _images));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();

      expect(find.byType(CompanyGalleryViewer), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('koyu temada da çiziliyor', (tester) async {
      await pumpInApp(
        tester,
        const CompanyGalleryStrip(images: _images),
        brightness: Brightness.dark,
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(2));
    });
  });
}
