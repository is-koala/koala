import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/business/features/home/presentation/widgets/b_option_sheet.dart';

import '../../../../../support/pump.dart';

const _options = [
  ReferenceLocation(id: '1', name: 'Ankara'),
  ReferenceLocation(id: '2', name: 'İstanbul'),
];

/// Sheet'i açan tek butonluk sayfa.
Widget sheetOpener({
  required ValueChanged<ReferenceLocation?> onPicked,
  ReferenceLocation? selected,
}) {
  return Builder(
    builder: (context) => TextButton(
      onPressed: () async {
        onPicked(
          await BOptionSheet.show<ReferenceLocation>(
            context,
            title: 'İl',
            options: _options,
            selected: selected,
            labelOf: (option) => option.name,
          ),
        );
      },
      child: const Text('aç'),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    testWidgets('$themeName temada seçenekler hatasız çiziliyor', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        sheetOpener(onPicked: (_) {}),
        brightness: brightness,
      );

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      // `ListTile` kullanılırsa Flutter "background color or ink splashes may
      // be invisible" hatasını bildiriyor ve test bu yüzden düşüyor:
      // `AppBottomSheet`'in renkli kabuğu araya giriyor. Bu test o gerilemeyi
      // tutuyor.
      expect(tester.takeException(), isNull);
      expect(find.text('Ankara'), findsOneWidget);
      expect(find.text('İstanbul'), findsOneWidget);
    });
  }

  testWidgets('seçilen değer geri döndürülüyor', (tester) async {
    ReferenceLocation? picked;

    await pumpInApp(tester, sheetOpener(onPicked: (value) => picked = value));

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İstanbul'));
    await tester.pumpAndSettle();

    expect(picked?.id, '2');
  });

  testWidgets('vazgeçilince null dönüyor', (tester) async {
    var called = false;
    ReferenceLocation? picked;

    await pumpInApp(
      tester,
      sheetOpener(
        onPicked: (value) {
          called = true;
          picked = value;
        },
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(picked, isNull);
  });

  testWidgets('seçili satır tik ile işaretleniyor', (tester) async {
    await pumpInApp(
      tester,
      sheetOpener(onPicked: (_) {}, selected: _options.first),
    );

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
