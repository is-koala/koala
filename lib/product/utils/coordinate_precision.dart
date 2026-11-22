/// Sunucuya giden koordinatın kesinliği: backend `@Digits(integer = 2, fraction
/// = 6)` uyguluyor, ham `LatLng` ise daha fazla ondalık taşıyor. Web'deki
/// `roundCoordinate` ile aynı sözleşme.
abstract final class CoordinatePrecision {
  /// Altı ondalık ≈ 11 cm.
  static const int fractionDigits = 6;

  static const int _scale = 1000000;

  /// Altı ondalığa yuvarlar; sıfıra yuvarlanan negatif `-0.0` değil `0.0`
  /// döner.
  static double round6(double value) => (value * _scale).round() / _scale;
}
