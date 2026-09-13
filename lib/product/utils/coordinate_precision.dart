/// Sunucuya giden enlem/boylamın kesinliği.
///
/// Backend `ReverseGeocodeRequestDto` ve `AddressPositionRequestDto`
/// koordinatı `@Digits(integer = 2, fraction = 6)` ile doğruluyor: altı
/// ondalıktan fazlası `LATITUDE_PRECISION` / `LONGITUDE_PRECISION` hatasıyla
/// 400 dönüyor. Harita kamerasından gelen `LatLng` ise ham çift kesinlikli
/// değer taşıyor (`41.01234567891` gibi), o yüzden giden her koordinat bu
/// sınıftan geçiyor. Web istemcisindeki `roundCoordinate` ile aynı sözleşme.
abstract final class CoordinatePrecision {
  /// Altı ondalık ≈ 11 cm: adres ve ilan konumu için fazlasıyla yeterli ve
  /// sunucunun kabul ettiği üst sınır.
  static const int fractionDigits = 6;

  static const int _scale = 1000000;

  /// [value] değerini altı ondalığa yuvarlar.
  ///
  /// Sıfıra yuvarlanan negatifler (`-0.0000004`) `-0.0` değil `0.0` döner:
  /// tam sayı sıfırın işareti olmadığı için `0 / _scale` her zaman `0.0`
  /// verir ve JSON'a `-0.0` yazılmaz. Zaten altı ondalıklı değer aynen kalır.
  static double round6(double value) => (value * _scale).round() / _scale;
}
