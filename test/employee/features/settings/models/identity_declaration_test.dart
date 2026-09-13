import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/chip_holder.dart';
import 'package:koala/employee/features/settings/models/identity_declaration.dart';

import '../../../../support/chip_fixtures.dart';

/// Kabul maddesi: **kanıt varken uyuşmaz beyan üretilemez.**
///
/// Bunu bir bayrakla değil tiple sağlıyoruz: [ChipDeclaration]'ın tek
/// girdisi çip sonucu, beş alanı da o sonucun kanıtından türeyen getter'lar.
/// Alan yazacak bir kurucu parametresi ya da `copyWith` **yok** — yani
/// kanıtla çelişen bir beyanı derleyecek kod da yok. Buradaki testler o
/// türetmenin doğru kanıta baktığını ölçüyor.
void main() {
  group('ChipDeclaration', () {
    test('beş alan da kanıtın kendisinden türüyor', () {
      final chip = buildChipResult(
        dg1: encodeDg1(line3: 'KAYA<<CAGRI<<<<<<<<<<<<<<<<<<<'),
        dg11: encodeDg11(nameOfHolder: 'KAYA<<ÇAĞRI'),
      );
      final expected = ChipHolder.fromEvidence(chip.evidence)!;

      final declaration = ChipDeclaration(chip);

      expect(declaration.firstName, expected.firstName);
      expect(declaration.lastName, expected.lastName);
      expect(declaration.tcIdentityNumber, expected.nationalIdentityNumber);
      expect(declaration.tcDocumentNumber, expected.documentNumber);
      expect(declaration.birthDate, expected.birthDate);
    });

    test('kanıt olduğu gibi, aynı nesne olarak taşınıyor', () {
      // Ekranda gösterilen alanlarla gönderilen base64 aynı kaynaktan
      // çıkıyor; kanıtın kopyalanıp değiştirilebileceği bir ara adım yok.
      final chip = buildChipResult(withChipProof: true);

      expect(identical(ChipDeclaration(chip).evidence, chip.evidence), isTrue);
    });

    test('çipe bağlı beyan her zaman tam', () {
      // Çipten gelen alanlar boş olamaz; kart bunları taşımasaydı sonuç hiç
      // üretilmezdi.
      expect(ChipDeclaration(buildChipResult()).isComplete, isTrue);
    });

    test('farklı kanıt farklı beyan üretiyor', () {
      // Beyanın kanıta değil bir ara saklamaya baktığı bir gerileme burada
      // yakalanır: aynı kodla iki kanıt, iki farklı ekran.
      final ada = ChipDeclaration(buildChipResult());
      final cagri = ChipDeclaration(
        buildChipResult(dg11: encodeDg11(nameOfHolder: 'KAYA<<ÇAĞRI')),
      );

      expect(ada.firstName, 'ADA');
      expect(cagri.firstName, 'ÇAĞRI');
    });
  });

  group('ManualDeclaration', () {
    test('kanıt taşımıyor', () {
      const declaration = ManualDeclaration(
        firstName: 'Ada',
        lastName: 'Kaya',
        tcIdentityNumber: '12345678950',
        tcDocumentNumber: 'A01B23456',
      );

      expect(declaration.evidence, isNull);
    });

    test('bütün alanlar doluysa ve TCKN on bir haneyse tam', () {
      final declaration = ManualDeclaration(
        firstName: 'Ada',
        lastName: 'Kaya',
        tcIdentityNumber: '12345678950',
        tcDocumentNumber: 'A01B23456',
        birthDate: DateTime(1998, 4, 7),
      );

      expect(declaration.isComplete, isTrue);
    });

    test('eksik alan ya da kısa TCKN beyanı eksik bırakıyor', () {
      ManualDeclaration build({
        String firstName = 'Ada',
        String lastName = 'Kaya',
        String tcIdentityNumber = '12345678950',
        String tcDocumentNumber = 'A01B23456',
        bool withBirthDate = true,
      }) {
        return ManualDeclaration(
          firstName: firstName,
          lastName: lastName,
          tcIdentityNumber: tcIdentityNumber,
          tcDocumentNumber: tcDocumentNumber,
          birthDate: withBirthDate ? DateTime(1998, 4, 7) : null,
        );
      }

      expect(build().isComplete, isTrue);
      expect(build(firstName: '').isComplete, isFalse);
      expect(build(lastName: '').isComplete, isFalse);
      expect(build(tcIdentityNumber: '1234567895').isComplete, isFalse);
      // Kural `NationalIdentityNumber` ile ortak: on bir karakter yetmiyor,
      // on bir **rakam** gerekiyor.
      expect(build(tcIdentityNumber: '1234567895A').isComplete, isFalse);
      expect(build(tcDocumentNumber: '').isComplete, isFalse);
      expect(build(withBirthDate: false).isComplete, isFalse);
    });
  });
}
