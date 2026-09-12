import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/chip_holder.dart';

import '../../../../support/chip_fixtures.dart';

/// Kart sahibinin beş alanı **yalnızca** çipin veri gruplarından türüyor.
///
/// Sunucu aynı kuralla okuyor: TCKN, doğum tarihi ve belge numarası DG1'in
/// MRZ'sinden; ad ve soyad varsa DG11'den, yoksa DG1'in ASCII'ye katlanmış
/// hâlinden. Buradaki ayrıştırıcı sunucununkinden sapsa ekrandaki beyan
/// sunucunun kabul ettiğinden ayrışırdı.
void main() {
  group('ChipHolder.fromEvidence', () {
    test('DG1 tek başına beş alanı ASCII adla veriyor', () {
      final holder = ChipHolder.fromEvidence(buildChipEvidence());

      expect(holder, isNotNull);
      expect(holder!.firstName, 'ADA');
      expect(holder.lastName, 'KAYA');
      expect(holder.nationalIdentityNumber, '12345678950');
      expect(holder.birthDate, DateTime(1998, 4, 7));
      expect(holder.documentNumber, 'A01B23456');
    });

    test('DG11 varsa ad ve soyad ulusal karakterlerle oradan geliyor', () {
      // MRZ **ÇAĞRI**'yı **CAGRI** yazıyor; DG11 SOD'da özetlendiği için daha
      // az güvenilir değil, yalnızca doğru. Geri kalan üç alan DG1'de kalıyor.
      final evidence = buildChipEvidence(
        dg1: encodeDg1(line3: 'KAYA<<CAGRI<<<<<<<<<<<<<<<<<<<'),
        dg11: encodeDg11(nameOfHolder: 'KAYA<<ÇAĞRI'),
      );

      final holder = ChipHolder.fromEvidence(evidence)!;

      expect(holder.firstName, 'ÇAĞRI');
      expect(holder.lastName, 'KAYA');
      expect(holder.nationalIdentityNumber, '12345678950');
      expect(holder.documentNumber, 'A01B23456');
    });

    test('birden çok ad `<` ayracından boşluğa çevriliyor', () {
      final evidence = buildChipEvidence(
        dg1: encodeDg1(line3: 'KAYA<<ALI<VELI<<<<<<<<<<<<<<<<'),
        dg11: encodeDg11(nameOfHolder: 'KAYA<<ALİ<VELİ'),
      );

      expect(ChipHolder.fromEvidence(evidence)!.firstName, 'ALİ VELİ');
    });

    test('DG11 yokken ASCII ad tahminle açılmıyor', () {
      // `CAGRI`'nın `ÇAĞRI` mı `CAGRI` mı olduğu DG11 olmadan bilinemez;
      // uydurmak, sunucunun DG11'i esas aldığı yerde yanlış ad göstermek
      // olurdu.
      final evidence = buildChipEvidence(
        dg1: encodeDg1(line3: 'KAYA<<CAGRI<<<<<<<<<<<<<<<<<<<'),
      );

      expect(ChipHolder.fromEvidence(evidence)!.firstName, 'CAGRI');
    });

    test('DG11 ad alanı bozuksa DG1 adına düşülüyor', () {
      // Soyad ile ad arasında `<<` yoksa DG11 ad taşımıyor demektir; sunucu
      // da bu durumda isteğin adını esas alıyor.
      final evidence = buildChipEvidence(
        dg11: encodeDg11(nameOfHolder: 'KAYAADA'),
      );

      final holder = ChipHolder.fromEvidence(evidence)!;

      expect(holder.firstName, 'ADA');
      expect(holder.lastName, 'KAYA');
    });

    test('DG11 çözümlenemiyorsa DG1 adıyla devam ediliyor', () {
      // DG11 gönderilmeye devam ediyor (SOD onu da özetliyor); yalnız adın
      // kaynağı DG1 kalıyor.
      final holder = ChipHolder.fromEvidence(
        buildChipEvidence(dg11: 'ZGcxMQ=='),
      );

      expect(holder, isNotNull);
      expect(holder!.firstName, 'ADA');
    });

    test('DG11 kişisel numarası TCKN olarak kullanılmıyor', () {
      // Sunucu TCKN'yi DG1'in isteğe bağlı alanından okuyor; DG11'deki
      // numara farklıysa ekrandaki beyan sunucunun reddedeceği bir değer
      // gösterirdi.
      final evidence = buildChipEvidence(
        dg11: encodeDg11(nameOfHolder: 'KAYA<<ADA', personalNumber: '99'),
      );

      expect(
        ChipHolder.fromEvidence(evidence)!.nationalIdentityNumber,
        '12345678950',
      );
    });

    test('DG1 TCKN taşımıyorsa sonuç üretilmiyor', () {
      // Sunucu aynı durumda `MRZ_UNREADABLE` ile reddediyor; kullanıcıyı
      // reddedilecek bir gidiş dönüşe sokmak yerine burada duruyoruz.
      final evidence = buildChipEvidence(
        dg1: encodeDg1(
          // İsteğe bağlı alan boş; bileşik kontrol hanesi yeniden hesaplı.
          line1: 'I<TURA01B234566<<<<<<<<<<<<<<<',
          line2: '9804072F3001019TUR<<<<<<<<<<<6',
        ),
      );

      expect(ChipHolder.fromEvidence(evidence), isNull);
    });

    test('DG1 çözümlenemiyorsa sonuç üretilmiyor', () {
      expect(ChipHolder.fromEvidence(buildChipEvidence(dg1: 'ZGcx')), isNull);
    });

    test('DG1 kontrol hanesi tutmuyorsa sonuç üretilmiyor', () {
      // Bozuk okunmuş bir MRZ'den beyan üretmek, kanıtla çelişen bir ekran
      // göstermek olurdu.
      final evidence = buildChipEvidence(
        dg1: encodeDg1(line1: 'I<TURA01B23457612345678950<<<<'),
      );

      expect(ChipHolder.fromEvidence(evidence), isNull);
    });
  });
}
