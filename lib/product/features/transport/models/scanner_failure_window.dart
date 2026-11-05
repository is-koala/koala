/// QR çözücünün "çalışmıyor" kararını veren zaman pencereli sayaç
/// (is-koala/koala#217).
///
/// Android'de barkod modeli Play Services'tan geliyor; model yoksa ya da
/// inmediyse her kare hata döner. Arada bir düşen tek tük kare hatası ise
/// sağlam bir cihazda da olur. Bu yüzden karar "üst üste N hata" değil,
/// "[window] içinde [threshold] hata": seyrek hatalar birikip yanlışlıkla
/// "QR okuyucu hazırlanamadı" dedirtmez. Başarılı bir okuma sayacı sıfırlar.
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

  /// Hatayı kaydeder; eşik bu pencerede aşıldıysa `true`.
  bool record(DateTime now) {
    _failures
      ..removeWhere((at) => now.difference(at) > window)
      ..add(now);
    return _failures.length >= threshold;
  }

  /// Başarılı okuma: geçmiş hatalar unutulur.
  void reset() => _failures.clear();
}
