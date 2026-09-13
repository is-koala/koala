import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/presentation/widgets/locked_field.dart';

import '../../../../../support/pump.dart';

/// Çipten türeyen beş alanın çizildiği satır: değer doğrudan geçiliyor,
/// yazılabilir bir şey yok ve ekran okuyucu etiketle değeri tek parça duyuyor.
void main() {
  for (final brightness in Brightness.values) {
    group('LockedField ${brightness.name} temada', () {
      testWidgets('etiketi ve değeri çiziyor', (tester) async {
        await pumpInApp(
          tester,
          const LockedField(label: 'Ad', value: 'ÇAĞRI'),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Ad'), findsOneWidget);
        expect(find.text('ÇAĞRI'), findsOneWidget);
      });

      testWidgets('yazılabilir ya da odaklanabilir bir alan taşımıyor', (
        tester,
      ) async {
        // Kilidin anlamı bu: metin alanı olsaydı bir `TextEditingController`
        // ekrandakini beyandan bağımsız değiştirebilirdi.
        await pumpInApp(
          tester,
          const LockedField(label: 'TC Kimlik No', value: '12345678950'),
          brightness: brightness,
        );

        final inside = find.byType(LockedField);
        expect(find.byType(EditableText), findsNothing);
        expect(find.byType(TextField), findsNothing);
        // Uygulama kabuğunun kendi odak düğümleri var; satırın içinde olmamalı.
        expect(
          find.descendant(of: inside, matching: find.byType(Focus)),
          findsNothing,
        );
      });

      testWidgets('ekran okuyucuya etiket ve değeri tek düğüm olarak veriyor', (
        tester,
      ) async {
        // "Ad" ve "ÇAĞRI" iki ayrı düğüm olsaydı okuyucu ikisini bağımsız,
        // sırası belirsiz iki öğe gibi okurdu; birlikte "Ad: ÇAĞRI" olmalı
        // ve salt okunur olduğu söylenmeli.
        final semantics = tester.ensureSemantics();
        await pumpInApp(
          tester,
          const LockedField(label: 'Ad', value: 'ÇAĞRI'),
          brightness: brightness,
        );

        expect(
          tester.getSemantics(find.byType(LockedField)),
          matchesSemantics(
            label: 'Ad',
            value: 'ÇAĞRI',
            isReadOnly: true,
            children: const [],
          ),
        );
        semantics.dispose();
      });
    });
  }
}
