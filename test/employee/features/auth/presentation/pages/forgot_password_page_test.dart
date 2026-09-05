import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';

void main() {
  testWidgets('şifre yenileme e-postası gerçek auth servisiyle istenir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    var sent = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: ForgotPasswordPage(
          authService: AuthService.withClient(api.client),
          onSent: () => sent = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'calisan@example.com');
    await tester.tap(find.text('BAĞLANTI GÖNDER'));
    await tester.pumpAndSettle();

    expect(sent, isTrue);
    expect(api.requests.single.path, '/auth/forgot-password');
    expect(api.requests.single.data, {'email': 'calisan@example.com'});
  });
}
