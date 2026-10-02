import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/widgets/profile_cover.dart';

import '../../support/finders.dart';
import '../../support/pump.dart';

/// Profil kapağı iki ekranda ortak: işverenin aday sayfası ve çalışanın
/// başkasının profili. Zemin marka yeşili gradyan, üstündeki her şey iki
/// temada da aynı beyaz — yani temayla değişmemeli.
void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light ? 'açık' : 'koyu';

    testWidgets('ad, meslek, rol etiketi ve konum çizilir ($theme tema)', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const ProfileCover(
          name: 'Ayşe Yılmaz',
          subtitle: 'Kafe işletmecisi',
          roleLabel: 'İşveren',
          location: 'Kadıköy/İstanbul',
        ),
        brightness: brightness,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Kafe işletmecisi'), findsOneWidget);
      expect(find.text('İşveren'), findsOneWidget);
      expect(find.text('Kadıköy/İstanbul'), findsOneWidget);
      // Konum işareti ikon kataloğundan (`AppIcon`), Material `Icons`'tan
      // değil (AGENTS.md §Icons).
      expect(findAppIcon(AppIcons.location), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('kapaktaki yazı iki temada da aynı beyaz ($theme tema)', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const ProfileCover(name: 'Ayşe Yılmaz', roleLabel: 'İşveren'),
        brightness: brightness,
      );

      final name = tester.widget<Text>(find.text('Ayşe Yılmaz'));
      expect(name.style?.color, AppColors.onAccent);
    });
  }

  testWidgets('olmayan parça çizilmez, boş etiket de', (tester) async {
    await pumpInApp(
      tester,
      const ProfileCover(name: 'Ayşe Yılmaz', subtitle: '', roleLabel: ''),
    );

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    // Boş meslek ve boş rol, boş bir satır ya da boş bir hap bırakmıyor.
    expect(find.text(''), findsNothing);
    expect(find.byType(Wrap), findsNothing);
  });
}
