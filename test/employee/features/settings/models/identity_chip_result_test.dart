import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';

import '../../../../support/chip_fixtures.dart';

void main() {
  group('IdentityChipResult.parse', () {
    test('kimlik bilgileri kanıtın baytlarından türetiliyor', () {
      // Sonuç kanıt + ondan türeyen kart sahibi; ikisini ayrı ayrı verecek
      // bir kurucu yok, yani birbirinden ayrışamıyorlar.
      final evidence = buildChipEvidence(
        dg11: encodeDg11(nameOfHolder: 'KAYA<<ÇAĞRI'),
      );

      final result = IdentityChipResult.parse(evidence);

      expect(result, isNotNull);
      expect(identical(result!.evidence, evidence), isTrue);
      expect(result.holder.firstName, 'ÇAĞRI');
      expect(result.holder.nationalIdentityNumber, '12345678950');
    });

    test('DG1 çözümlenemezse sonuç yok', () {
      // Kanıt olup kimlik bilgisi olmayan bir sonuç, formu boş kilitlemek
      // olurdu; çip ekranı bunu okuma hatası olarak gösteriyor.
      expect(IdentityChipResult.parse(buildChipEvidence(dg1: 'ZGcx')), isNull);
    });
  });
}
