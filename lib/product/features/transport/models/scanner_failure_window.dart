/// QR çözücünün "çalışmıyor" kararı (#217). Android'de model Play Services'tan
/// geliyor, yoksa her kare hata döner; tek tük hata ise sağlam cihazda da olur.
/// Karar "[window] içinde [threshold] hata"; başarılı okuma sıfırlar.
class ScannerFailureWindow {
  ScannerFailureWindow({
    this.threshold = defaultThreshold,
    this.window = defaultWindow,
  });

  static const int defaultThreshold = 3;
  static const Duration defaultWindow = Duration(seconds: 10);

  final int threshold;
  final Duration window;
  final List<DateTime> _failures = [];

  /// Eşik aşıldıysa `true`.
  bool record(DateTime now) {
    _failures
      ..removeWhere((at) => now.difference(at) > window)
      ..add(now);
    return _failures.length >= threshold;
  }

  void reset() => _failures.clear();
}
