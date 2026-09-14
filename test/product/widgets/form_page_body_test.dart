import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/keyboard_done_bar.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

import '../../support/keyboard.dart';

void main() {
  /// Alanlar + CTA taşıyan bir sayfa. [resizes] `Scaffold`'un klavyeye göre
  /// küçülüp küçülmediğini, [numeric] ikinci alanın iOS'ta "Bitti" şeridi
  /// alan bir tuş takımı açıp açmadığını, [bottomBar] CTA'nın gövdede mi
  /// `bottomNavigationBar`'da mı durduğunu seçiyor.
  Future<void> pumpForm(
    WidgetTester tester, {
    required bool resizes,
    Brightness brightness = Brightness.light,
    bool numeric = false,
    bool bottomBar = false,
    VoidCallback? onCta,
  }) {
    final cta = MyButton(
      key: const ValueKey('cta'),
      onPressed: onCta ?? () {},
      title: 'KAYDET',
    );
    return tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: Scaffold(
          resizeToAvoidBottomInset: resizes,
          appBar: AppBar(title: const Text('Form')),
          bottomNavigationBar: bottomBar
              ? ButtonNavbar(
                  key: const ValueKey('bar'),
                  onPressed: onCta ?? () {},
                  title: 'Gönder',
                )
              : null,
          body: FormPageBody(
            padding: AppPadding.primaryAll,
            child: Column(
              children: [
                const MyTextfield(
                  key: ValueKey('field-1'),
                  labelText: 'Birinci',
                ),
                const SizedBox(height: 320),
                MyTextfield(
                  key: const ValueKey('field-2'),
                  labelText: 'İkinci',
                  keyboardType: numeric
                      ? TextInputType.phone
                      : TextInputType.text,
                ),
                const SizedBox(height: 16),
                if (!bottomBar) cta,
              ],
            ),
          ),
        ),
      ),
    );
  }

  final cta = find.byKey(const ValueKey('cta'));
  final field1 = find.byKey(const ValueKey('field-1'));
  final field2 = find.byKey(const ValueKey('field-2'));

  for (final brightness in Brightness.values) {
    group('${brightness.name} tema', () {
      testWidgets('küçülen Scaffold: klavye açıkken CTA kaydırılarak '
          'klavyenin üstüne gelir', (tester) async {
        var tapped = false;
        await pumpForm(
          tester,
          resizes: true,
          brightness: brightness,
          onCta: () => tapped = true,
        );
        await showKeyboard(tester);

        await expectAboveKeyboard(tester, cta);
        await tester.tap(cta);
        expect(tapped, isTrue);
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

        await expectAboveKeyboard(tester, cta);
        await tester.tap(cta);
      });

      testWidgets('boş alana dokununca odak düşer', (tester) async {
        await pumpForm(tester, resizes: true, brightness: brightness);

        await expectTapOutsideDropsFocus(tester, field1);
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

    await tester.tap(field1);
    await tester.pump();
    expect(anyFieldFocused(tester), isTrue);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(anyFieldFocused(tester), isFalse);
  });

  testWidgets('ButtonNavbar klavyenin üstüne çıkar ve gövde onun üstünde '
      'biter', (tester) async {
    var tapped = false;
    await pumpForm(
      tester,
      resizes: true,
      bottomBar: true,
      onCta: () => tapped = true,
    );
    await showKeyboard(tester);

    await expectAboveKeyboard(tester, findBottomBarButton());
    await tester.tap(find.text('Gönder'));
    expect(tapped, isTrue);

    final bodyBottom = tester.getRect(find.byType(FormPageBody)).bottom;
    final barTop = tester.getRect(find.byKey(const ValueKey('bar'))).top;
    expect(bodyBottom, lessThanOrEqualTo(barTop));
  });

  /// iOS'ta "Bitti" şeridi klavyenin üstünde 44 pt daha yer kaplıyor; alt
  /// çubuk, gövde payı ve odaklı alan bunu `KeyboardInsets` üzerinden
  /// hesaba katmalı, yoksa düğmenin merkezine dokunmak şeride gidiyor.
  group('iOS Bitti şeridi', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} tema: alt çubuk ve odaklı alan şeridin üstünde '
        'kalır, düğme gönderir',
        (tester) async {
          var tapped = false;
          await pumpForm(
            tester,
            resizes: true,
            brightness: brightness,
            numeric: true,
            bottomBar: true,
            onCta: () => tapped = true,
          );
          await showKeyboard(tester);

          await expectFocusedFieldAboveKeyboard(tester, field2);
          expect(find.byType(KeyboardDoneBar), findsOneWidget);

          await expectAboveKeyboard(tester, findBottomBarButton());
          await tester.tap(find.text('Gönder'));
          expect(tapped, isTrue, reason: 'dokunuş şeride gitti');
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }

    testWidgets('gövdedeki CTA şeridin üstüne kaydırılır ve gönderir', (
      tester,
    ) async {
      var tapped = false;
      await pumpForm(
        tester,
        resizes: true,
        numeric: true,
        onCta: () => tapped = true,
      );
      await showKeyboard(tester);

      await expectFocusedFieldAboveKeyboard(tester, field2);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scroll.padding!.resolve(TextDirection.ltr).bottom,
        AppPadding.primaryAll.bottom + AppSizes.keyboardToolbar,
      );

      await expectAboveKeyboard(tester, cta);
      await tester.tap(cta);
      expect(tapped, isTrue, reason: 'dokunuş şeride gitti');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'alt çubuğu olan sayfada gövde şerit payını ikinci kez eklemez',
      (tester) async {
        await pumpForm(tester, resizes: true, numeric: true, bottomBar: true);
        await showKeyboard(tester);
        await focusField(tester, field2);
        expect(find.byType(KeyboardDoneBar), findsOneWidget);

        final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scroll.padding!.resolve(TextDirection.ltr).bottom,
          AppPadding.primaryAll.bottom,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'Bitti\'ye dokununca şerit kalkar ve çubuk klavyenin üstüne iner',
      (tester) async {
        await pumpForm(tester, resizes: true, numeric: true, bottomBar: true);
        await showKeyboard(tester);
        await focusField(tester, field2);

        final raised = tester.getRect(findBottomBarButton()).bottom;
        await tester.tap(find.text(KeyboardDoneBar.label));
        await tester.pump();

        expect(find.byType(KeyboardDoneBar), findsNothing);
        expect(anyFieldFocused(tester), isFalse);
        expect(
          tester.getRect(findBottomBarButton()).bottom,
          raised + AppSizes.keyboardToolbar,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });
}
