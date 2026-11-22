import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Harita ekranlarının paylaştığı konum sabitleri. Koala yalnız İstanbul'da;
/// backend bu alanın dışındaki adresi reddediyor.
class AppMap {
  /// Konum yokken açılış noktası (Sultanahmet); ilk karede pinlerin çoğu
  /// görünüyor.
  static const LatLng istanbulCenter = LatLng(41.008238, 28.978359);

  /// Backend'in kabul ettiği alan; kamera ve pin bununla sınırlı.
  static final LatLngBounds istanbulBounds = LatLngBounds(
    southwest: const LatLng(40.80, 28.55),
    northeast: const LatLng(41.35, 29.50),
  );

  static const double initialZoom = 15;

  /// Bilinen bir noktaya odaklanırken: bina numarası okunacak, cadde bağlamı
  /// kaybolmayacak kadar yakın.
  static const double streetZoom = 17;
}
