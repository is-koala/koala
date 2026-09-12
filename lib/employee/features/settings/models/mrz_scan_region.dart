import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Önizleme çerçevesiyle OCR'a giden piksel alanının tek geometrisi.
abstract final class MrzScanRegion {
  static const double aspectRatio = 3.2;
  static const double widthFraction = 0.88;
  static const Offset normalizedCenter = Offset(0.5, 0.575);

  /// MRZ kadrajını verilen dik önizleme alanında piksel olarak döndürür.
  static Rect pixelRegion(Size uprightSize) {
    final width = uprightSize.width * widthFraction;
    final height = width / aspectRatio;
    return Rect.fromCenter(
      center: Offset(
        uprightSize.width * normalizedCenter.dx,
        uprightSize.height * normalizedCenter.dy,
      ),
      width: width,
      height: height,
    ).intersect(Offset.zero & uprightSize);
  }

  /// Dik önizlemedeki kadrajı sensörün ham piksel koordinatına çevirir.
  static Rect rawPixelRegion({
    required Size rawSize,
    required InputImageRotation rotation,
    required bool evenCoordinates,
  }) {
    final uprightSize = _uprightSize(rawSize, rotation);
    final upright = pixelRegion(uprightSize);
    final raw = switch (rotation) {
      InputImageRotation.rotation0deg => upright,
      InputImageRotation.rotation90deg => Rect.fromLTRB(
        upright.top,
        rawSize.height - upright.right,
        upright.bottom,
        rawSize.height - upright.left,
      ),
      InputImageRotation.rotation180deg => Rect.fromLTRB(
        rawSize.width - upright.right,
        rawSize.height - upright.bottom,
        rawSize.width - upright.left,
        rawSize.height - upright.top,
      ),
      InputImageRotation.rotation270deg => Rect.fromLTRB(
        rawSize.width - upright.bottom,
        upright.left,
        rawSize.width - upright.top,
        upright.right,
      ),
    };
    return _integerRegion(raw, rawSize, evenCoordinates: evenCoordinates);
  }

  static Size _uprightSize(Size rawSize, InputImageRotation rotation) {
    final turns =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return turns ? Size(rawSize.height, rawSize.width) : rawSize;
  }

  static Rect _integerRegion(
    Rect region,
    Size bounds, {
    required bool evenCoordinates,
  }) {
    var left = region.left.floor();
    var top = region.top.floor();
    var right = region.right.ceil();
    var bottom = region.bottom.ceil();
    if (evenCoordinates) {
      left = (left ~/ 2) * 2;
      top = (top ~/ 2) * 2;
      right = ((right + 1) ~/ 2) * 2;
      bottom = ((bottom + 1) ~/ 2) * 2;
    }

    left = left.clamp(0, bounds.width.toInt());
    top = top.clamp(0, bounds.height.toInt());
    right = right.clamp(left, bounds.width.toInt());
    bottom = bottom.clamp(top, bounds.height.toInt());
    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
  }
}

/// ML Kit'e verilen, kadraj dışı pikselleri içermeyen bellek içi kare.
class MrzCroppedFrame {
  const MrzCroppedFrame({
    required this.bytes,
    required this.rawWidth,
    required this.rawHeight,
    required this.bytesPerRow,
    required this.meanLuminance,
  });

  final Uint8List bytes;
  final int rawWidth;
  final int rawHeight;
  final int bytesPerRow;
  final double meanLuminance;
}

/// NV21/BGRA kamera karesini OCR'dan önce MRZ kadrajına indirger.
abstract final class MrzFrameCropper {
  static MrzCroppedFrame? crop({
    required Uint8List bytes,
    required int rawWidth,
    required int rawHeight,
    required int bytesPerRow,
    required InputImageFormat format,
    required InputImageRotation rotation,
  }) {
    if (rawWidth <= 0 || rawHeight <= 0 || bytesPerRow <= 0) return null;
    final isNv21 = format == InputImageFormat.nv21;
    final isBgra = format == InputImageFormat.bgra8888;
    if (!isNv21 && !isBgra) return null;

    final region = MrzScanRegion.rawPixelRegion(
      rawSize: Size(rawWidth.toDouble(), rawHeight.toDouble()),
      rotation: rotation,
      evenCoordinates: isNv21,
    );
    final left = region.left.toInt();
    final top = region.top.toInt();
    final width = region.width.toInt();
    final height = region.height.toInt();
    if (width <= 0 || height <= 0) return null;

    return isNv21
        ? _cropNv21(
            bytes: bytes,
            rawHeight: rawHeight,
            sourceStride: bytesPerRow,
            left: left,
            top: top,
            width: width,
            height: height,
          )
        : _cropBgra(
            bytes: bytes,
            sourceStride: bytesPerRow,
            left: left,
            top: top,
            width: width,
            height: height,
          );
  }

  static MrzCroppedFrame? _cropNv21({
    required Uint8List bytes,
    required int rawHeight,
    required int sourceStride,
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    final sourceUvOffset = sourceStride * rawHeight;
    final requiredLength = sourceUvOffset + (sourceStride * (rawHeight ~/ 2));
    if (bytes.length < requiredLength) return null;

    final output = Uint8List(width * height * 3 ~/ 2);
    for (var row = 0; row < height; row++) {
      final source = ((top + row) * sourceStride) + left;
      output.setRange(row * width, (row + 1) * width, bytes, source);
    }
    final outputUvOffset = width * height;
    for (var row = 0; row < height ~/ 2; row++) {
      final source =
          sourceUvOffset + (((top ~/ 2) + row) * sourceStride) + left;
      final target = outputUvOffset + (row * width);
      output.setRange(target, target + width, bytes, source);
    }
    return MrzCroppedFrame(
      bytes: output,
      rawWidth: width,
      rawHeight: height,
      bytesPerRow: width,
      meanLuminance: _meanNv21(output, width * height),
    );
  }

  static MrzCroppedFrame? _cropBgra({
    required Uint8List bytes,
    required int sourceStride,
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    final outputStride = width * 4;
    final lastSourceByte =
        ((top + height - 1) * sourceStride) + ((left + width) * 4);
    if (bytes.length < lastSourceByte) return null;

    final output = Uint8List(outputStride * height);
    for (var row = 0; row < height; row++) {
      final source = ((top + row) * sourceStride) + (left * 4);
      output.setRange(
        row * outputStride,
        (row + 1) * outputStride,
        bytes,
        source,
      );
    }
    return MrzCroppedFrame(
      bytes: output,
      rawWidth: width,
      rawHeight: height,
      bytesPerRow: outputStride,
      meanLuminance: _meanBgra(output),
    );
  }

  static double _meanNv21(Uint8List bytes, int luminanceLength) {
    var sum = 0;
    var samples = 0;
    for (var index = 0; index < luminanceLength; index += 64) {
      sum += bytes[index];
      samples++;
    }
    return samples == 0 ? 0 : sum / samples;
  }

  static double _meanBgra(Uint8List bytes) {
    var sum = 0;
    var samples = 0;
    for (var index = 0; index + 2 < bytes.length; index += 256) {
      sum += (bytes[index] + bytes[index + 1] + bytes[index + 2]) ~/ 3;
      samples++;
    }
    return samples == 0 ? 0 : sum / samples;
  }
}
