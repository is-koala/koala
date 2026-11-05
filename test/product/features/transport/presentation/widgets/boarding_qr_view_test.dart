import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_qr_view.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/pump.dart';

void main() {
  final qr = BoardingQr.fromJson(boardingQrJson());

  for (final brightness in Brightness.values) {
    testWidgets('QR iki temada da beyaz üstüne siyah çizilir '
        '(${brightness.name})', (tester) async {
      await pumpInApp(tester, BoardingQrView(qr: qr), brightness: brightness);

      final box = tester.widget<Container>(
        find.byKey(const ValueKey('boarding-qr')),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.qrBackground);

      final image = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(image.semanticsLabel, 'Biniş QR kodu');
      expect(image.backgroundColor, AppColors.qrBackground);
      expect(image.eyeStyle.color, AppColors.qrForeground);
      expect(image.dataModuleStyle.color, AppColors.qrForeground);
      expect(find.byKey(const ValueKey('boarding-qr-expired')), findsNothing);
    });
  }

  testWidgets('kenar ekranı aşmaz ve üst sınırda kalır', (tester) async {
    await pumpInApp(tester, BoardingQrView(qr: qr));

    final size = tester.getSize(find.byKey(const ValueKey('boarding-qr')));
    expect(size.width, BoardingQrView.defaultMaxSide);
    expect(size.height, size.width);
  });

  testWidgets('süresi dolan QR soluklaşır ve açıklama yazılır', (tester) async {
    await pumpInApp(tester, BoardingQrView(qr: qr, expired: true));

    expect(find.byKey(const ValueKey('boarding-qr-expired')), findsOne);
    expect(find.text('QR\'ın süresi doldu; yenileniyor.'), findsOne);
  });
}
