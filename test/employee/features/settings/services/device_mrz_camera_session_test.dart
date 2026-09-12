import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/services/device_mrz_camera_session.dart';
import 'package:koala/employee/features/settings/services/mrz_scanner.dart';

class _NoopTextRecognizer extends TextRecognizer {
  @override
  Future<void> close() async {}

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async =>
      RecognizedText(text: '', blocks: const []);
}

class _FakeDeviceCameraFactory implements MrzDeviceCameraFactory {
  final List<_FakeDeviceCameraController> controllers = [];
  final List<Completer<void>> initialization = [];

  @override
  Future<MrzDeviceCameraController> createRearCamera() async {
    final completer = Completer<void>();
    final controller = _FakeDeviceCameraController(completer.future);
    controllers.add(controller);
    initialization.add(completer);
    return controller;
  }
}

class _PendingCreationFactory implements MrzDeviceCameraFactory {
  final Completer<void> release = Completer<void>();
  final _FakeDeviceCameraController controller = _FakeDeviceCameraController(
    Future<void>.value(),
  );

  @override
  Future<MrzDeviceCameraController> createRearCamera() async {
    await release.future;
    return controller;
  }
}

class _FakeDeviceCameraController implements MrzDeviceCameraController {
  _FakeDeviceCameraController(this.initialization);

  final Future<void> initialization;
  bool disposed = false;
  bool streaming = false;
  int disposeCount = 0;
  DeviceOrientation orientation = DeviceOrientation.portraitUp;
  Completer<void>? disposeGate;

  @override
  DeviceOrientation get deviceOrientation => orientation;

  @override
  CameraLensDirection get lensDirection => CameraLensDirection.back;

  @override
  Size? get previewSize => const Size(720, 1280);

  @override
  int get sensorOrientation => 90;

  @override
  bool get isStreamingImages => streaming;

  @override
  Widget buildPreview() => const SizedBox();

  @override
  Future<void> initialize() => initialization;

  @override
  Future<void> lockCaptureOrientation(DeviceOrientation orientation) async {}

  @override
  Future<void> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    streaming = true;
  }

  @override
  Future<void> stopImageStream() async => streaming = false;

  @override
  Future<void> dispose() async {
    final gate = disposeGate;
    if (gate != null) await gate.future;
    disposed = true;
    disposeCount++;
  }
}

void main() {
  test('portrait kilidi cihaz yataya dönünce OCR dönüşünü değiştirmez', () {
    final controller = _FakeDeviceCameraController(Future<void>.value());

    final portrait = DeviceMrzCameraSession.rotationForCamera(
      controller,
      isIOS: false,
    );
    controller.orientation = DeviceOrientation.landscapeLeft;
    final landscape = DeviceMrzCameraSession.rotationForCamera(
      controller,
      isIOS: false,
    );

    expect(portrait, InputImageRotation.rotation90deg);
    expect(landscape, portrait);
  });

  test('dispose, geç dönen factory controllerını stale bırakmaz', () async {
    final factory = _PendingCreationFactory();
    final session = DeviceMrzCameraSession(
      cameraFactory: factory,
      scanner: MrzScanner(recognizer: _NoopTextRecognizer()),
    );

    final starting = session.start();
    await Future<void>.delayed(Duration.zero);
    final disposing = session.dispose();
    factory.release.complete();
    await starting;
    await disposing;

    expect(factory.controller.disposed, isTrue);
    expect(factory.controller.streaming, isFalse);
    expect(factory.controller.disposeCount, 1);
  });

  test('başlatma sırasında pause eski controllerı hemen bırakır', () async {
    final factory = _FakeDeviceCameraFactory();
    final session = DeviceMrzCameraSession(
      cameraFactory: factory,
      scanner: MrzScanner(recognizer: _NoopTextRecognizer()),
    );

    final starting = session.start();
    await Future<void>.delayed(Duration.zero);
    expect(factory.controllers, hasLength(1));

    final pausing = session.pause();
    factory.initialization.single.complete();
    await starting;
    await pausing;

    expect(factory.controllers.single.disposed, isTrue);
    expect(factory.controllers.single.streaming, isFalse);
    expect(factory.controllers.single.disposeCount, 1);
    expect(session.previewSize, isNull);

    await session.dispose();
  });

  test(
    'pause controllerı dispose eder, resume yenisini initialize eder',
    () async {
      final factory = _FakeDeviceCameraFactory();
      final session = DeviceMrzCameraSession(
        cameraFactory: factory,
        scanner: MrzScanner(recognizer: _NoopTextRecognizer()),
      );

      final firstStart = session.start();
      await Future<void>.delayed(Duration.zero);
      factory.initialization[0].complete();
      await firstStart;
      expect(factory.controllers[0].streaming, isTrue);

      await session.pause();
      expect(factory.controllers[0].disposed, isTrue);
      expect(factory.controllers[0].streaming, isFalse);
      expect(session.previewSize, isNull);

      final resumed = session.resume();
      await Future<void>.delayed(Duration.zero);
      expect(factory.controllers, hasLength(2));
      factory.initialization[1].complete();
      await resumed;

      expect(factory.controllers[1].disposed, isFalse);
      expect(factory.controllers[1].streaming, isTrue);
      expect(session.previewSize, const Size(720, 1280));

      await session.dispose();
      expect(factory.controllers[1].disposed, isTrue);
    },
  );

  test('hızlı pause-resume eski dispose bitmeden yeni kamera açmaz', () async {
    final factory = _FakeDeviceCameraFactory();
    final session = DeviceMrzCameraSession(
      cameraFactory: factory,
      scanner: MrzScanner(recognizer: _NoopTextRecognizer()),
    );
    final firstStart = session.start();
    await Future<void>.delayed(Duration.zero);
    factory.initialization[0].complete();
    await firstStart;
    final disposeGate = Completer<void>();
    factory.controllers[0].disposeGate = disposeGate;

    final pausing = session.pause();
    await Future<void>.delayed(Duration.zero);
    final resuming = session.resume();
    await Future<void>.delayed(Duration.zero);

    expect(factory.controllers, hasLength(1));

    disposeGate.complete();
    await pausing;
    await Future<void>.delayed(Duration.zero);
    expect(factory.controllers, hasLength(2));
    factory.initialization[1].complete();
    await resuming;

    await session.dispose();
  });
}
