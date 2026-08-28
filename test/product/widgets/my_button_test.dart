import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/my_button.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('başlığı gösterir', (tester) async {
    await pumpInApp(tester, MyButton(onPressed: () {}, title: 'Başvur'));

    expect(find.text('Başvur'), findsOneWidget);
  });

  testWidgets('basınca callback çalışır', (tester) async {
    var basildi = 0;
    await pumpInApp(
      tester,
      MyButton(onPressed: () => basildi++, title: 'Başvur'),
    );

    await tester.tap(find.byType(ElevatedButton));

    expect(basildi, 1);
  });

  testWidgets('onPressed null ise buton devre dışı', (tester) async {
    await pumpInApp(tester, const MyButton(onPressed: null, title: 'Başvur'));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  group('isReversed', () {
    // Ters buton yeşilin üstünde değil yerinde duruyor: zemini sayfanınki,
    // ayıran şey yeşil kenarlık. `onPrimary`'ye bağlıyken koyu temada yanlış
    // renge düşüyordu.
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada zemin sayfa zeminiyle aynı', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          MyButton(onPressed: () {}, title: 'Giriş', isReversed: true),
          brightness: brightness,
        );

        final theme = brightness == Brightness.dark ? darkTheme : lightTheme;
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final background = button.style?.backgroundColor?.resolve({});

        expect(background, theme.scaffoldBackgroundColor);
      });
    }
  });

  group('isLoading', () {
    testWidgets('başlık yerine spinner çizer', (tester) async {
      await pumpInApp(
        tester,
        MyButton(onPressed: () {}, title: 'Başvur', isLoading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Başvur'), findsNothing);
    });

    // Yükleniyorken tekrar basılabilirse aynı başvuru iki kez gider.
    testWidgets('yükleniyorken basılamaz', (tester) async {
      var basildi = 0;
      await pumpInApp(
        tester,
        MyButton(onPressed: () => basildi++, title: 'Başvur', isLoading: true),
      );

      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);

      expect(basildi, 0);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });
  });

  group('tema', () {
    // Zemin ve yazı rengi isReversed ile yer değiştiriyor; ikisi de
    // context'ten okunuyor, sabit renk kullanılmıyor.
    testWidgets('isReversed zemin ile yazı rengini takas eder', (tester) async {
      await pumpInApp(
        tester,
        Column(
          children: [
            MyButton(onPressed: () {}, title: 'Normal'),
            MyButton(onPressed: () {}, title: 'Ters', isReversed: true),
          ],
        ),
      );

      final normal = tester.widget<Text>(find.text('Normal')).style!.color;
      final ters = tester.widget<Text>(find.text('Ters')).style!.color;

      expect(normal, isNot(ters));
    });

    // Renkler `context`ten geldiği için bu widget'lar `const` olamıyor;
    // yanlışlıkla `const` eklenirse ya da bir renk sabitlenirse çizim
    // burada patlar.
    testWidgets('her iki temada da hatasız çizilir', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpInApp(
          tester,
          MyButton(onPressed: () {}, title: 'Başvur'),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull, reason: '$brightness patladı');
        expect(find.text('Başvur'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('Başvur')).style?.color,
          isNotNull,
          reason: '$brightness için yazı rengi verilmemiş',
        );
      }
    });
  });
}
