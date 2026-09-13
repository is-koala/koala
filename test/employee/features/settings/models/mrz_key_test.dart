import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';

/// Gerçek bir TCKK düzeninde, kontrol haneleri hesaplanmış TD1 MRZ'si.
///
/// Birinci satır: `I<TUR` + belge no + kontrol hanesi + isteğe bağlı veri
/// (TCKN). İkinci satır: doğum tarihi + kontrol, cinsiyet, son geçerlilik +
/// kontrol, uyruk, isteğe bağlı veri 2 ve bileşik kontrol hanesi.
const String _line1 = 'I<TURA01B23456612345678950<<<<';
const String _line2 = '9804072F3001019TUR<<<<<<<<<<<8';
const String _line3 = 'KAYA<<ADA<<<<<<<<<<<<<<<<<<<<<';

const String _mrz = '$_line1\n$_line2\n$_line3';

void main() {
  group('MrzKey.checkDigit', () {
    test('ICAO 7-3-1 ağırlıkları uygulanıyor', () {
      // ICAO Doc 9303 Part 3 §4.9'daki örnek dizgi.
      expect(MrzKey.checkDigit('D23145890734'), 9);
      expect(MrzKey.checkDigit('340712'), 7);
    });

    test('`<` sıfır sayılıyor', () {
      expect(MrzKey.checkDigit('AB2134<<<'), MrzKey.checkDigit('AB2134000'));
    });

    test('tanımsız karakter sıfır sayılmıyor, hesap reddediliyor', () {
      // Sıfır saymak, hatalı okunmuş bir alanı geçerli gösterirdi.
      expect(MrzKey.checkDigit('AB21-4<<<'), isNull);
    });

    test('doğrulama beklenen haneyle karşılaştırıyor', () {
      expect(MrzKey.isCheckDigitValid('A01B23456', '6'), isTrue);
      expect(MrzKey.isCheckDigitValid('A01B23456', '7'), isFalse);
    });
  });

  group('MrzKey.parseTd1', () {
    test('üç satırlık TD1 çipi açan üç alana ayrışıyor', () {
      final key = MrzKey.parseTd1(_mrz);

      expect(key, isNotNull);
      expect(key!.documentNumber, 'A01B23456');
      expect(key.birthDate, DateTime(1998, 4, 7));
      expect(key.expiryDate, DateTime(2030, 1, 1));
    });

    test('TCKN birinci satırın isteğe bağlı veri alanından okunuyor', () {
      expect(MrzKey.parseTd1(_mrz)!.nationalIdentityNumber, '12345678950');
    });

    test('ayırıcı `<` ile başlayan TCKN düzeni de okunuyor', () {
      // TCKK'nın sahadaki ikinci düzeni; kural çipteki DG1 ile ortak
      // (`NationalIdentityNumber`) ve iki yol aynı numarayı vermeli.
      const line1 = 'I<TURA01B234566<12345678950<<<';
      final composite =
          line1.substring(5, 30) +
          _line2.substring(0, 7) +
          _line2.substring(8, 15) +
          _line2.substring(18, 29);
      final line2 = _line2.replaceRange(29, 30, _checkDigit(composite));

      expect(
        MrzKey.parseTd1('$line1\n$line2\n$_line3')?.nationalIdentityNumber,
        '12345678950',
      );
    });

    test('OCR gürültüsü ve boşluklar temizleniyor', () {
      // MRZ satırlarını çevreleyen başka metin ve `<` yerine okunan `«`.
      final noisy =
          'TÜRKİYE CUMHURİYETİ\n'
          '${_line1.replaceAll('<', '«')}\n'
          '$_line2\n'
          '$_line3\n';

      expect(MrzKey.parseTd1(noisy)?.documentNumber, 'A01B23456');
    });

    test('üç satır tek satıra yapıştığında da ayrışıyor', () {
      expect(MrzKey.parseTd1('$_line1$_line2$_line3'), isNotNull);
    });

    test('tarih alanındaki harfler rakama düzeltiliyor', () {
      // `0` yerine `O`, `1` yerine `I`: OCR'ın en sık karıştırdığı ikili.
      final misread = _line2.replaceRange(0, 6, '98O4O7');

      expect(
        MrzKey.parseTd1('$_line1\n$misread\n$_line3')?.birthDate,
        DateTime(1998, 4, 7),
      );
    });

    test('belge numarası kontrol hanesi tutmazsa tarama reddediliyor', () {
      // Güvenlik ağı: yanlış anahtarla çipe gidilseydi kullanıcı
      // anlaşılmaz bir "kart okunamadı" görürdü.
      final broken = _line1.replaceRange(5, 14, 'A01B23457');

      expect(MrzKey.parseTd1('$broken\n$_line2\n$_line3'), isNull);
    });

    test('bileşik kontrol hanesi tutmazsa tarama reddediliyor', () {
      // Üç alanın kendi kontrol hanesi tutuyor ama isteğe bağlı veri
      // alanında (TCKN) bir hane yanlış okunmuş. Bunu yalnızca bileşik
      // hane yakalıyor — asıl varlık sebebi bu.
      final broken = _line1.replaceRange(15, 26, '12345678951');

      expect(MrzKey.parseTd1('$broken\n$_line2\n$_line3'), isNull);
    });

    test('cinsiyet hanesi bileşik kontrolün dışında kalıyor', () {
      // ICAO bileşik haneyi orta satırın 1-7, 9-15 ve 19-29
      // pozisyonlarından hesaplıyor; 8. pozisyondaki cinsiyet dahil değil.
      // Dahil sayılsaydı geçerli her kart reddedilirdi.
      final other = _line2.replaceRange(7, 8, 'M');

      expect(MrzKey.parseTd1('$_line1\n$other\n$_line3'), isNotNull);
    });

    test('eksik satır ayrıştırılmıyor', () {
      expect(MrzKey.parseTd1('$_line1\n$_line2'), isNull);
    });

    test('pasaportun TD3 düzeni TD1 diye okunmuyor', () {
      // TD3 iki satır × 44 karakter; uzunluk tutmadığı için aday bile
      // olmuyor.
      const td3 =
          'P<TURKAYA<<ADA<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n'
          'A01B234566TUR9804072F3001019<<<<<<<<<<<<<<04';

      expect(MrzKey.parseTd1(td3), isNull);
    });

    test('geçersiz takvim günü taşma yapmadan reddediliyor', () {
      // `DateTime(2025, 2, 30)` sessizce 2 Mart'a taşıyor; taşan bir tarih
      // kabul edilseydi çip anahtarı yanlış üretilirdi.
      const day = '980230';
      final line2 = '$day${_checkDigit(day)}F3001019TUR<<<<<<<<<<<';
      final composite =
          _line1.substring(5, 30) +
          line2.substring(0, 7) +
          line2.substring(8, 15) +
          line2.substring(18, 29);

      expect(
        MrzKey.parseTd1('$_line1\n$line2${_checkDigit(composite)}\n$_line3'),
        isNull,
      );
    });
  });

  group('MrzKey yüzyıl çıkarımı', () {
    test('son geçerlilik her zaman 2000\'li yıllar', () {
      // 19xx'te biten bir kart zaten geçersiz olurdu.
      expect(MrzKey.parseTd1(_mrz)!.expiryDate.year, 2030);
    });

    test('doğum yılı bugünün iki hanesinden büyükse 19xx sayılıyor', () {
      expect(MrzKey.parseTd1(_mrz)!.birthDate.year, 1998);
    });
  });

  group('MrzKey.manual', () {
    test('elle giriş büyük harfe çevrilip boşluklardan arındırılıyor', () {
      final key = MrzKey.manual(
        documentNumber: '  a01b23456 ',
        birthDate: DateTime(1998, 4, 7),
        expiryDate: DateTime(2030, 1, 1),
      );

      expect(key.documentNumber, 'A01B23456');
      // Elle girişte MRZ'nin isteğe bağlı alanı yok; TCKN uydurulmuyor.
      expect(key.nationalIdentityNumber, isNull);
    });
  });
}

String _checkDigit(String field) => '${MrzKey.checkDigit(field)}';
