import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/widgets/password_field.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('varsayılanı gizli açılır', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpInApp(
      tester,
      PasswordField(
        labelText: 'Şifre',
        controller: controller,
        onToggle: () {},
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
  });

  testWidgets('göz düğmesi gizliliği çevirir', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var hidden = true;

    await pumpInApp(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          return PasswordField(
            labelText: 'Şifre',
            controller: controller,
            isHidden: hidden,
            onToggle: () => setState(() => hidden = !hidden),
          );
        },
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse);
  });
}
