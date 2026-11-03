/// Haritanın görünen alanı.
///
/// `google_maps_flutter`'ın `LatLngBounds`'undan ayrı bir tip: sunucunun
/// beklediği dört alan burada zaten ayrı ayrı duruyor ve harita eklentisine
/// bağlı olmadığı için görünen alan mantığı eklenti olmadan sınanabiliyor.
class JobMapBounds {
  const JobMapBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  /// 180. meridyeni aşan kutu. Google Maps böyle bir kutuda `minLongitude`'u
  /// `maxLongitude`'dan büyük döndürüyor.
  bool get wrapsAntimeridian => minLongitude > maxLongitude;

  /// [other] tümüyle bu kutunun içinde mi.
  ///
  /// Sarmalayan kutularda **her zaman `false`**: düz karşılaştırma orada
  /// yanlış sonuç verir ve "istek atmaya gerek yok" kararı yanlış tarafa
  /// düşerse kullanıcı boş harita görür. Gereksiz bir istek, eksik pinden
  /// ucuz.
  bool contains(JobMapBounds other) {
    if (wrapsAntimeridian || other.wrapsAntimeridian) return false;

    return minLatitude <= other.minLatitude &&
        maxLatitude >= other.maxLatitude &&
        minLongitude <= other.minLongitude &&
        maxLongitude >= other.maxLongitude;
  }

  /// Nokta kutunun içinde mi (kenarlar dahil). 180. meridyeni aşan kutuda
  /// boylam iki parçadan birine düşmesi yetiyor.
  bool containsPoint(double latitude, double longitude) {
    if (latitude < minLatitude || latitude > maxLatitude) return false;
    if (wrapsAntimeridian) {
      return longitude >= minLongitude || longitude <= maxLongitude;
    }
    return longitude >= minLongitude && longitude <= maxLongitude;
  }

  @override
  bool operator ==(Object other) =>
      other is JobMapBounds &&
      other.minLatitude == minLatitude &&
      other.maxLatitude == maxLatitude &&
      other.minLongitude == minLongitude &&
      other.maxLongitude == maxLongitude;

  @override
  int get hashCode =>
      Object.hash(minLatitude, maxLatitude, minLongitude, maxLongitude);
}
