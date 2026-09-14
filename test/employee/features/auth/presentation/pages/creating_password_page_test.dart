import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/creating_password_page.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';
import '../../../../../support/keyboard.dart';

/// Şifre belirleme ekranı: token ve sözleşmeler sahte sunucudan geliyor,
/// form açılıyor; klavye açıkken BİTİR kaydırılarak klavyenin üstüne
/// geliyor ve boş alana dokunmak odağı düşürüyor (is-koala/koala#190).
FakeApi _server() => FakeApi(
  handler: (request) => switch (request.path) {
    '/auth/verify-registration-token' => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'setPasswordToken': 'set-1', 'isEmployer': false},
      },
    ),
    '/legal/agreements' => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': [
          {
            'id': 'agr-1',
            'type': 'TERMS_OF_SERVICE',
            'version': '1',
            'locale': 'tr',
            'mandatory': true,
          },
        ],
      },
    ),
    _ => const FakeApiResponse(statusCode: 200, body: {'success': true}),
  },
);

Future<void> _pumpPage(WidgetTester tester, Brightness brightness) async {
  final api = _server();
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? darkTheme : lightTheme,
      home: CreatingPasswordPage(
        token: 'reg-1',
        authService: AuthService.withClient(api.client),
        legalService: LegalService.withClient(api.client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} tema', () {
      testWidgets('klavye açıkken BİTİR kaydırılarak klavyenin üstüne gelir', (
        tester,
      ) async {
        await _pumpPage(tester, brightness);
        await showKeyboard(tester);

        await expectAboveKeyboard(tester, find.text('BİTİR'));
      });

      testWidgets('boş alana dokununca odak düşer', (tester) async {
        await _pumpPage(tester, brightness);

        await expectTapOutsideDropsFocus(tester, findFieldLabelled('Şifre'));
      });
    });
  }
}
