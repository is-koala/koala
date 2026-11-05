import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_scanner.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/fake_boarding_camera.dart';
import '../../../../../support/pump.dart';

void main() {
  late FakeBoardingCamera camera;
  late FakeCameraPermissionProbe probe;
  late List<BoardingToken> tokens;

  setUp(() {
    camera = FakeBoardingCamera();
    probe = FakeCameraPermissionProbe();
    tokens = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    BoardingTokenKind accepted = BoardingTokenKind.shuttle,
    Brightness brightness = Brightness.light,
  }) => pumpInApp(
    tester,
    BoardingScannerView(
      actor: BoardingActor.worker,
      acceptedKind: accepted,
      instruction: 'Servisteki QR\'ı okutun.',
      unavailableHint: 'Kendi QR\'ınızı gösterin.',
      onToken: (token, _) => tokens.add(token),
      cameraBuilder: camera.build,
      permissionProbe: probe,
      appScheme: 'koala-staging',
      now: () => DateTime.utc(2026, 9, 20, 3, 41),
    ),
    brightness: brightness,
  );

  for (final brightness in Brightness.values) {
    testWidgets('doğru türdeki QR iletilir, aynı kod tekrar iletilmez '
        '(${brightness.name})', (tester) async {
      await pump(tester, brightness: brightness);

      expect(find.byKey(const ValueKey('fake-boarding-camera')), findsOne);
      expect(find.text('Servisteki QR\'ı okutun.'), findsOne);

      camera.scan('koala-staging://board?t=$shuttleTokenValue');
      camera.scan('koala-staging://board?t=$shuttleTokenValue');
      await tester.pump();

      expect(tokens, hasLength(1));
      expect(tokens.single.subjectId, shuttleUuid);
    });
  }

  testWidgets('çalışan QR\'ı ve yabancı kod uyarı gösterir, iletilmez', (
    tester,
  ) async {
    await pump(tester);

    camera.scan('koala-staging://board?t=$workerTokenValue');
    await tester.pump();
    expect(
      find.text(
        BoardingScannerView.wrongKindMessage(BoardingTokenKind.shuttle),
      ),
      findsOne,
    );

    camera.scan('https://example.com/menu');
    await tester.pump();
    expect(find.text(BoardingScannerView.notBoardingQrMessage), findsOne);
    expect(tokens, isEmpty);

    await tester.pump(BoardingScannerView.hintDuration);
    expect(find.text(BoardingScannerView.notBoardingQrMessage), findsNothing);
  });

  testWidgets('izin reddi: tekrar dene kamerayı yeniden kurar', (tester) async {
    await pump(tester);

    camera.fail(BoardingCameraError.permissionDenied);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('boarding-camera-error-permissionDenied')),
      findsOne,
    );
    expect(find.text('Kamera izni verilmedi'), findsOne);
    final buildsBefore = camera.builds;

    await tester.tap(find.byKey(const ValueKey('boarding-camera-retry')));
    await tester.pumpAndSettle();

    expect(camera.builds, greaterThan(buildsBefore));
    expect(find.byKey(const ValueKey('fake-boarding-camera')), findsOne);
  });

  testWidgets('kalıcı ret: ayarları aç düğmesi ve başka yol ipucu', (
    tester,
  ) async {
    probe.permanentlyDenied = true;
    await pump(tester);

    camera.fail(BoardingCameraError.permissionDenied);
    await tester.pumpAndSettle();

    expect(find.text('Kamera izni kapalı'), findsOne);
    expect(find.text('Kendi QR\'ınızı gösterin.'), findsOne);
    await tester.tap(find.byKey(const ValueKey('boarding-camera-settings')));
    await tester.pumpAndSettle();
    expect(probe.settingsOpened, 1);

    // Ayarlar açıkken kamera yeniden denenmez; izin henüz verilmedi.
    final buildsBefore = camera.builds;
    expect(find.text('Kamera izni kapalı'), findsOne);

    // Kullanıcı Ayarlar'dan döndü: kamera yeniden kurulur.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(camera.builds, greaterThan(buildsBefore));
    expect(find.byKey(const ValueKey('fake-boarding-camera')), findsOne);
  });

  testWidgets('QR okuyucu yoksa Play Services gerektiği söylenir', (
    tester,
  ) async {
    await pump(tester);

    camera.fail(BoardingCameraError.scannerUnavailable);
    await tester.pumpAndSettle();

    expect(find.text('QR okuyucu hazırlanamadı'), findsOne);
    expect(find.textContaining('Google Play Hizmetleri'), findsOne);
    expect(find.text('Kendi QR\'ınızı gösterin.'), findsOne);
  });

  testWidgets('meşgulken okunan kod yok sayılır', (tester) async {
    await pumpInApp(
      tester,
      BoardingScannerView(
        actor: BoardingActor.employer,
        acceptedKind: BoardingTokenKind.worker,
        instruction: 'x',
        busy: true,
        onToken: (token, _) => tokens.add(token),
        cameraBuilder: camera.build,
        permissionProbe: probe,
        appScheme: 'koala-staging',
      ),
    );

    camera.scan(workerTokenValue);
    await tester.pump();

    expect(tokens, isEmpty);
    expect(find.byKey(const ValueKey('boarding-scanner-busy')), findsOne);
  });

  testWidgets('sonuçlanmış kod 30 sn ya da farklı bir kod görülene kadar '
      'yeniden gönderilmez', (tester) async {
    var now = DateTime.utc(2026, 9, 20, 3, 41);
    await pumpInApp(
      tester,
      BoardingScannerView(
        actor: BoardingActor.worker,
        acceptedKind: BoardingTokenKind.shuttle,
        instruction: 'x',
        onToken: (token, _) => tokens.add(token),
        cameraBuilder: camera.build,
        permissionProbe: probe,
        appScheme: 'koala-staging',
        now: () => now,
      ),
    );
    const other = 's1.aaaaaaaa-0000-4000-8000-000000000000.2934001.otherMac';

    camera.scan(shuttleTokenValue);
    now = now.add(const Duration(seconds: 20));
    camera.scan(shuttleTokenValue);
    expect(tokens, hasLength(1), reason: '30 sn dolmadı');

    now = now.add(const Duration(seconds: 11));
    camera.scan(shuttleTokenValue);
    expect(tokens, hasLength(2), reason: '30 sn doldu');

    camera.scan(other);
    camera.scan(shuttleTokenValue);
    expect(tokens, hasLength(4), reason: 'araya farklı kod girdi');
    await tester.pump();
  });
}
