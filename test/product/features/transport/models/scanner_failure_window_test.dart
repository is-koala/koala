import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/scanner_failure_window.dart';

void main() {
  final start = DateTime.utc(2026, 9, 20, 3, 41);

  test('pencere içinde üç hata QR okuyucuyu çalışmıyor sayar', () {
    final window = ScannerFailureWindow();

    expect(window.record(start), isFalse);
    expect(window.record(start.add(const Duration(seconds: 2))), isFalse);
    expect(window.record(start.add(const Duration(seconds: 4))), isTrue);
  });

  test('seyrek hatalar birikmez', () {
    final window = ScannerFailureWindow();

    expect(window.record(start), isFalse);
    expect(window.record(start.add(const Duration(seconds: 8))), isFalse);
    // İlk hata pencereden çıktı.
    expect(window.record(start.add(const Duration(seconds: 15))), isFalse);
  });

  test('başarılı okuma sayacı sıfırlar', () {
    final window = ScannerFailureWindow();

    window
      ..record(start)
      ..record(start.add(const Duration(seconds: 1)))
      ..reset();

    expect(window.record(start.add(const Duration(seconds: 2))), isFalse);
  });
}
