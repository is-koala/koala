import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/gallery_image.dart';

void main() {
  group('GalleryImage', () {
    test('sunucu yanıtını ve toptan güncelleme satırını dönüştürüyor', () {
      final image = GalleryImage.fromJson(const {
        'id': 'img_1',
        'url': 'https://cdn.local/1.png',
        'sortOrder': 3,
        'cover': true,
        'caption': 'Salon',
      });

      expect(image.isCover, isTrue);
      expect(image.toEntryJson(sortOrder: 0), {
        'imageId': 'img_1',
        'sortOrder': 0,
        'cover': true,
        'caption': 'Salon',
      });
    });

    test('liste dönüştürücü sıralı sunucu yanıtını koruyor', () {
      final images = GalleryImage.listFromJson([
        {'id': 'img_2', 'url': '2.png', 'sortOrder': 0},
        {'id': 'img_1', 'url': '1.png', 'sortOrder': 1},
      ]);

      expect(images.map((image) => image.id), ['img_2', 'img_1']);
    });

    test('copyWith kapak ve sırayı değiştirirken medyayı koruyor', () {
      const image = GalleryImage(
        id: 'img_1',
        url: 'https://cdn.local/1.png',
        caption: 'Salon',
      );

      final updated = image.copyWith(sortOrder: 2, isCover: true);

      expect(updated.id, image.id);
      expect(updated.url, image.url);
      expect(updated.caption, image.caption);
      expect(updated.sortOrder, 2);
      expect(updated.isCover, isTrue);
    });
  });
}
