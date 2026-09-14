import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/widgets/messaging_gate_note.dart';
import 'package:koala/product/constants/app_icons.dart';

import '../../support/finders.dart';
import '../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('MessagingGateNote / $themeName tema', () {
      testWidgets('metni bilgi ikonuyla yazar', (tester) async {
        await pumpInApp(
          tester,
          const MessagingGateNote(
            message: 'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
          ),
          brightness: brightness,
        );

        expect(
          find.text('Mesajlaşma, işveren ödemeyi tamamladığında açılır.'),
          findsOneWidget,
        );
        expect(findAppIcon(AppIcons.info), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);
      });

      testWidgets('kısayol verilirse metnin yanında durur', (tester) async {
        var tapped = false;
        await pumpInApp(
          tester,
          MessagingGateNote(
            message: 'Ödemeyi tamamlayınca ekip sohbeti açılır.',
            action: TextButton(
              onPressed: () => tapped = true,
              child: const Text('Ödemeye Git'),
            ),
          ),
          brightness: brightness,
        );

        await tester.tap(find.text('Ödemeye Git'));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });
  }
}
