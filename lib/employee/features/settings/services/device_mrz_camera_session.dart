import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_region.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';
import 'package:koala/employee/features/settings/services/mrz_camera_session.dart';
import 'package:koala/employee/features/settings/services/mrz_scanner.dart';

/// Kamera eklentisini oturumdan ayıran üretim sınırı.
abstract interface class MrzDeviceCameraFactory {
  Future<MrzDeviceCameraController> createRearCamera();
}

/// Yaşam döngüsü ve yarış testlerinde gerçek oturum sahipliğini sınayan seam.
abstract interface class MrzDeviceCameraController {
  bool get isStreamingImages;
  DeviceOrientation get deviceOrientation;
  CameraLensDirection get lensDirection;
  int get sensorOrientation;
  Size? get previewSize;

  Widget buildPreview();
  Future<void> initialize();
  Future<void> lockCaptureOrientation(DeviceOrientation orientation);
  Future<void> startImageStream(void Function(CameraImage image) onImage);
  Future<void> stopImageStream();
  Future<void> dispose();
}

class _PluginMrzDeviceCameraFactory implements MrzDeviceCameraFactory {
  @override
  Future<MrzDeviceCameraController> createRearCamera() async {
    final cameras = await availableCameras();
    final rear = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    if (rear.isEmpty) {
      throw const ChipReadException(ChipReadFailure.cameraDenied);
    }
    return _PluginMrzDeviceCameraController(
      CameraController(
        rear.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      ),
    );
  }
}

class _PluginMrzDeviceCameraController implements MrzDeviceCameraController {
  const _PluginMrzDeviceCameraController(this.controller);

  final CameraController controller;

  @override
  DeviceOrientation get deviceOrientation => controller.value.deviceOrientation;

  @override
  bool get isStreamingImages => controller.value.isStreamingImages;

  @override
  CameraLensDirection get lensDirection => controller.description.lensDirection;

  @override
  Size? get previewSize {
    final raw = controller.value.previewSize;
    if (raw == null) return null;
    return Size(raw.height, raw.width);
  }

  @override
  int get sensorOrientation => controller.description.sensorOrientation;

  @override
  Widget buildPreview() => CameraPreview(controller);

  @override
  Future<void> dispose() => controller.dispose();

  @override
  Future<void> initialize() => controller.initialize();

  @override
  Future<void> lockCaptureOrientation(DeviceOrientation orientation) =>
      controller.lockCaptureOrientation(orientation);

  @override
  Future<void> startImageStream(void Function(CameraImage image) onImage) =>
      controller.startImageStream(onImage);

  @override
  Future<void> stopImageStream() => controller.stopImageStream();
}

/// Resmî Flutter kamera eklentisini ML Kit MRZ çözümleyicisine bağlar.
///
/// Kareler yalnız bellekte yaşar, dosyaya ve loga yazılmaz. ML Kit sürerken
/// yeni kare düşürülür; böylece kişisel veri kuyruğu ve eşzamanlı OCR oluşmaz.
class DeviceMrzCameraSession implements MrzCameraSession {
  DeviceMrzCameraSession({
    MrzScanner? scanner,
    MrzDeviceCameraFactory? cameraFactory,
  }) : _scanner = scanner ?? MrzScanner(),
       _cameraFactory = cameraFactory ?? _PluginMrzDeviceCameraFactory();

  final MrzScanner _scanner;
  final MrzDeviceCameraFactory _cameraFactory;
  final StreamController<MrzFrameObservation> _observations =
      StreamController<MrzFrameObservation>.broadcast();

  MrzDeviceCameraController? _controller;
  bool _isAnalyzing = false;
  bool _isPaused = true;
  bool _isDisposed = false;
  int _generation = 0;
  DateTime? _lastAnalysisAt;
  Future<void> _operationTail = Future<void>.value();

  /// Kamera akışını düşük cihazlarda da akıcı tutan analiz aralığı.
  static const Duration _analysisInterval = Duration(milliseconds: 180);

  /// Önizleme, sensör dönüşümü ve OCR metadata'sı aynı kilidi kullanır.
  static const DeviceOrientation _captureOrientation =
      DeviceOrientation.portraitUp;

  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  Stream<MrzFrameObservation> get observations => _observations.stream;

  @override
  Size? get previewSize => _controller?.previewSize;

  @override
  Widget buildPreview() =>
      _controller?.buildPreview() ?? const SizedBox.shrink();

  @override
  Future<void> start() {
    if (_isDisposed || (_controller != null && !_isPaused)) {
      return Future<void>.value();
    }

    _isPaused = false;
    final generation = ++_generation;
    return _enqueue(() => _start(generation));
  }

  Future<void> _start(int generation) async {
    if (!_isCurrent(generation) || _controller != null) return;
    MrzDeviceCameraController? candidate;
    try {
      candidate = await _cameraFactory.createRearCamera();
      if (!await _keepOrDispose(candidate, generation)) return;

      await candidate.initialize();
      if (!await _keepOrDispose(candidate, generation)) return;

      await candidate.lockCaptureOrientation(_captureOrientation);
      if (!await _keepOrDispose(candidate, generation)) return;

      await candidate.startImageStream(
        (frame) => _onFrame(candidate!, frame, generation),
      );
      if (!await _keepOrDispose(candidate, generation)) return;

      _lastAnalysisAt = null;
      _controller = candidate;
    } on CameraException catch (error) {
      await _disposeCandidate(candidate);
      if (_isCurrent(generation)) {
        throw ChipReadException(_failureForCamera(error), cause: error);
      }
    } on ChipReadException {
      await _disposeCandidate(candidate);
      if (_isCurrent(generation)) rethrow;
    } on Object {
      await _disposeCandidate(candidate);
      if (_isCurrent(generation)) rethrow;
    }
  }

  /// Her yerli `await` sonrasında sahiplik hâlâ bu başlangıca mı ait.
  Future<bool> _keepOrDispose(
    MrzDeviceCameraController candidate,
    int generation,
  ) async {
    if (_isCurrent(generation)) return true;
    await _disposeCandidate(candidate);
    return false;
  }

  bool _isCurrent(int generation) =>
      !_isDisposed && !_isPaused && generation == _generation;

  @override
  Future<void> pause() {
    if (_isDisposed) return Future<void>.value();
    _isPaused = true;
    _generation++;
    _lastAnalysisAt = null;
    return _enqueue(_releaseController);
  }

  Future<void> _releaseController() async {
    final controller = _controller;
    try {
      await _disposeCandidate(controller);
    } finally {
      if (identical(_controller, controller)) _controller = null;
    }
  }

  @override
  Future<void> resume() {
    if (_isDisposed || (!_isPaused && _controller != null)) {
      return Future<void>.value();
    }
    return start();
  }

  void _onFrame(
    MrzDeviceCameraController owner,
    CameraImage frame,
    int generation,
  ) {
    if (!_isCurrent(generation) || _controller != owner || _isAnalyzing) {
      return;
    }
    final now = DateTime.now();
    final last = _lastAnalysisAt;
    if (last != null && now.difference(last) < _analysisInterval) return;

    final input = _inputImage(owner, frame);
    if (input == null) return;
    _lastAnalysisAt = now;
    _isAnalyzing = true;
    unawaited(_analyze(input, generation));
  }

  Future<void> _analyze(
    ({InputImage image, double meanLuminance}) input,
    int generation,
  ) async {
    try {
      final observation = await _scanner.analyzeLiveFrame(
        input.image,
        meanLuminance: input.meanLuminance,
      );
      if (_isCurrent(generation)) _observations.add(observation);
    } on ChipReadException catch (error, stackTrace) {
      if (_isCurrent(generation)) {
        _observations.addError(error, stackTrace);
        unawaited(pause());
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  ({InputImage image, double meanLuminance})? _inputImage(
    MrzDeviceCameraController controller,
    CameraImage frame,
  ) {
    if (frame.planes.length != 1) return null;

    final format = InputImageFormatValue.fromRawValue(frame.format.raw as int);
    final expected = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;
    if (format != expected) return null;

    final rotation = rotationForCamera(controller, isIOS: Platform.isIOS);
    if (rotation == null) return null;
    final plane = frame.planes.single;
    final cropped = MrzFrameCropper.crop(
      bytes: plane.bytes,
      rawWidth: frame.width,
      rawHeight: frame.height,
      bytesPerRow: plane.bytesPerRow,
      format: format!,
      rotation: rotation,
    );
    if (cropped == null) return null;

    return (
      image: InputImage.fromBytes(
        bytes: cropped.bytes,
        metadata: InputImageMetadata(
          size: Size(cropped.rawWidth.toDouble(), cropped.rawHeight.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: cropped.bytesPerRow,
        ),
      ),
      meanLuminance: cropped.meanLuminance,
    );
  }

  /// Capture portrait kilitliyken cihazın anlık yönü OCR dönüşünü değiştirmez.
  @visibleForTesting
  static InputImageRotation? rotationForCamera(
    MrzDeviceCameraController controller, {
    required bool isIOS,
  }) {
    if (isIOS) {
      return InputImageRotationValue.fromRawValue(controller.sensorOrientation);
    }

    final deviceRotation = _orientationDegrees[_captureOrientation];
    if (deviceRotation == null) return null;
    final degrees = controller.lensDirection == CameraLensDirection.front
        ? (controller.sensorOrientation + deviceRotation) % 360
        : (controller.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees);
  }

  Future<void> _disposeCandidate(MrzDeviceCameraController? controller) async {
    if (controller == null) return;
    if (controller.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } on Object {
        // Yerli kaynakları yine de bırakmak için dispose'a devam edilir.
      }
    }
    await controller.dispose();
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

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationTail.then((_) => operation());
    _operationTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  @override
  Future<void> dispose() {
    if (_isDisposed) return _operationTail;
    _isDisposed = true;
    _isPaused = true;
    _generation++;
    return _enqueue(_disposeResources);
  }

  Future<void> _disposeResources() async {
    await _releaseController();
    await _scanner.dispose();
    await _observations.close();
  }
}
