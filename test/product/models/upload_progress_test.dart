import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/upload_progress.dart';

void main() {
  group('uploadFraction', () {
    test('oranı verir', () {
      expect(uploadFraction(0, 100), 0.0);
      expect(uploadFraction(25, 100), 0.25);
      expect(uploadFraction(100, 100), 1.0);
    });

    test('toplam bilinmiyorsa null (belirsiz çubuk)', () {
      expect(uploadFraction(10, 0), isNull);
      expect(uploadFraction(10, -1), isNull);
    });

    test('1\'i aşmaz', () {
      expect(uploadFraction(500, 120), 1.0);
    });
  });
}
