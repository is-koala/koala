import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:koala/main.dart' as app;
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/router/router_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const workerEmail = String.fromEnvironment('QA_WORKER_EMAIL');
  const employerEmail = String.fromEnvironment('QA_EMPLOYER_EMAIL');
  const accountPassword = String.fromEnvironment('QA_ACCOUNT_PASSWORD');
  const finalRole = String.fromEnvironment(
    'QA_FINAL_ROLE',
    defaultValue: 'employer',
  );

  testWidgets('canlı API iki QA hesabını doğru uygulamaya yönlendirir', (
    tester,
  ) async {
    if (workerEmail.isEmpty ||
        employerEmail.isEmpty ||
        accountPassword.isEmpty) {
      throw StateError(
        'Canlı test için QA_WORKER_EMAIL, QA_EMPLOYER_EMAIL ve '
        'QA_ACCOUNT_PASSWORD zorunludur.',
      );
    }

    await SessionManager().end();
    await SessionManager().markOnboardingSeen();
    app.main();
    await tester.pumpAndSettle();

    await _login(
      tester,
      email: workerEmail,
      password: accountPassword,
      expectedPath: '/explore',
    );

    await SessionManager().end();
    RouterManager.router.go('/auth/login');
    await tester.pumpAndSettle();

    await _login(
      tester,
      email: employerEmail,
      password: accountPassword,
      expectedPath: '/business/home',
    );

    if (finalRole == 'worker') {
      await SessionManager().end();
      RouterManager.router.go('/auth/login');
      await tester.pumpAndSettle();
      await _login(
        tester,
        email: workerEmail,
        password: accountPassword,
        expectedPath: '/explore',
      );
    }
  });
}

Future<void> _login(
  WidgetTester tester, {
  required String email,
  required String password,
  required String expectedPath,
}) async {
  RouterManager.router.go('/auth/login');
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const ValueKey('login-email')), email);
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    password,
  );
  await tester.tap(find.byKey(const ValueKey('login-submit')));

  await _pumpUntil(
    tester,
    () =>
        RouterManager.router.routeInformationProvider.value.uri.path ==
        expectedPath,
  );
  expect(
    RouterManager.router.routeInformationProvider.value.uri.path,
    expectedPath,
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
