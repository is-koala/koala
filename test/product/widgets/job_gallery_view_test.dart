import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/widgets/gallery_strip.dart';
import 'package:koala/product/widgets/job_gallery_view.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('boş galeri yüzeyde hiç yer kaplamıyor', (tester) async {
    await pumpInApp(tester, const JobGalleryView(images: [], isLoading: false));

    expect(find.text('Galeri'), findsNothing);
    expect(find.byType(GalleryStrip), findsNothing);
  });

  testWidgets('yükleme ve hata durumlarını ayırıyor', (tester) async {
    await pumpInApp(tester, const JobGalleryView(images: [], isLoading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var retried = false;
    await pumpInApp(
      tester,
      JobGalleryView(
        images: const [],
        isLoading: false,
        errorMessage: 'İlan bulunamadı.',
        onRetry: () => retried = true,
      ),
    );
    await tester.tap(find.text('Tekrar dene'));
    expect(retried, isTrue);
  });

  testWidgets('görselleri salt okunur ortak şeritle gösteriyor', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const JobGalleryView(
        images: [GalleryImage(id: 'img_1', url: 'not-a-url')],
        isLoading: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Galeri'), findsOneWidget);
    expect(find.byType(GalleryStrip), findsOneWidget);
    expect(find.text('Görsel Ekle'), findsNothing);
    expect(find.text('Kaldır'), findsNothing);
  });
}
