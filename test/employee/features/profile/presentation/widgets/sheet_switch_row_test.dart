import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/presentation/widgets/sheet_switch_row.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';

import '../../../../../support/pump.dart';

Future<void> pumpInSheet(
  WidgetTester tester, {
  required bool value,
  required ValueChanged<bool> onChanged,
  Brightness brightness = Brightness.light,
}) {
  return pumpInApp(
    tester,
    AppBottomSheet(
      title: 'Eğitim Ekle',
      child: SheetSwitchRow(
        title: 'Hâlâ okuyorum',
        value: value,
        onChanged: onChanged,
      ),
    ),
    brightness: brightness,
  );
}

void main() {
  // `SwitchListTile` içeride bir `ListTile` kuruyor ve `AppBottomSheet`'in
  // renkli kabuğu araya girdiği için Flutter "background color or ink
  // splashes may be invisible" assert'ini düşürüyor — form hiç açılmıyor.
  // Bu test o gerilemeyi tutuyor.
  testWidgets('sheet içinde ListTile kurmuyor', (tester) async {
    await pumpInSheet(tester, value: false, onChanged: (_) {});

    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Hâlâ okuyorum'), findsOneWidget);
  });

  testWidgets('anahtara dokunmak değeri çeviriyor', (tester) async {
    bool? changed;
    await pumpInSheet(tester, value: false, onChanged: (v) => changed = v);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
  });

  // `SwitchListTile`'ın kaybedilen tek davranışı etikete dokunmaktı;
  // yerine konan satır bunu koruyor.
  testWidgets('etikete dokunmak da değeri çeviriyor', (tester) async {
    bool? changed;
    await pumpInSheet(tester, value: true, onChanged: (v) => changed = v);

    await tester.tap(find.text('Hâlâ okuyorum'));
    await tester.pumpAndSettle();

    expect(changed, isFalse);
  });

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpInSheet(
      tester,
      value: false,
      onChanged: (_) {},
      brightness: Brightness.dark,
    );

    expect(tester.takeException(), isNull);
  });
}
