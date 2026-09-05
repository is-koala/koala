import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/email_verification_link_page.dart';

import '../../../../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'e-posta tokenı gösterilmeden bağlantı karşılanır: $brightness',
      (tester) async {
        const token = 'ekranda-gorunmemesi-gereken-token';

        await pumpInApp(
          tester,
          const EmailVerificationLinkPage(token: token),
          brightness: brightness,
        );

        expect(find.text('E-posta doğrulama bağlantın alındı'), findsOneWidget);
        expect(find.textContaining(token), findsNothing);
      },
    );
  }
}
