import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/constants/upload_limits.dart';

void main() {
  group('IdentityPhotoSlot', () {
    test('dört kare sunucunun parça adlarını taşıyor', () {
      expect(IdentityPhotoSlot.values.map((slot) => slot.fieldName), [
        'front',
        'back',
        'selfie',
        'together',
      ]);
    });

    test('yüz kareleri ön kamera, kart kareleri arka kamera', () {
      expect(IdentityPhotoSlot.front.usesFrontCamera, isFalse);
      expect(IdentityPhotoSlot.back.usesFrontCamera, isFalse);
      expect(IdentityPhotoSlot.selfie.usesFrontCamera, isTrue);
      expect(IdentityPhotoSlot.together.usesFrontCamera, isTrue);
    });

    test('her karenin başlığı ve kadraj rehberi var', () {
      for (final slot in IdentityPhotoSlot.values) {
        expect(slot.title, isNotEmpty, reason: slot.name);
        expect(slot.guide, isNotEmpty, reason: slot.name);
      }
    });
  });

  group('IdentityPhotoPolicy', () {
    test('sınırlar sunucu ve web ile aynı', () {
      // Sunucu: dosya başına 10 MiB (`upload.max-image-size-mb`), toplam
      // istek 42 MB; web: dört × 10 MiB = 40 MiB içerik bütçesi.
      expect(IdentityPhotoPolicy.maxPhotoBytes, 10 * 1024 * 1024);
      expect(IdentityPhotoPolicy.maxPhotoBytes, UploadLimits.maxImageBytes);
      expect(IdentityPhotoPolicy.photoCount, IdentityPhotoSlot.values.length);
      expect(IdentityPhotoPolicy.maxTotalBytes, 4 * 10 * 1024 * 1024);
      expect(IdentityPhotoPolicy.allowedExtensions, {
        'png',
        'jpg',
        'jpeg',
        'webp',
      });
    });

    test('seçici yeniden kodlamaya zorlanıyor', () {
      // Kalite 100 Android seçicisinde yeniden kodlamayı atlatıyor ve HEIC
      // olduğu gibi gelirdi; ölçek de 50 MP tavanının çok altında.
      expect(IdentityPhotoPolicy.quality, lessThan(100));
      expect(
        IdentityPhotoPolicy.maxDimension * IdentityPhotoPolicy.maxDimension,
        lessThan(50 * 1000 * 1000),
      );
    });

    test('kabul edilen uzantı ve boyut geçiyor', () {
      for (final extension in const ['jpg', 'JPEG', 'png', 'webp']) {
        expect(
          IdentityPhotoPolicy.check(path: '/tmp/on.$extension', bytes: 1024),
          isNull,
          reason: extension,
        );
      }
      expect(
        IdentityPhotoPolicy.check(
          path: '/tmp/on.jpg',
          bytes: IdentityPhotoPolicy.maxPhotoBytes,
        ),
        isNull,
        reason: 'sınırın tam üstü kabul',
      );
    });

    test('HEIC kendi mesajıyla reddediliyor', () {
      expect(
        IdentityPhotoPolicy.check(path: '/tmp/IMG_0001.HEIC', bytes: 1024),
        IdentityPhotoRejection.heic,
      );
      expect(
        IdentityPhotoPolicy.check(path: '/tmp/IMG_0001.heif', bytes: 1024),
        IdentityPhotoRejection.heic,
      );
      expect(IdentityPhotoRejection.heic.message, contains('HEIC'));
    });

    test('tanınmayan uzantı ve uzantısız dosya reddediliyor', () {
      expect(
        IdentityPhotoPolicy.check(path: '/tmp/on.gif', bytes: 1024),
        IdentityPhotoRejection.unsupportedType,
      );
      expect(
        IdentityPhotoPolicy.check(path: '/tmp/on', bytes: 1024),
        IdentityPhotoRejection.unsupportedType,
      );
      expect(
        IdentityPhotoPolicy.check(path: '/tmp/on.', bytes: 1024),
        IdentityPhotoRejection.unsupportedType,
      );
    });

    test('10 MB üstü tek dosya reddediliyor', () {
      expect(
        IdentityPhotoPolicy.check(
          path: '/tmp/on.jpg',
          bytes: IdentityPhotoPolicy.maxPhotoBytes + 1,
        ),
        IdentityPhotoRejection.tooLarge,
      );
    });

    test('dört dosyanın toplamı 40 MB\'ı aşınca reddediliyor', () {
      IdentityPhoto photo(IdentityPhotoSlot slot, int bytes) => IdentityPhoto(
        slot: slot,
        path: '/tmp/${slot.name}.jpg',
        bytes: bytes,
      );
      const tenMb = 10 * 1024 * 1024;

      expect(
        IdentityPhotoPolicy.checkTotal([
          for (final slot in IdentityPhotoSlot.values) photo(slot, tenMb),
        ]),
        isNull,
        reason: 'dört tam dosya tam sınır',
      );
      expect(
        IdentityPhotoPolicy.checkTotal([
          for (final slot in IdentityPhotoSlot.values) photo(slot, tenMb),
          photo(IdentityPhotoSlot.front, 1),
        ]),
        IdentityPhotoRejection.totalTooLarge,
      );
    });

    test('uzantı yoldan değil dosya adından okunuyor', () {
      expect(IdentityPhotoPolicy.extensionOf('/a.b/c/on.JPG'), 'jpg');
      expect(IdentityPhotoPolicy.extensionOf('/a.b/c/on'), '');
    });
  });
}
