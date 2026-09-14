import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/widgets/keyboard_done_bar.dart';
import 'package:koala/product/widgets/my_textfield.dart';

import '../../support/keyboard.dart';
import '../../support/pump.dart';

void main() {
  group('KeyboardDoneBar.needsFor', () {
    test('geri dönüş tuşu olmayan iOS klavyeleri için doğru', () {
      expect(KeyboardDoneBar.needsFor(TextInputType.number), isTrue);
      expect(
        KeyboardDoneBar.needsFor(
          const TextInputType.numberWithOptions(decimal: true),
        ),
        isTrue,
      );
      expect(KeyboardDoneBar.needsFor(TextInputType.phone), isTrue);
    });

    test('tuşu olan klavyeler için yanlış', () {
      expect(KeyboardDoneBar.needsFor(TextInputType.text), isFalse);
      expect(KeyboardDoneBar.needsFor(TextInputType.emailAddress), isFalse);
      expect(KeyboardDoneBar.needsFor(TextInputType.multiline), isFalse);
      expect(
        KeyboardDoneBar.needsFor(
          const TextInputType.numberWithOptions(signed: true),
        ),
        isFalse,
      );
    });
  });

  Future<void> pumpFields(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) {
    return pumpInApp(
      tester,
      const Column(
        children: [
          MyTextfield(
            key: ValueKey('phone'),
            labelText: 'Telefon',
            keyboardType: TextInputType.phone,
          ),
          MyTextfield(key: ValueKey('name'), labelText: 'Ad'),
        ],
      ),
      brightness: brightness,
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} tema: iOS sayısal alan odaklanınca klavyenin '
      'üstünde Bitti çıkar, dokununca odak düşer',
      (tester) async {
        await pumpFields(tester, brightness: brightness);
        await showKeyboard(tester);

        await tester.tap(find.byKey(const ValueKey('phone')));
        await tester.pumpAndSettle();

        final done = find.text(KeyboardDoneBar.label);
        expect(done, findsOneWidget);
        final bar = tester.getRect(find.byType(KeyboardDoneBar));
        expect(bar.bottom, screenHeightOf(tester) - keyboardHeight);

        await tester.tap(done);
        await tester.pumpAndSettle();

        expect(anyFieldFocused(tester), isFalse);
        expect(find.byType(KeyboardDoneBar), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'iOS metin alanında şerit çizilmez; odak sayısaldan metne geçince kalkar',
    (tester) async {
      await pumpFields(tester);
      await showKeyboard(tester);

      await tester.tap(find.byKey(const ValueKey('name')));
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardDoneBar), findsNothing);

      await tester.tap(find.byKey(const ValueKey('phone')));
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardDoneBar), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('name')));
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardDoneBar), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('klavye henüz yükselmediyse şerit ekranın dibine yapışmaz', (
    tester,
  ) async {
    await pumpFields(tester);

    await tester.tap(find.byKey(const ValueKey('phone')));
    await tester.pumpAndSettle();
    expect(find.byType(KeyboardDoneBar), findsNothing);

    await showKeyboard(tester);
    expect(find.byType(KeyboardDoneBar), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android klavyesi kendi Bitti tuşunu taşır; şerit çizilmez', (
    tester,
  ) async {
    await pumpFields(tester);
    await showKeyboard(tester);

    await tester.tap(find.byKey(const ValueKey('phone')));
    await tester.pumpAndSettle();

    expect(find.byType(KeyboardDoneBar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('alan ağaçtan kalkınca şerit de kalkar', (tester) async {
    await pumpFields(tester);
    await showKeyboard(tester);
    await tester.tap(find.byKey(const ValueKey('phone')));
    await tester.pumpAndSettle();
    expect(find.byType(KeyboardDoneBar), findsOneWidget);

    await pumpInApp(tester, const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(find.byType(KeyboardDoneBar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
