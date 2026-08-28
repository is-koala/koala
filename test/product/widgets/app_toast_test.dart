import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/widgets/app_toast.dart';

import '../../support/pump.dart';

/// Toast'u tetikleyen düğme; `AppToast` bir widget değil, `context` isteyen
/// bir çağrı olduğu için ağaçta bir tetikleyiciye ihtiyaç var.
Widget _trigger(void Function(BuildContext context) onTap) {
  return Builder(
    builder: (context) =>
        ElevatedButton(onPressed: () => onTap(context), child: const Text('X')),
  );
}

/// Giriş animasyonu bitene kadar bekleniyor: animasyon sürerken snackbar
/// dokunma almıyor, eylem düğmesine basan test boşa tıklıyor.
Future<void> _tapTrigger(WidgetTester tester) async {
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

SnackBar _snackBar(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

void main() {
  testWidgets('mesajı gösterir', (tester) async {
    await pumpInApp(
      tester,
      _trigger((context) => AppToast.success(context, 'Kaydedildi')),
    );

    await _tapTrigger(tester);

    expect(find.text('Kaydedildi'), findsOneWidget);
  });

  // Kullanıcının açıkça istediği ölçü: kapsülün yarıçapı butonlarınkiyle aynı.
  testWidgets('köşe yarıçapı buton yarıçapıyla aynı', (tester) async {
    await pumpInApp(
      tester,
      _trigger((context) => AppToast.info(context, 'Bilgi')),
    );

    await _tapTrigger(tester);

    final shape = _snackBar(tester).shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, AppRadius.primaryCircular);
  });

  // Zemin temadan okunuyor; iki temada da sabit bir renge düşmemeli.
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} temada zemin temadan gelir', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        _trigger((context) => AppToast.error(context, 'Hata')),
        brightness: brightness,
      );

      await _tapTrigger(tester);

      final expected = brightness == Brightness.dark
          ? AppColors.darkTileHigh
          : AppColors.lightTileHigh;
      expect(_snackBar(tester).backgroundColor, expected);
      expect(find.text('Hata'), findsOneWidget);
    });
  }

  group('eylem', () {
    testWidgets('etiket ve geri çağırma birlikte verilince eylem çizilir', (
      tester,
    ) async {
      var basildi = 0;
      await pumpInApp(
        tester,
        _trigger(
          (context) => AppToast.info(
            context,
            'Kaldırıldı',
            actionLabel: 'Geri Al',
            onAction: () => basildi++,
          ),
        ),
      );

      await _tapTrigger(tester);
      await tester.tap(find.text('Geri Al'));

      expect(basildi, 1);
    });

    testWidgets('eylemsiz toast eylem düğmesi taşımaz', (tester) async {
      await pumpInApp(
        tester,
        _trigger((context) => AppToast.info(context, 'Kaldırıldı')),
      );

      await _tapTrigger(tester);

      expect(_snackBar(tester).action, isNull);
    });
  });

  // Art arda gelen iki mesajda kullanıcı ikincisini görmek ister; birincisi
  // sırada beklerse yanlış mesaj ekranda kalıyor.
  testWidgets('ikinci toast birincinin yerini alır', (tester) async {
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            ElevatedButton(
              onPressed: () => AppToast.info(context, 'Birinci'),
              child: const Text('bir'),
            ),
            ElevatedButton(
              onPressed: () => AppToast.info(context, 'İkinci'),
              child: const Text('iki'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('bir'));
    await tester.pump();
    await tester.tap(find.text('iki'));
    await tester.pumpAndSettle();

    expect(find.text('Birinci'), findsNothing);
    expect(find.text('İkinci'), findsOneWidget);
  });
}
