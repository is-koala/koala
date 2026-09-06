import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_chip_card.dart';

import '../../../../../support/pump.dart';

IdentityChipResult _result({required bool withChipProof}) {
  return IdentityChipResult(
    evidence: ChipEvidence(
      sod: 'c29k',
      dg1: 'ZGcx',
      dg15: withChipProof ? 'ZGcxNQ==' : null,
      challenge: withChipProof ? 'Y2hhbGxlbmdl' : null,
      activeAuthenticationSignature: withChipProof ? 'c2ln' : null,
    ),
    key: MrzKey.manual(
      documentNumber: 'A01B23456',
      birthDate: DateTime(1998, 4, 7),
      expiryDate: DateTime(2030, 1, 1),
    ),
  );
}

void main() {
  group('IdentityChipCard okumadan önce', () {
    testWidgets('okumaya davet ediyor ama zorunlu göstermiyor', (tester) async {
      // Çip bir kapı değil: okunmadan da doğrulama tamamlanıyor ve metnin
      // bunu söylemesi gerekiyor.
      await pumpInApp(tester, IdentityChipCard(result: null, onRead: () {}));

      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      expect(find.textContaining('elle de'), findsOneWidget);
    });

    testWidgets('okut düğmesi geri çağırıyı tetikliyor', (tester) async {
      var opened = 0;
      await pumpInApp(
        tester,
        IdentityChipCard(result: null, onRead: () => opened++),
      );

      await tester.tap(find.text('Kartı Okut'));
      await tester.pump();

      expect(opened, 1);
    });
  });

  group('IdentityChipCard okumadan sonra', () {
    testWidgets('çip kanıtlandığında bunu söylüyor', (tester) async {
      await pumpInApp(
        tester,
        IdentityChipCard(result: _result(withChipProof: true), onRead: () {}),
      );

      expect(find.text('Kimlik kartı okundu'), findsOneWidget);
      expect(find.textContaining('çipi doğrulandı'), findsOneWidget);
    });

    testWidgets('DG15 yokken kanıtlandı demiyor ama yolu kapatmıyor', (
      tester,
    ) async {
      // Canlı çip doğrulaması yapılamadı; yapılmış gibi göstermek
      // kullanıcıya olmayan bir güvence vermek olurdu. Akış yine de
      // tamamlanabiliyor ve metin bunu söylüyor.
      await pumpInApp(
        tester,
        IdentityChipCard(result: _result(withChipProof: false), onRead: () {}),
      );

      expect(find.textContaining('çipi doğrulandı'), findsNothing);
      expect(find.textContaining('desteklemiyor'), findsOneWidget);
      expect(find.textContaining('tamamlanabilir'), findsOneWidget);
    });
  });

  group('IdentityChipCard iki temada da çiziliyor', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada hata vermiyor', (tester) async {
        await pumpInApp(
          tester,
          IdentityChipCard(result: null, onRead: () {}),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);

        await pumpInApp(
          tester,
          IdentityChipCard(result: _result(withChipProof: true), onRead: () {}),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
