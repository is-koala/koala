import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/widgets/my_list_tile.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('başlığı gösterir', (tester) async {
    await pumpInApp(
      tester,
      MyListTile(title: 'Görünüm', icon: HugeIcons.strokeRoundedPaintBoard),
    );

    expect(find.text('Görünüm'), findsOneWidget);
  });

  testWidgets('value verilince sağda gösterilir', (tester) async {
    await pumpInApp(
      tester,
      MyListTile(
        title: 'Görünüm',
        icon: HugeIcons.strokeRoundedPaintBoard,
        value: 'Sistem',
      ),
    );

    expect(find.text('Sistem'), findsOneWidget);
  });

  testWidgets('value yokken sadece başlık var', (tester) async {
    await pumpInApp(
      tester,
      MyListTile(title: 'Görünüm', icon: HugeIcons.strokeRoundedPaintBoard),
    );

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('dokununca callback çalışır', (tester) async {
    var dokunuldu = 0;
    await pumpInApp(
      tester,
      MyListTile(
        title: 'Görünüm',
        icon: HugeIcons.strokeRoundedPaintBoard,
        onTap: () => dokunuldu++,
      ),
    );

    await tester.tap(find.byType(InkWell));

    expect(dokunuldu, 1);
  });

  // hugeicons 1.x ikonu artık IconData değil; ikon bir HugeIcon widget'ı
  // olarak çiziliyor. Paket tekrar kırıcı bir sürüm çıkarırsa burada yakalanır.
  testWidgets('ikon HugeIcon olarak çizilir', (tester) async {
    await pumpInApp(
      tester,
      MyListTile(title: 'Görünüm', icon: HugeIcons.strokeRoundedPaintBoard),
    );

    final hugeIcon = tester.widget<HugeIcon>(find.byType(HugeIcon));
    expect(hugeIcon.icon, HugeIcons.strokeRoundedPaintBoard);
    expect(hugeIcon.color, isNotNull);
  });

  testWidgets('her iki temada da hatasız çizilir', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpInApp(
        tester,
        MyListTile(
          title: 'Görünüm',
          icon: HugeIcons.strokeRoundedPaintBoard,
          value: 'Sistem',
        ),
        brightness: brightness,
      );

      expect(tester.takeException(), isNull, reason: '$brightness patladı');
      expect(find.text('Görünüm'), findsOneWidget);
    }
  });
}
