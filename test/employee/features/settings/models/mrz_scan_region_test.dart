import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_region.dart';

void main() {
  test('dikey önizleme kadrajı 3.2 oranını tek normalize modelden üretir', () {
    const size = Size(720, 1280);

    final region = MrzScanRegion.pixelRegion(size);

    expect(region.width / region.height, closeTo(3.2, 0.001));
    expect(region.center.dx, closeTo(size.width * 0.5, 0.001));
    expect(region.center.dy, closeTo(size.height * 0.575, 0.001));
  });

  test('90 derece Android karesinde önizleme ROI ham koordinata çevrilir', () {
    const rawSize = Size(8, 12);

    final region = MrzScanRegion.rawPixelRegion(
      rawSize: rawSize,
      rotation: InputImageRotation.rotation90deg,
      evenCoordinates: true,
    );

    expect(region.left, 2);
    expect(region.top, 0);
    expect(region.right, 8);
    expect(region.bottom, 12);
  });

  test('bütün sensör dönüşleri aynı dik önizleme kadrajına geri döner', () {
    const rawSize = Size(720, 1280);
    for (final rotation in InputImageRotation.values) {
      final raw = MrzScanRegion.rawPixelRegion(
        rawSize: rawSize,
        rotation: rotation,
        evenCoordinates: true,
      );
      final uprightSize =
          rotation == InputImageRotation.rotation90deg ||
              rotation == InputImageRotation.rotation270deg
          ? const Size(1280, 720)
          : rawSize;
      final expected = MrzScanRegion.pixelRegion(uprightSize);
      final actual = _toUpright(raw, rawSize, rotation);

      expect(actual.left, closeTo(expected.left, 2));
      expect(actual.top, closeTo(expected.top, 2));
      expect(actual.right, closeTo(expected.right, 2));
      expect(actual.bottom, closeTo(expected.bottom, 2));
    }
  });

  test('NV21 kare OCR öncesi ROI alanına gerçekten kırpılır', () {
    const width = 8;
    const height = 12;
    final bytes = Uint8List(width * height * 3 ~/ 2);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        bytes[(y * width) + x] = (y * 10) + x;
      }
    }
    for (var index = width * height; index < bytes.length; index++) {
      bytes[index] = 200;
    }

    final cropped = MrzFrameCropper.crop(
      bytes: bytes,
      rawWidth: width,
      rawHeight: height,
      bytesPerRow: width,
      format: InputImageFormat.nv21,
      rotation: InputImageRotation.rotation90deg,
    );

    expect(cropped, isNotNull);
    expect(cropped!.rawWidth, 6);
    expect(cropped.rawHeight, 12);
    expect(cropped.bytesPerRow, 6);
    expect(cropped.bytes.length, 6 * 12 * 3 ~/ 2);
    expect(cropped.bytes.first, 2);
    expect(cropped.bytes[5], 7);
    expect(cropped.bytes[6], 12);
    expect(cropped.bytes.where((value) => value == 0), isEmpty);
  });

  test('BGRA satır dolgusu kırpılmış OCR girdisine taşınmaz', () {
    const width = 10;
    const height = 10;
    const stride = 48;
    final bytes = Uint8List(stride * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * stride) + (x * 4);
        bytes[offset] = x;
        bytes[offset + 1] = y;
        bytes[offset + 2] = 100;
        bytes[offset + 3] = 255;
      }
    }

    final cropped = MrzFrameCropper.crop(
      bytes: bytes,
      rawWidth: width,
      rawHeight: height,
      bytesPerRow: stride,
      format: InputImageFormat.bgra8888,
      rotation: InputImageRotation.rotation0deg,
    );

    expect(cropped, isNotNull);
    expect(cropped!.bytesPerRow, cropped.rawWidth * 4);
    expect(cropped.bytes.length, cropped.bytesPerRow * cropped.rawHeight);
    expect(cropped.bytes[3], 255);
  });
}

Rect _toUpright(Rect raw, Size rawSize, InputImageRotation rotation) =>
    switch (rotation) {
      InputImageRotation.rotation0deg => raw,
      InputImageRotation.rotation90deg => Rect.fromLTRB(
        rawSize.height - raw.bottom,
        raw.left,
        rawSize.height - raw.top,
        raw.right,
      ),
      InputImageRotation.rotation180deg => Rect.fromLTRB(
        rawSize.width - raw.right,
        rawSize.height - raw.bottom,
        rawSize.width - raw.left,
        rawSize.height - raw.top,
      ),
      InputImageRotation.rotation270deg => Rect.fromLTRB(
        raw.top,
        rawSize.width - raw.right,
        raw.bottom,
        rawSize.width - raw.left,
      ),
    };
