import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/my_textfield.dart';

import '../../support/keyboard.dart';
import '../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} tema: sheet kabuğunun boş alanına dokununca odak '
      'düşer',
      (tester) async {
        await pumpInApp(
          tester,
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => AppBottomSheet.show<void>(
                  context,
                  builder: (_) => const AppBottomSheet(
                    title: 'Not',
                    child: MyTextfield(labelText: 'Açıklama'),
                  ),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('Aç'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(anyFieldFocused(tester), isTrue);

        // Başlık satırının solundaki pay: ne kapatma düğmesi ne alan.
        final sheet = tester.getRect(find.byType(AppBottomSheet));
        await tester.tapAt(sheet.topLeft + const Offset(4, 4));
        await tester.pump();

        expect(anyFieldFocused(tester), isFalse);
        expect(find.byType(AppBottomSheet), findsOneWidget);
      },
    );
  }

  group('liste en üstteyken aşağı çekince kapanma', () {
    Future<void> openListSheet(WidgetTester tester) async {
      await pumpInApp(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => AppBottomSheet.show<void>(
                context,
                builder: (_) => AppBottomSheet(
                  title: 'Liste',
                  child: SizedBox(
                    height: 300,
                    child: ListView(
                      key: const ValueKey('sheet-list'),
                      children: [
                        for (var i = 0; i < 30; i++)
                          SizedBox(height: 48, child: Text('Satır $i')),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      expect(find.text('Liste'), findsOneWidget);
    }

    testWidgets('en üstteyken aşağı çekmek sheet\'i kapatır', (tester) async {
      await openListSheet(tester);

      await tester.drag(
        find.byKey(const ValueKey('sheet-list')),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Liste'), findsNothing);
    });

    testWidgets('liste aşağıdayken yukarı kaydırmak sheet\'i kapatmaz', (
      tester,
    ) async {
      await openListSheet(tester);
      await tester.drag(
        find.byKey(const ValueKey('sheet-list')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('sheet-list')),
        const Offset(0, 150),
      );
      await tester.pumpAndSettle();

      expect(find.text('Liste'), findsOneWidget);
    });
  });
}
