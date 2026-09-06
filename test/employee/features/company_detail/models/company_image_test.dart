import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/company_detail/models/company_image.dart';

void main() {
  group('CompanyImage', () {
    test('sunucunun `cover` alanı `isCover`a çevriliyor', () {
      final image = CompanyImage.fromJson(const {
        'id': 'img_1',
        'url': 'https://cdn.local/1.png',
        'sortOrder': 2,
        'cover': true,
        'caption': 'Salon',
      });

      expect(image.id, 'img_1');
      expect(image.url, 'https://cdn.local/1.png');
      expect(image.sortOrder, 2);
      expect(image.isCover, isTrue);
      expect(image.caption, 'Salon');
    });

    test('toEntryJson `GalleryImageEntryDto` alanlarını üretiyor', () {
      const image = CompanyImage(
        id: 'img_1',
        url: 'https://cdn.local/1.png',
        sortOrder: 3,
        isCover: true,
        caption: 'Salon',
      );

      // Sunucu satır kimliğini değil görselin kimliğini bekliyor
      // (`GalleryMapper` `id`yi `image.id`den eşliyor) ve bayrağın adı
      // `isCover` değil `cover`.
      expect(image.toEntryJson(), {
        'imageId': 'img_1',
        'sortOrder': 3,
        'cover': true,
        'caption': 'Salon',
      });
    });

    test('toEntryJson listedeki konumu sıra numarası olarak yazıyor', () {
      const image = CompanyImage(id: 'img_1', url: '', sortOrder: 3);

      // Toptan güncellemede sıra listenin kendisinden geliyor; modeldeki
      // eski değer gönderilseydi sürükleme hiç kaydedilmezdi.
      expect(image.toEntryJson(sortOrder: 0)['sortOrder'], 0);
    });

    test('copyWith kapak bayrağını değiştiriyor, gerisini koruyor', () {
      const image = CompanyImage(
        id: 'img_1',
        url: 'https://cdn.local/1.png',
        sortOrder: 3,
        caption: 'Salon',
      );

      final cover = image.copyWith(isCover: true);

      expect(cover.isCover, isTrue);
      expect(cover.id, 'img_1');
      expect(cover.url, 'https://cdn.local/1.png');
      expect(cover.caption, 'Salon');
    });
  });
}
