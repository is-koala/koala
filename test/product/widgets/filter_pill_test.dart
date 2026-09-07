import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/widgets/filter_pill.dart';

import '../../support/finders.dart';
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

  // Açık ve kapalı çip **aynı dokunuşla** sınanıyor. Tek başına duran negatif
  // bir iddia ("kapalıyken tetiklenmiyor") dokunuş hiç inmese de geçerdi;
  // ikizi geçtiği için dokunuşun çipe indiği de sabitlenmiş oluyor.
  for (final enabled in [true, false]) {
    final stateName = enabled ? 'açık' : 'kapalı';

    testWidgets(
      '$stateName çip dokunmayı ${enabled ? "iletiyor" : "yutuyor"}',
      (tester) async {
        var tapped = false;

        await pumpInApp(
          tester,
          FilterPill(
            label: 'Mesafe',
            isSelected: false,
            enabled: enabled,
            onTap: () => tapped = true,
          ),
        );

        await tester.tap(find.text('Mesafe'), warnIfMissed: false);
        expect(tapped, enabled);
      },
    );
  }

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

    expect(findAppIcon(AppIcons.close), findsOneWidget);
    await tester.tap(findAppIcon(AppIcons.close));
    expect(removed, isTrue);
  });

  testWidgets('kaldırma verilmeyen çipte çarpı yok', (tester) async {
    await pumpInApp(
      tester,
      const FilterPill(label: 'Ankara', isSelected: true),
    );

    expect(findAppIcon(AppIcons.close), findsNothing);
  });
}
