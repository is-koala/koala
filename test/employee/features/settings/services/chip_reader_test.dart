import 'dart:async';

import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/internal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/services/chip_reader.dart';

/// Cihaz gerektirmeyen tek ama en kıymetli parça: `dmrtd`'nin hatasının
/// kullanıcıya ne söyleyeceğe çevrildiği yer.
///
/// Hepsini "bir hata oluştu" göstermek bu akışta kullanıcıyı döngüye
/// sokuyor: "kart hareket etti" tekrar denemekle çözülüyor, "bu telefonda
/// NFC yok" asla çözülmüyor.
void main() {
  group('ChipReader.failureFor', () {
    test('yanlış anahtar güvenlik durumu hatasından ayrışıyor', () {
      // BAC/PACE anahtarı kartın beklediği değilse çip güvenlik durumunun
      // sağlanmadığını söylüyor. Kullanıcı tarafındaki karşılığı tek:
      // MRZ'den okunan üç alandan biri yanlış.
      final error = PassportError(
        'security status not satisfied',
        code: StatusWord.securityStatusNotSatisfied,
      );

      expect(ChipReader.failureFor(error), ChipReadFailure.wrongKey);
    });

    test('eski kartların 63xx yanıtı da yanlış anahtar sayılıyor', () {
      // Bazı eski belgeler yanlış DBA anahtarında 63CF döndürüyor.
      final error = PassportError(
        'authentication failed',
        code: const StatusWord(sw1: 0x63, sw2: 0xCF),
      );

      expect(ChipReader.failureFor(error), ChipReadFailure.wrongKey);
    });

    test('dosya bulunamadı çipin desteklenmediğini söylüyor', () {
      // eMRTD uygulaması yoksa okutulan şey çipli kimlik kartı değil.
      final error = PassportError('no file', code: StatusWord.fileNotFound);

      expect(ChipReader.failureFor(error), ChipReadFailure.chipUnsupported);
    });

    test('bağlantı hatası kartın hareket ettiği anlamına geliyor', () {
      expect(
        ChipReader.failureFor(const ComProviderError('tag lost')),
        ChipReadFailure.cardMoved,
      );
    });

    test('çözümlenemeyen dosya desteklenmeyen çip sayılıyor', () {
      expect(
        ChipReader.failureFor(EfParseError('bad tag')),
        ChipReadFailure.chipUnsupported,
      );
    });

    test('zaten sınıflandırılmış hata olduğu gibi taşınıyor', () {
      const failure = ChipReadException(ChipReadFailure.nfcDisabled);

      expect(ChipReader.failureFor(failure), ChipReadFailure.nfcDisabled);
    });

    test('tanınmayan hata bilinmeyen olarak işaretleniyor', () {
      expect(
        ChipReader.failureFor(StateError('beklenmedik')),
        ChipReadFailure.unknown,
      );
    });
  });

  group('ChipReader.readOptional', () {
    // DG14 yardımcı bilgi: sunucu onsuz da doğruluyor. EF.COM'da listelenip
    // yine de okunamayan bir dosya, bu PR öncesinde doğrulanabilen bir
    // kartı doğrulanamaz hâle getirmemeli.
    test('okunan dosya olduğu gibi dönüyor', () async {
      final result = await ChipReader.readOptional(() async => 'dg14');

      expect(result, 'dg14');
    });

    test('kartın vermediği dosya akışı bozmuyor', () async {
      // Kart dosyayı reddetti (ör. 6A82 dosya yok). Güvenli kanal sayacı
      // hatalı yanıtta da ilerlediği için sonraki okuma normal sürüyor.
      final result = await ChipReader.readOptional<String>(
        () async =>
            throw PassportError('no file', code: StatusWord.fileNotFound),
      );

      expect(result, isNull);
    });

    test('çözülemeyen içerik akışı bozmuyor', () async {
      final result = await ChipReader.readOptional<String>(
        () async => throw EfParseError('bad tag'),
      );

      expect(result, isNull);
    });

    test('kartın uzaklaşması yutulmuyor', () async {
      // Bağlantı koptuysa bir sonraki dosya da okunamayacak; sebebi burada
      // gizlemek kullanıcıya yanlış bir hata gösterirdi.
      await expectLater(
        ChipReader.readOptional<String>(
          () async => throw const ComProviderError('tag lost'),
        ),
        throwsA(isA<ComProviderError>()),
      );
    });

    test('zaten sınıflandırılmış hata olduğu gibi yükseliyor', () async {
      await expectLater(
        ChipReader.readOptional<String>(
          () async => throw const ChipReadException(ChipReadFailure.cardMoved),
        ),
        throwsA(
          isA<ChipReadException>().having(
            (error) => error.reason,
            'reason',
            ChipReadFailure.cardMoved,
          ),
        ),
      );
    });
  });

  group('ChipReader.availability', () {
    testWidgets('yanıtsız kalan sorgu sonsuza kadar beklenmiyor', (
      tester,
    ) async {
      // Eklentinin kanalı bağlı değilse `nfcAvailability` hiç
      // tamamlanmıyor. Süre sınırı olmasa ekran sonsuza kadar dönen bir
      // göstergede kalır, kullanıcının tek çıkışı geri tuşu olurdu.
      NfcAvailability? result;
      unawaited(ChipReader().availability().then((value) => result = value));

      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(result, NfcAvailability.unsupported);
    });
  });

  group('ChipReadFailure', () {
    test('donanımı olmayan cihazda tekrar denemek önerilmiyor', () {
      // Tekrar butonu göstermek kullanıcıyı sonu olmayan bir döngüye sokar.
      expect(ChipReadFailure.nfcUnsupported.canRetry, isFalse);
    });

    test('geri kalan her sebepte tekrar denemenin bir anlamı var', () {
      final hopeless = ChipReadFailure.values
          .where((failure) => !failure.canRetry)
          .toList();

      expect(hopeless, [ChipReadFailure.nfcUnsupported]);
    });

    test('her sebep dolu bir başlık ve yönlendirme taşıyor', () {
      for (final failure in ChipReadFailure.values) {
        expect(failure.title.trim(), isNotEmpty, reason: failure.name);
        expect(failure.message.trim(), isNotEmpty, reason: failure.name);
      }
    });
  });
}
