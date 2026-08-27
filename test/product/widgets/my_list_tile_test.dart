import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_list_tile.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('başlığı gösterir', (tester) async {
    await pumpInApp(
      tester,
      const MyListTile(title: 'Görünüm', icon: AppIcons.paint),
    );

    expect(find.text('Görünüm'), findsOneWidget);
  });

  testWidgets('value verilince sağda gösterilir', (tester) async {
    await pumpInApp(
      tester,
      const MyListTile(title: 'Görünüm', icon: AppIcons.paint, value: 'Sistem'),
    );

    expect(find.text('Sistem'), findsOneWidget);
  });

  testWidgets('value yokken sadece başlık var', (tester) async {
    await pumpInApp(
      tester,
      const MyListTile(title: 'Görünüm', icon: AppIcons.paint),
    );

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('dokununca callback çalışır', (tester) async {
    var dokunuldu = 0;
    await pumpInApp(
      tester,
      MyListTile(
        title: 'Görünüm',
        icon: AppIcons.paint,
        onTap: () => dokunuldu++,
      ),
    );

    await tester.tap(find.byType(InkWell));

    expect(dokunuldu, 1);
  });

  testWidgets('ikon AppIcon olarak çizilir', (tester) async {
    await pumpInApp(
      tester,
      const MyListTile(title: 'Görünüm', icon: AppIcons.paint),
    );

    final appIcon = tester.widget<AppIcon>(find.byType(AppIcon));
    expect(appIcon.name, AppIcons.paint);
    expect(appIcon.color, isNotNull);
  });

  testWidgets('her iki temada da hatasız çizilir', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpInApp(
        tester,
        const MyListTile(
          title: 'Görünüm',
          icon: AppIcons.paint,
          value: 'Sistem',
        ),
        brightness: brightness,
      );

      expect(tester.takeException(), isNull, reason: '$brightness patladı');
      expect(find.text('Görünüm'), findsOneWidget);
    }
  });
}
