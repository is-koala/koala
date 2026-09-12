import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_region.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';
import 'package:koala/employee/features/settings/presentation/widgets/live_mrz_scanner.dart';
import 'package:koala/employee/features/settings/services/mrz_camera_session.dart';
import 'package:koala/product/constants/app_colors.dart';

import '../../../../../support/pump.dart';

class _FakeCameraSession implements MrzCameraSession {
  final StreamController<MrzFrameObservation> controller =
      StreamController<MrzFrameObservation>.broadcast();

  bool started = false;
  bool paused = false;

  @override
  Widget buildPreview() => const ColoredBox(
    key: ValueKey('fake-camera-preview'),
    color: Colors.black,
  );

  @override
  Stream<MrzFrameObservation> get observations => controller.stream;

  @override
  Size? get previewSize => const Size(720, 1280);

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;

  @override
  Future<void> dispose() async => controller.close();
}

class _PendingCameraSession extends _FakeCameraSession {
  final Completer<void> pending = Completer<void>();

  @override
  Future<void> start() => pending.future;
}

class _DeniedCameraSession extends _FakeCameraSession {
  @override
  Future<void> start() async {
    throw const ChipReadException(ChipReadFailure.cameraDenied);
  }
}

class _BrokenCameraSession extends _FakeCameraSession {
  @override
  Future<void> start() async => throw StateError('camera failed');
}

class _BrokenResumeCameraSession extends _FakeCameraSession {
  @override
  Future<void> resume() async {
    throw const ChipReadException(ChipReadFailure.unknown);
  }
}

void main() {
  testWidgets('kamera açılırken hazırlık durumu gösterilir', (tester) async {
    final camera = _PendingCameraSession();

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (_) {},
        onFailure: (_) {},
        onManualEntry: () {},
      ),
    );

    expect(find.text('Kamera hazırlanıyor'), findsOneWidget);

    camera.pending.complete();
    await tester.pump();
  });

  testWidgets('canlı kamera amber kadrajla eylem söyler', (tester) async {
    final camera = _FakeCameraSession();
    var manualEntryRequested = false;
    final semantics = tester.ensureSemantics();

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (_) {},
        onFailure: (_) {},
        onManualEntry: () => manualEntryRequested = true,
      ),
    );
    await tester.pump();

    expect(camera.started, isTrue);
    expect(find.byKey(const ValueKey('fake-camera-preview')), findsOneWidget);
    expect(find.text('Kartı kadraja yaklaştır'), findsOneWidget);
    expect(find.text('Bilgileri Elle Gir'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'TCKK arka yüzündeki üç satırlık MRZ alanı için tarama çerçevesi',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Bilgileri Elle Gir'));
    expect(manualEntryRequested, isTrue);

    final frame = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('mrz-scan-frame')),
    );
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.border!.top.color, AppColors.warning);

    final preview = tester.getRect(
      find.byKey(const ValueKey('fake-camera-preview')),
    );
    final expected = MrzScanRegion.pixelRegion(
      preview.size,
    ).shift(preview.topLeft);
    expect(
      tester.getRect(find.byKey(const ValueKey('mrz-scan-frame'))),
      expected,
    );
    semantics.dispose();
  });

  testWidgets('kararlı MRZ yeşile dönüp titreşimden sonra otomatik ilerler', (
    tester,
  ) async {
    final camera = _FakeCameraSession();
    final key = MrzKey.manual(
      documentNumber: 'A01B23456',
      birthDate: DateTime(1998, 4, 7),
      expiryDate: DateTime(2030, 1, 1),
    );
    MrzKey? captured;
    var hapticCount = 0;

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (value) => captured = value,
        onFailure: (_) {},
        onManualEntry: () {},
        successHold: const Duration(milliseconds: 300),
        haptic: () async => hapticCount++,
      ),
    );
    await tester.pump();

    for (var index = 0; index < 3; index++) {
      camera.controller.add(MrzFrameObservation.valid(key));
      await tester.pump();
    }

    expect(find.text('MRZ geçerli, çip okumaya hazır'), findsOneWidget);
    final frame = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('mrz-scan-frame')),
    );
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.border!.top.color, AppColors.success);
    expect(hapticCount, 1);
    expect(captured, isNull);

    await tester.pump(const Duration(milliseconds: 300));

    expect(captured?.documentNumber, 'A01B23456');
  });

  for (final lifecycle in const [
    AppLifecycleState.inactive,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    testWidgets('${lifecycle.name} kamerayı kapatır ve dönüşte yeniden açar', (
      tester,
    ) async {
      final camera = _FakeCameraSession();

      await pumpInApp(
        tester,
        LiveMrzScanner(
          camera: camera,
          onCaptured: (_) {},
          onFailure: (_) {},
          onManualEntry: () {},
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(lifecycle);
      await tester.pump();
      expect(camera.paused, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(camera.paused, isFalse);
    });
  }

  testWidgets('kamera açılırken arka plana geçilirse akış duraklatılır', (
    tester,
  ) async {
    final camera = _PendingCameraSession();

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (_) {},
        onFailure: (_) {},
        onManualEntry: () {},
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    camera.pending.complete();
    await tester.pump();
    await tester.pump();

    expect(camera.paused, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('lifecycle dönüş hatası yakalanıp ekrana bildirilir', (
    tester,
  ) async {
    final camera = _BrokenResumeCameraSession();
    ChipReadFailure? failure;

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (_) {},
        onFailure: (value) => failure = value,
        onManualEntry: () {},
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(failure, ChipReadFailure.unknown);
  });

  testWidgets('kamera izni reddedilince ayrışmış hata bildirilir', (
    tester,
  ) async {
    final camera = _DeniedCameraSession();
    ChipReadFailure? failure;

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (_) {},
        onFailure: (value) => failure = value,
        onManualEntry: () {},
      ),
    );
    await tester.pump();

    expect(failure, ChipReadFailure.cameraDenied);
  });

  testWidgets('izin dışındaki kamera açılış hatası bilinmeyen kalır', (
    tester,
  ) async {
    final camera = _BrokenCameraSession();
    ChipReadFailure? failure;

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (_) {},
        onFailure: (value) => failure = value,
        onManualEntry: () {},
      ),
    );
    await tester.pump();

    expect(failure, ChipReadFailure.unknown);
  });

  testWidgets('OCR akış hatasının gerçek nedenini kaybetmez', (tester) async {
    final camera = _FakeCameraSession();
    ChipReadFailure? failure;

    await pumpInApp(
      tester,
      LiveMrzScanner(
        camera: camera,
        onCaptured: (_) {},
        onFailure: (value) => failure = value,
        onManualEntry: () {},
      ),
    );
    await tester.pump();

    camera.controller.addError(
      const ChipReadException(ChipReadFailure.ocrModelUnavailable),
    );
    await tester.pump();

    expect(failure, ChipReadFailure.ocrModelUnavailable);
  });

  for (final brightness in Brightness.values) {
    testWidgets('canlı kadraj ${brightness.name} temada çizilir', (
      tester,
    ) async {
      final camera = _FakeCameraSession();

      await pumpInApp(
        tester,
        LiveMrzScanner(
          camera: camera,
          onCaptured: (_) {},
          onFailure: (_) {},
          onManualEntry: () {},
        ),
        brightness: brightness,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('mrz-scan-frame')), findsOneWidget);
      expect(find.text('Kartı kadraja yaklaştır'), findsOneWidget);
    });
  }
}
