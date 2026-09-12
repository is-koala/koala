import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_chip_card.dart';

import '../../../../../support/chip_fixtures.dart';
import '../../../../../support/pump.dart';

IdentityChipResult _result({required bool withChipProof}) =>
    buildChipResult(withChipProof: withChipProof);

void main() {
  group('IdentityChipCard okumadan önce', () {
    testWidgets('okumaya davet ediyor ama zorunlu göstermiyor', (tester) async {
      // Çip bir kapı değil: okunmadan da doğrulama tamamlanıyor ve metnin
      // bunu söylemesi gerekiyor.
      await pumpInApp(
        tester,
        IdentityChipCard(result: null, onRead: () {}, onRemove: () {}),
      );

      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      expect(find.textContaining('elle de'), findsOneWidget);
      // Kaldırılacak bir okuma yok.
      expect(find.text('Okumayı Kaldır'), findsNothing);
    });

    testWidgets('okut düğmesi geri çağırıyı tetikliyor', (tester) async {
      var opened = 0;
      await pumpInApp(
        tester,
        IdentityChipCard(result: null, onRead: () => opened++, onRemove: () {}),
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
        IdentityChipCard(
          result: _result(withChipProof: true),
          onRead: () {},
          onRemove: () {},
        ),
      );

      expect(find.text('Kimlik kartı okundu'), findsOneWidget);
      expect(find.textContaining('çipi doğrulandı'), findsOneWidget);
    });

    testWidgets('beş alanın da karttan geldiğini söylüyor', (tester) async {
      // Eskiden yalnız seri no ve doğum tarihi karttan geliyordu; artık ad,
      // soyad ve TCKN de. Kullanıcı neyin neden kilitli olduğunu buradan
      // anlıyor.
      await pumpInApp(
        tester,
        IdentityChipCard(
          result: _result(withChipProof: false),
          onRead: () {},
          onRemove: () {},
        ),
      );

      expect(find.textContaining('Ad, soyad, TC kimlik no'), findsOneWidget);
    });

    testWidgets('DG15 yokken kanıtlandı demiyor ama yolu kapatmıyor', (
      tester,
    ) async {
      // Canlı çip doğrulaması yapılamadı; yapılmış gibi göstermek
      // kullanıcıya olmayan bir güvence vermek olurdu. Akış yine de
      // tamamlanabiliyor ve metin bunu söylüyor.
      await pumpInApp(
        tester,
        IdentityChipCard(
          result: _result(withChipProof: false),
          onRead: () {},
          onRemove: () {},
        ),
      );

      expect(find.textContaining('çipi doğrulandı'), findsNothing);
      expect(find.textContaining('desteklemiyor'), findsOneWidget);
      expect(find.textContaining('tamamlanabilir'), findsOneWidget);
    });

    testWidgets('yeniden oku ve okumayı kaldır ayrı geri çağırılara gidiyor', (
      tester,
    ) async {
      // Elle düzenlemeye dönüşün tek yolu okumayı kaldırmak; yeniden okumak
      // ise kanıtı yenisiyle değiştiriyor. İkisi karışırsa kullanıcı ya
      // kanıtı istemeden kaybeder ya da kilitten çıkamaz.
      var reads = 0;
      var removals = 0;
      await pumpInApp(
        tester,
        IdentityChipCard(
          result: _result(withChipProof: true),
          onRead: () => reads++,
          onRemove: () => removals++,
        ),
      );

      await tester.tap(find.text('Yeniden Oku'));
      await tester.pump();
      expect((reads, removals), (1, 0));

      await tester.tap(find.text('Okumayı Kaldır'));
      await tester.pump();
      expect((reads, removals), (1, 1));
    });
  });

  group('IdentityChipCard iki temada da çiziliyor', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada hata vermiyor', (tester) async {
        await pumpInApp(
          tester,
          IdentityChipCard(result: null, onRead: () {}, onRemove: () {}),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);

        await pumpInApp(
          tester,
          IdentityChipCard(
            result: _result(withChipProof: true),
            onRead: () {},
            onRemove: () {},
          ),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
