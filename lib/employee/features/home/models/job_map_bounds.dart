/// Haritanın görünen alanı; eklentiden bağımsız tip ki mantık eklentisiz
/// sınansın.
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

  /// Google Maps böyle kutuda `minLongitude`'u büyük döndürüyor.
  bool get wrapsAntimeridian => minLongitude > maxLongitude;

  /// Sarmalayan kutuda **her zaman `false`**: yanlış "istek gerekmez" boş
  /// harita gösterir; gereksiz istek eksik pinden ucuz.
  bool contains(JobMapBounds other) {
    if (wrapsAntimeridian || other.wrapsAntimeridian) return false;

    return minLatitude <= other.minLatitude &&
        maxLatitude >= other.maxLatitude &&
        minLongitude <= other.minLongitude &&
        maxLongitude >= other.maxLongitude;
  }

  /// Kenarlar dahil; meridyeni aşan kutuda iki parçadan biri yeter.
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
