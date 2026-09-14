import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

import '../../support/keyboard.dart';

void main() {
  /// Alanlar + gövde içinde CTA taşıyan bir sayfa; [resizes] `Scaffold`'un
  /// klavyeye göre küçülüp küçülmediğini seçiyor.
  Future<void> pumpForm(
    WidgetTester tester, {
    required bool resizes,
    Brightness brightness = Brightness.light,
    Widget? bottomBar,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: Scaffold(
          resizeToAvoidBottomInset: resizes,
          appBar: AppBar(title: const Text('Form')),
          bottomNavigationBar: bottomBar,
          body: FormPageBody(
            padding: AppPadding.primaryAll,
            child: Column(
              children: [
                const MyTextfield(
                  key: ValueKey('field-1'),
                  labelText: 'Birinci',
                ),
                const SizedBox(height: 320),
                const MyTextfield(
                  key: ValueKey('field-2'),
                  labelText: 'İkinci',
                ),
                const SizedBox(height: 16),
                MyButton(
                  key: const ValueKey('cta'),
                  onPressed: () {},
                  title: 'KAYDET',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    group('${brightness.name} tema', () {
      testWidgets('küçülen Scaffold: klavye açıkken CTA kaydırılarak '
          'klavyenin üstüne gelir', (tester) async {
        await pumpForm(tester, resizes: true, brightness: brightness);
        await showKeyboard(tester);

        await expectAboveKeyboard(tester, find.byKey(const ValueKey('cta')));
        await tester.tap(find.byKey(const ValueKey('cta')));
      });

      testWidgets('küçülmeyen Scaffold: alt pay klavye kadar büyür ve CTA '
          'yine kaydırılarak erişilir', (tester) async {
        await pumpForm(tester, resizes: false, brightness: brightness);
        await showKeyboard(tester);

        final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scroll.padding!.resolve(TextDirection.ltr).bottom,
          AppPadding.primaryAll.bottom + keyboardHeight,
        );

        await expectAboveKeyboard(tester, find.byKey(const ValueKey('cta')));
        await tester.tap(find.byKey(const ValueKey('cta')));
      });

      testWidgets('boş alana dokununca odak düşer', (tester) async {
        await pumpForm(tester, resizes: true, brightness: brightness);

        await expectTapOutsideDropsFocus(
          tester,
          find.byKey(const ValueKey('field-1')),
        );
      });
    });
  }

  testWidgets('küçülen Scaffold gövdeye klavye payı vermez; pay ikiye '
      'katlanmaz', (tester) async {
    await pumpForm(tester, resizes: true);
    await showKeyboard(tester);

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(
      scroll.padding!.resolve(TextDirection.ltr).bottom,
      AppPadding.primaryAll.bottom,
    );
  });

  testWidgets('gövde sürüklenince klavye kapanır', (tester) async {
    await pumpForm(tester, resizes: true);

    await tester.tap(find.byKey(const ValueKey('field-1')));
    await tester.pumpAndSettle();
    expect(anyFieldFocused(tester), isTrue);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(anyFieldFocused(tester), isFalse);
  });

  testWidgets('ButtonNavbar klavyenin üstüne çıkar ve gövde onun üstünde '
      'biter', (tester) async {
    await pumpForm(
      tester,
      resizes: true,
      bottomBar: ButtonNavbar(
        key: const ValueKey('bar'),
        onPressed: () {},
        title: 'Gönder',
      ),
    );
    await showKeyboard(tester);

    await expectAboveKeyboard(tester, findBottomBarButton());
    await tester.tap(find.text('Gönder'));

    final bodyBottom = tester.getRect(find.byType(FormPageBody)).bottom;
    final barTop = tester.getRect(find.byKey(const ValueKey('bar'))).top;
    expect(bodyBottom, lessThanOrEqualTo(barTop));
  });
}
