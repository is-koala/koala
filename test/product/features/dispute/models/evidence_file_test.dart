import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';

import '../../../../support/dispute_evidence_fixtures.dart';

/// Yükleme anı; adı olmayan dosyanın adı buradan.
final DateTime _now = DateTime(2026, 10, 3, 10, 42, 31);

EvidenceCandidate _candidate(
  List<int> content, {
  String? name = 'dosya',
  int? bytes,
}) => EvidenceCandidate(
  path: '/tmp/${name ?? 'gecici'}',
  bytes: bytes ?? content.length,
  head: content.take(EvidenceFormat.signatureLength).toList(),
  displayName: name,
);

({EvidenceFile? file, EvidenceRejection? rejection}) _accept(
  EvidenceCandidate candidate,
) => DisputeEvidencePolicy.accept(candidate, now: _now);

void main() {
  group('EvidenceFormat.detect', () {
    test('biçimi içerik imzasından tanır', () {
      expect(EvidenceFormat.detect(jpegSignatureBytes), EvidenceFormat.jpeg);
      expect(EvidenceFormat.detect(onePixelPng), EvidenceFormat.png);
      expect(EvidenceFormat.detect(pdfBytes), EvidenceFormat.pdf);
    });

    // Sunucuda WebP okuyan bir ImageIO eklentisi yok; gerçek bir WebP hep
    // `STORAGE_UNSUPPORTED_TYPE` ile düşüyor (koala-backend#348), o yüzden
    // vaat edilmiyor.
    test('WebP tanınmaz ve reddedilir', () {
      final webp = [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits];

      expect(EvidenceFormat.detect(webp), isNull);
      expect(
        _accept(_candidate(webp, name: 'foto.webp')).rejection,
        EvidenceRejection.unsupportedType,
      );
      expect(
        EvidenceFormat.values.map((format) => format.extension),
        isNot(contains('webp')),
      );
    });

    test('tanınmayan ya da kısa başlık null', () {
      expect(EvidenceFormat.detect(const []), isNull);
      expect(EvidenceFormat.detect('MZ'.codeUnits), isNull);
      expect(EvidenceFormat.detect(const [0x25, 0x50, 0x44]), isNull);
    });

    test('uzantı ve MIME biçimin kendisinden', () {
      expect(EvidenceFormat.jpeg.extension, 'jpg');
      expect(EvidenceFormat.jpeg.mimeType, 'image/jpeg');
      expect(EvidenceFormat.pdf.extension, 'pdf');
      expect(EvidenceFormat.pdf.mimeType, 'application/pdf');
      expect(EvidenceFormat.pdf.isImage, isFalse);
      expect(EvidenceFormat.png.isImage, isTrue);
    });

    // Sunucunun uzantı beyaz listesi ile içerik biçimleri aynı küme olmalı:
    // biri genişlerse ötekinin de genişlemesi gerekiyor.
    test('her biçimin uzantısı sunucunun beyaz listesinde', () {
      for (final format in EvidenceFormat.values) {
        expect(
          DisputeEvidencePolicy.allowedExtensions,
          contains(format.extension),
          reason: format.name,
        );
      }
      expect(DisputeEvidencePolicy.allowedExtensions, {
        'pdf',
        'png',
        'jpg',
        'jpeg',
      });
    });
  });

  group('DisputeEvidencePolicy.accept', () {
    test('geçerli dosyayı içerikten yazılmış adla kabul eder', () {
      // Ad `.heic`, içerik JPEG: Android seçicisinin yeniden kodladığı kare.
      final result = _accept(
        _candidate(jpegSignatureBytes, name: 'IMG_1.heic'),
      );

      expect(result.rejection, isNull);
      expect(result.file!.format, EvidenceFormat.jpeg);
      expect(result.file!.uploadName, 'IMG_1.jpg');
    });

    test('PDF kabul edilir', () {
      final result = _accept(_candidate(pdfBytes, name: 'tutanak.pdf'));

      expect(result.file!.format, EvidenceFormat.pdf);
      expect(result.file!.uploadName, 'tutanak.pdf');
    });

    test('boş dosya reddedilir', () {
      final result = _accept(_candidate(const [], name: 'bos.pdf', bytes: 0));

      expect(result.rejection, EvidenceRejection.empty);
      expect(result.file, isNull);
    });

    test('HEIC kendi mesajıyla reddedilir', () {
      final result = _accept(_candidate(heicSignatureBytes, name: 'IMG.heic'));

      expect(result.rejection, EvidenceRejection.heic);
      expect(result.rejection!.message, contains('HEIC'));
    });

    test('uzantısı doğru ama içeriği tanınmayan dosya reddedilir', () {
      final result = _accept(
        _candidate('MZ-bir-exe'.codeUnits, name: 'kanit.pdf'),
      );

      expect(result.rejection, EvidenceRejection.unsupportedType);
    });

    test('10 MiB sınırı: sınırda kabul, bir bayt fazlada ret', () {
      final atLimit = _accept(
        _candidate(
          pdfBytes,
          name: 'a.pdf',
          bytes: DisputeEvidencePolicy.maxFileBytes,
        ),
      );
      final over = _accept(
        _candidate(
          pdfBytes,
          name: 'a.pdf',
          bytes: DisputeEvidencePolicy.maxFileBytes + 1,
        ),
      );

      expect(atLimit.file, isNotNull);
      expect(over.rejection, EvidenceRejection.tooLarge);
      expect(DisputeEvidencePolicy.maxFileBytes, 10 * 1024 * 1024);
    });

    test('her ret bir mesaj taşır', () {
      for (final rejection in EvidenceRejection.values) {
        expect(rejection.message, isNotEmpty, reason: rejection.name);
      }
    });
  });

  group('adı olmayan dosya', () {
    test('kanit-<yükleme anı> adını alır, uzantı içerikten', () {
      final result = _accept(_candidate(jpegSignatureBytes, name: null));

      expect(result.file!.uploadName, 'kanit-20261003-104231.jpg');
    });

    // Seçim ya da çekim anı değil, yükleme anı: personel adı çekim zamanı
    // sanmasın.
    test('ad yüklemenin saatinden, adayın değil', () {
      final candidate = _candidate(jpegSignatureBytes, name: null);

      final first = DisputeEvidencePolicy.accept(
        candidate,
        now: DateTime(2026, 10, 3, 10, 42, 31),
      );
      final later = DisputeEvidencePolicy.accept(
        candidate,
        now: DateTime(2026, 10, 3, 10, 43, 2),
      );

      expect(first.file!.uploadName, 'kanit-20261003-104231.jpg');
      expect(later.file!.uploadName, 'kanit-20261003-104302.jpg');
    });

    test('PDF kendi adını korur', () {
      final result = _accept(_candidate(pdfBytes, name: 'Tutanak 1.pdf'));

      expect(result.file!.uploadName, 'Tutanak 1.pdf');
    });

    test('tek haneli ay, gün ve saat sıfırla doldurulur', () {
      expect(
        DisputeEvidencePolicy.generatedBaseName(DateTime(2026, 1, 2, 3, 4, 5)),
        'kanit-20260102-030405',
      );
    });
  });

  group('uploadNameFor', () {
    test('uzantıyı gerçek biçime çevirir', () {
      expect(
        DisputeEvidencePolicy.uploadNameFor('foto.heic', EvidenceFormat.jpeg),
        'foto.jpg',
      );
      expect(
        DisputeEvidencePolicy.uploadNameFor('rapor.PDF', EvidenceFormat.pdf),
        'rapor.pdf',
      );
    });

    test('klasör ayracı ve tehlikeli işaretleri temizler', () {
      expect(
        DisputeEvidencePolicy.uploadNameFor(
          '../../etc/pass:wd?.pdf',
          EvidenceFormat.pdf,
        ),
        'pass_wd_.pdf',
      );
      expect(
        DisputeEvidencePolicy.uploadNameFor(
          r'C:\x\y\z.png',
          EvidenceFormat.png,
        ),
        'z.png',
      );
    });

    test('boş, noktalı ya da gizli ad kanit olur', () {
      expect(
        DisputeEvidencePolicy.uploadNameFor('', EvidenceFormat.jpeg),
        'kanit.jpg',
      );
      expect(
        DisputeEvidencePolicy.uploadNameFor('...', EvidenceFormat.jpeg),
        'kanit.jpg',
      );
      expect(
        DisputeEvidencePolicy.uploadNameFor('.gizli.jpg', EvidenceFormat.jpeg),
        'gizli.jpg',
      );
    });

    test('uzun ad kısaltılır, Türkçe harfler korunur', () {
      final name = DisputeEvidencePolicy.uploadNameFor(
        '${'ş' * 200}.pdf',
        EvidenceFormat.pdf,
      );

      expect(name, '${'ş' * DisputeEvidencePolicy.maxBaseNameLength}.pdf');
    });
  });

  group('DisputeEvidencePolicy.canAttach', () {
    test('açık uyuşmazlıkta ve sınırın altında ekleme var', () {
      expect(DisputeEvidencePolicy.canAttach(isOpen: true, count: 0), isTrue);
      expect(DisputeEvidencePolicy.canAttach(isOpen: true, count: 4), isTrue);
    });

    test('beşinci dosyadan sonra ve sonuçlanmış uyuşmazlıkta yok', () {
      expect(DisputeEvidencePolicy.canAttach(isOpen: true, count: 5), isFalse);
      expect(DisputeEvidencePolicy.canAttach(isOpen: false, count: 0), isFalse);
      expect(DisputeEvidencePolicy.maxPerDispute, 5);
    });
  });

  test('fotoğraf ölçeği kimlik fotoğraflarıyla aynı kaynaktan', () {
    // İki ayrı sabit olsaydı biri değişince ötekini yeniden kodlama
    // garantisi (HEIC → JPEG) sessizce bozulabilirdi.
    expect(DisputeEvidencePolicy.maxDimension, 2560);
    expect(DisputeEvidencePolicy.quality, 90);
  });
}
