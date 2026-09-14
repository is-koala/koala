import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/register_page.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/keyboard.dart';
import '../../../../../support/finders.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: const RegisterPage(isBusiness: false),
      ),
    );
    // Yasal alt satır sözleşmeleri sunucudan istiyor; test istemcisi bunu
    // hemen reddediyor, istek kapansın ki askıda zamanlayıcı kalmasın.
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    group('${brightness.name} tema', () {
      testWidgets('klavye açıkken KAYIT OL kaydırılarak klavyenin üstüne '
          'gelir ve tıklanır', (tester) async {
        await pumpPage(tester, brightness);
        await showKeyboard(tester);

        await expectAboveKeyboard(tester, find.text('KAYIT OL'));
        await tester.tap(find.text('KAYIT OL'));
        await tester.pump();
      });

      testWidgets('boş alana dokununca odak düşer', (tester) async {
        await pumpPage(tester, brightness);

        await expectTapOutsideDropsFocus(tester, findFieldLabelled('E-posta'));
      });
    });
  }
}
