import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/national_identity_number.dart';

/// TCKN kuralı tek yerde: canlı MRZ taraması, çipteki DG1 ve elle beyan
/// hepsi buraya bakıyor. Kural üç kopyaya ayrıştığında ayırıcı `<` ile
/// başlayan geçerli bir kart tek bir yolda okunamaz sayılmıştı.
void main() {
  group('NationalIdentityNumber.fromMrzOptionalData', () {
    test('numara başta, dolgu arkada', () {
      expect(
        NationalIdentityNumber.fromMrzOptionalData('12345678950<<<<'),
        '12345678950',
      );
    });

    test('ayırıcı `<` başta, numara arkasında', () {
      // Sunucu bütün `<`'leri atıp on bir hane arıyor; `dmrtd` ise yalnız
      // sondaki dolguyu temizliyor. İki düzen de aynı numarayı vermeli.
      expect(
        NationalIdentityNumber.fromMrzOptionalData('<12345678950<<<'),
        '12345678950',
      );
      expect(
        NationalIdentityNumber.fromMrzOptionalData('<12345678950'),
        '12345678950',
      );
    });

    test('boşluk da dolgu sayılıyor', () {
      expect(
        NationalIdentityNumber.fromMrzOptionalData(' 12345678950 '),
        '12345678950',
      );
    });

    test('dolgu atıldıktan sonra tam on bir hane kalmıyorsa null', () {
      expect(NationalIdentityNumber.fromMrzOptionalData(''), isNull);
      expect(NationalIdentityNumber.fromMrzOptionalData('<<<<<'), isNull);
      expect(
        NationalIdentityNumber.fromMrzOptionalData('1234567895<<<<<'),
        isNull,
      );
      expect(
        NationalIdentityNumber.fromMrzOptionalData('123456789501<<<'),
        isNull,
      );
    });

    test('rakam dışı karakter numarayı geçersiz kılıyor', () {
      // `O` ile `0` karışan bir OCR okuması burada değil kontrol hanesinde
      // elenir; ama çipten gelen alanda harf varsa bu bir TCKN değildir.
      expect(
        NationalIdentityNumber.fromMrzOptionalData('1234567895O<<<<'),
        isNull,
      );
    });
  });

  group('NationalIdentityNumber.isValid', () {
    test('tam on bir rakam', () {
      expect(NationalIdentityNumber.isValid('12345678950'), isTrue);
      expect(NationalIdentityNumber.isValid('1234567895'), isFalse);
      expect(NationalIdentityNumber.isValid('123456789501'), isFalse);
      expect(NationalIdentityNumber.isValid('1234567895A'), isFalse);
    });

    test('uzunluk sabiti desenle aynı', () {
      // `LengthLimitingTextInputFormatter` bu sabiti kullanıyor; desen
      // değişip sabit kalırsa kullanıcı hiç gönderemeyeceği bir numara
      // yazabilirdi.
      expect(NationalIdentityNumber.length, 11);
      expect(
        NationalIdentityNumber.isValid('1' * NationalIdentityNumber.length),
        isTrue,
      );
    });
  });
}
