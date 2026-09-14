import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/constants/upload_limits.dart';

import '../../../../support/identity_document_fixtures.dart';

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

  group('IdentityImageFormat', () {
    test('JPEG, PNG ve WEBP imzaları biçimleriyle tanınıyor', () {
      expect(
        IdentityImageFormat.detect(jpegSignatureBytes),
        IdentityImageFormat.jpeg,
      );
      expect(IdentityImageFormat.detect(onePixelPng), IdentityImageFormat.png);
      expect(
        IdentityImageFormat.detect([
          ...'RIFF'.codeUnits,
          0x24, 0x00, 0x00, 0x00, //
          ...'WEBP'.codeUnits,
          ...'VP8 '.codeUnits,
        ]),
        IdentityImageFormat.webp,
      );
      expect(IdentityImageFormat.detect('GIF89a'.codeUnits), isNull);
      expect(IdentityImageFormat.detect(const []), isNull);
    });

    test('HEIF kutusu markasından tanınıyor', () {
      expect(IdentityImageFormat.isHeif(heicSignatureBytes), isTrue);
      expect(
        IdentityImageFormat.isHeif([
          0x00, 0x00, 0x00, 0x1C, //
          ...'ftypmif1'.codeUnits,
        ]),
        isTrue,
      );
      expect(IdentityImageFormat.isHeif(jpegSignatureBytes), isFalse);
      expect(IdentityImageFormat.isHeif(onePixelPng), isFalse);
    });

    test('uzantı ve içerik tipi sunucunun kabul ettiği kümeden', () {
      for (final format in IdentityImageFormat.values) {
        expect(
          IdentityPhotoPolicy.allowedExtensions,
          contains(format.extension),
          reason: format.name,
        );
        expect(format.mimeType, startsWith('image/'), reason: format.name);
      }
    });
  });

  group('IdentityPhotoPolicy', () {
    IdentityPhotoCandidate candidate({
      required List<int> head,
      int bytes = 1024,
      String path = '/tmp/on.jpg',
    }) => IdentityPhotoCandidate(
      slot: IdentityPhotoSlot.front,
      path: path,
      bytes: bytes,
      head: head,
    );

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

    test('biçim uzantıdan değil içerikten: .heic adlı JPEG kabul, adı ve '
        'tipi JPEG', () {
      // Android galerisinden HEIC seçilince seçici JPEG'e çeviriyor ama adı
      // `.heic` bırakıyor; uzantıya bakan denetim doğru kareyi reddederdi.
      final (:photo, :rejection) = IdentityPhotoPolicy.accept(
        candidate(head: jpegSignatureBytes, path: '/tmp/IMG_0001.HEIC'),
      );

      expect(rejection, isNull);
      expect(photo!.format, IdentityImageFormat.jpeg);
      expect(photo.uploadName, 'front.jpg');
      expect(photo.format.mimeType, 'image/jpeg');
    });

    test('gerçek HEIC baytları adı ne olursa olsun kendi mesajıyla '
        'reddediliyor', () {
      for (final path in const ['/tmp/IMG_0001.heic', '/tmp/kare.jpg']) {
        final (:photo, :rejection) = IdentityPhotoPolicy.accept(
          candidate(head: heicSignatureBytes, path: path),
        );
        expect(photo, isNull, reason: path);
        expect(rejection, IdentityPhotoRejection.heic, reason: path);
      }
      expect(IdentityPhotoRejection.heic.message, contains('HEIC'));
    });

    test('tanınmayan imza reddediliyor', () {
      expect(
        IdentityPhotoPolicy.accept(
          candidate(head: 'GIF89a'.codeUnits, path: '/tmp/on.jpg'),
        ).rejection,
        IdentityPhotoRejection.unsupportedType,
      );
      expect(
        IdentityPhotoPolicy.accept(candidate(head: const [])).rejection,
        IdentityPhotoRejection.unsupportedType,
      );
    });

    test('10 MB sınırının tam üstü kabul, bir bayt fazlası ret', () {
      expect(
        IdentityPhotoPolicy.accept(
          candidate(
            head: jpegSignatureBytes,
            bytes: IdentityPhotoPolicy.maxPhotoBytes,
          ),
        ).photo,
        isNotNull,
      );
      expect(
        IdentityPhotoPolicy.accept(
          candidate(
            head: jpegSignatureBytes,
            bytes: IdentityPhotoPolicy.maxPhotoBytes + 1,
          ),
        ).rejection,
        IdentityPhotoRejection.tooLarge,
      );
    });

    test('dört dosyanın toplamı 40 MB\'ı aşınca reddediliyor', () {
      IdentityPhoto photo(IdentityPhotoSlot slot, int bytes) => IdentityPhoto(
        slot: slot,
        path: '/tmp/${slot.name}.jpg',
        bytes: bytes,
        format: IdentityImageFormat.jpeg,
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
  });
}
