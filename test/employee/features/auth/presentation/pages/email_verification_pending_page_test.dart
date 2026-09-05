import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/email_verification_pending_page.dart';

import '../../../../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final isBusiness in [false, true]) {
      testWidgets(
        'doğrulama beklerken demo oturumu açılamaz: $brightness, işveren=$isBusiness',
        (tester) async {
          await pumpInApp(
            tester,
            EmailVerificationPendingPage(
              isBusiness: isBusiness,
              email: 'ornek@iskoala.test',
            ),
            brightness: brightness,
          );

          expect(find.textContaining('ornek@iskoala.test'), findsOneWidget);
          expect(find.textContaining('Arayüzünü Gör (Demo)'), findsNothing);
        },
      );
    }
  }
}
