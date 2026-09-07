import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/widgets/filter_pill.dart';

import '../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    testWidgets(
      '$themeName temada seçili ve seçilmemiş hâl hatasız çiziliyor',
      (tester) async {
        await pumpInApp(
          tester,
          const Wrap(
            children: [
              FilterPill(label: 'Seçili', isSelected: true),
              FilterPill(label: 'Seçilmemiş', isSelected: false),
            ],
          ),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Seçili'), findsOneWidget);
        expect(find.text('Seçilmemiş'), findsOneWidget);
      },
    );
  }

  testWidgets('dokunma geri çağırımı tetikliyor', (tester) async {
    var tapped = false;

    await pumpInApp(
      tester,
      FilterPill(
        label: 'Garsonluk',
        isSelected: false,
        onTap: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Garsonluk'));
    expect(tapped, isTrue);
  });

  testWidgets('kapalı çip dokunmayı yutuyor', (tester) async {
    var tapped = false;

    await pumpInApp(
      tester,
      FilterPill(
        label: 'Mesafe',
        isSelected: false,
        enabled: false,
        onTap: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Mesafe'), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('kaldırılabilir çip çarpı taşıyor ve tek alanı temizliyor', (
    tester,
  ) async {
    var removed = false;

    await pumpInApp(
      tester,
      FilterPill(
        label: 'Ankara',
        isSelected: true,
        onRemove: () => removed = true,
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });

  testWidgets('kaldırma verilmeyen çipte çarpı yok', (tester) async {
    await pumpInApp(
      tester,
      const FilterPill(label: 'Ankara', isSelected: true),
    );

    expect(find.byIcon(Icons.close), findsNothing);
  });
}
