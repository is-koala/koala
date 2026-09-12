import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';
import 'package:koala/employee/features/settings/services/mrz_camera_session.dart';
import 'package:koala/employee/features/settings/services/mrz_scanner.dart';

/// Resmî Flutter kamera eklentisini ML Kit MRZ çözümleyicisine bağlar.
///
/// Kareler yalnız bellekte yaşar, dosyaya ve loga yazılmaz. ML Kit sürerken
/// yeni kare düşürülür; böylece kişisel veri kuyruğu ve eşzamanlı OCR oluşmaz.
class DeviceMrzCameraSession implements MrzCameraSession {
  DeviceMrzCameraSession({MrzScanner? scanner})
    : _scanner = scanner ?? MrzScanner();

  final MrzScanner _scanner;
  final StreamController<MrzFrameObservation> _observations =
      StreamController<MrzFrameObservation>.broadcast();

  CameraController? _controller;
  CameraDescription? _camera;
  bool _isAnalyzing = false;
  bool _isPaused = false;
  bool _isDisposed = false;
  int _generation = 0;
  DateTime? _lastAnalysisAt;

  /// Kamera akışını düşük cihazlarda da akıcı tutan analiz aralığı.
  static const Duration _analysisInterval = Duration(milliseconds: 180);

  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  Stream<MrzFrameObservation> get observations => _observations.stream;

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Center(child: CameraPreview(controller));
  }

  @override
  Future<void> start() async {
    if (_isDisposed) return;
    if (_controller != null) {
      await resume();
      return;
    }

    try {
      final cameras = await availableCameras();
      final rear = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      if (rear.isEmpty) {
        throw const ChipReadException(ChipReadFailure.cameraDenied);
      }

      _camera = rear.first;
      final controller = CameraController(
        rear.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await _startStream();
    } on CameraException catch (error) {
      throw ChipReadException(_failureForCamera(error), cause: error);
    }
  }

  @override
  Future<void> pause() async {
    if (_isDisposed || _isPaused) return;
    _isPaused = true;
    _generation++;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    if (!controller.value.isPreviewPaused) await controller.pausePreview();
  }

  @override
  Future<void> resume() async {
    if (_isDisposed || !_isPaused) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _isPaused = false;
    _generation++;
    if (controller.value.isPreviewPaused) await controller.resumePreview();
    await _startStream();
  }

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null || controller.value.isStreamingImages) return;
    await controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage frame) {
    if (_isDisposed || _isPaused || _isAnalyzing) return;
    final now = DateTime.now();
    final last = _lastAnalysisAt;
    if (last != null && now.difference(last) < _analysisInterval) return;

    final input = _inputImage(frame);
    if (input == null) return;
    _lastAnalysisAt = now;
    _isAnalyzing = true;
    final generation = _generation;
    unawaited(_analyze(frame, input, generation));
  }

  Future<void> _analyze(
    CameraImage frame,
    ({InputImage image, Size uprightSize}) input,
    int generation,
  ) async {
    try {
      final observation = await _scanner.analyzeLiveFrame(
        input.image,
        uprightSize: input.uprightSize,
        meanLuminance: _meanLuminance(frame),
      );
      if (_canPublish(generation)) _observations.add(observation);
    } on ChipReadException catch (error, stackTrace) {
      if (_canPublish(generation)) {
        _observations.addError(error, stackTrace);
        unawaited(pause());
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  bool _canPublish(int generation) =>
      !_isDisposed && !_isPaused && generation == _generation;

  ({InputImage image, Size uprightSize})? _inputImage(CameraImage frame) {
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null || frame.planes.length != 1) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(frame.format.raw as int);
    final expected = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;
    if (format != expected) return null;

    final rotation = _rotationFor(camera, controller.value.deviceOrientation);
    if (rotation == null) return null;

    final rawSize = Size(frame.width.toDouble(), frame.height.toDouble());
    final turnsSize =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final uprightSize = turnsSize
        ? Size(rawSize.height, rawSize.width)
        : rawSize;
    final plane = frame.planes.single;
    return (
      image: InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: rawSize,
          rotation: rotation,
          format: format!,
          bytesPerRow: plane.bytesPerRow,
        ),
      ),
      uprightSize: uprightSize,
    );
  }

  InputImageRotation? _rotationFor(
    CameraDescription camera,
    DeviceOrientation orientation,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    final deviceRotation = _orientationDegrees[orientation];
    if (deviceRotation == null) return null;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees);
  }

  double _meanLuminance(CameraImage frame) {
    final bytes = frame.planes.single.bytes;
    if (bytes.isEmpty) return 0;

    var sum = 0;
    var samples = 0;
    if (Platform.isAndroid) {
      // NV21'in ilk width × height baytı doğrudan parlaklık düzlemidir.
      final limit = frame.width * frame.height;
      for (var index = 0; index < limit && index < bytes.length; index += 64) {
        sum += bytes[index];
        samples++;
      }
    } else {
      // BGRA'da her pikselin ilk üç baytının ortalaması yeterli bir ışık
      // sinyali verir; bütün kareyi dolaşmadan örnekliyoruz.
      for (var index = 0; index + 2 < bytes.length; index += 256) {
        sum += (bytes[index] + bytes[index + 1] + bytes[index + 2]) ~/ 3;
        samples++;
      }
    }
    return samples == 0 ? 0 : sum / samples;
  }

  ChipReadFailure _failureForCamera(CameraException error) {
    const deniedCodes = {
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
    };
    return deniedCodes.contains(error.code)
        ? ChipReadFailure.cameraDenied
        : ChipReadFailure.unknown;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _isPaused = true;
    _generation++;

    final controller = _controller;
    if (controller != null) {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } on Object {
          // Dispose kalan yerli kaynakları yine de bırakır.
        }
      }
      await controller.dispose();
    }
    await _scanner.dispose();
    await _observations.close();
  }
}
