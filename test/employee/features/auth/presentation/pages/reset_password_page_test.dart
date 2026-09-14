import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/reset_password_page.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/keyboard.dart';

void main() {
  testWidgets('yeni şifre reset tokenıyla backend\'e gönderilir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: ResetPasswordPage(
          token: 'reset-123',
          authService: AuthService.withClient(api.client),
          onCompleted: () => completed = true,
        ),
      ),
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Yeni Şifre',
      ),
      'KoalaDemo!2026',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Yeni Şifre Tekrar',
      ),
      'KoalaDemo!2026',
    );
    await tester.tap(find.text('ŞİFREYİ GÜNCELLE'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(api.requests.single.path, '/auth/reset-password');
    expect(api.requests.single.data, {
      'resetToken': 'reset-123',
      'newPassword': 'KoalaDemo!2026',
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} tema: klavye açıkken ŞİFREYİ GÜNCELLE klavyenin '
      'üstünde kalır, boş alana dokununca odak düşer',
      (tester) async {
        final api = FakeApi(
          handler: (_) =>
              const FakeApiResponse(statusCode: 200, body: {'success': true}),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark ? darkTheme : lightTheme,
            home: ResetPasswordPage(
              token: 'reset-123',
              authService: AuthService.withClient(api.client),
            ),
          ),
        );
        await showKeyboard(tester);

        await expectAboveKeyboard(
          tester,
          find.byKey(const ValueKey('reset-password-submit')),
        );
        await expectTapOutsideDropsFocus(tester, find.byType(TextField).first);
      },
    );
  }
}
