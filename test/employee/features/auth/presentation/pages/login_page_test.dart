import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/login_page.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/keyboard.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: const LoginPage(),
      ),
    );
    // Yasal alt satır sözleşmeleri sunucudan istiyor; test istemcisi bunu
    // hemen reddediyor, istek kapansın ki askıda zamanlayıcı kalmasın.
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    group('${brightness.name} tema', () {
      testWidgets('klavye açıkken GİRİŞ YAP kaydırılarak klavyenin üstüne '
          'gelir ve tıklanır', (tester) async {
        await pumpPage(tester, brightness);
        await showKeyboard(tester);

        await expectAboveKeyboard(
          tester,
          find.byKey(const ValueKey('login-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('login-submit')));
        await tester.pump();
      });

      testWidgets('boş alana dokununca odak düşer', (tester) async {
        await pumpPage(tester, brightness);

        await expectTapOutsideDropsFocus(
          tester,
          find.byKey(const ValueKey('login-email')),
        );
      });
    });
  }
}
