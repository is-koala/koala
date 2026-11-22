import 'package:koala/product/utils/coordinate_precision.dart';

/// Yol tarifi hedefi. Yalnız **hedef** taşıyor; çalışanın konumu bağlantıya
/// yazılmaz, harita uygulaması cihazdan okur (#188).
class DirectionsTarget {
  const DirectionsTarget({
    required this.latitude,
    required this.longitude,
    this.arrival,
  });

  final double latitude;
  final double longitude;

  /// Bağlantıya yazılmıyor ([DirectionsLinks]); ekranda söyleniyor.
  final DateTime? arrival;
}

/// Android'de seçim yok: evrensel bağlantı sistem seçicisine düşüyor.
enum DirectionsApp {
  apple('Apple Haritalar'),
  google('Google Haritalar');

  const DirectionsApp(this.label);

  final String label;
}

/// Harici harita uygulamalarına toplu taşıma yol tarifi bağlantıları (#188);
/// uygulama içinde rota çizilmiyor.
///
/// **Varış saati bağlantıda yok:** Google `api=1`, `comgooglemaps://` ve Apple
/// `maps://` belgelerinde saat parametresi yok, yazılsa sessizce düşer.
/// Kullanıcı "saati ayarladım" sanmasın diye saat düğmenin altında metinle
/// söyleniyor; `directions_links_test` bunu sabitliyor.
abstract final class DirectionsLinks {
  /// Apple Haritalar; `dirflg=r` toplu taşıma.
  static Uri appleMaps(DirectionsTarget target) =>
      Uri.parse('maps://?daddr=${_coordinate(target)}&dirflg=r');

  static Uri googleMapsApp(DirectionsTarget target) => Uri.parse(
    'comgooglemaps://?daddr=${_coordinate(target)}&directionsmode=transit',
  );

  /// Android'de intent seçici, iOS'ta uygulama yoksa tarayıcı.
  static Uri googleMapsWeb(DirectionsTarget target) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${_coordinate(target)}&travelmode=transit',
  );

  /// Altı ondalık, nokta ayırıcı. Virgül kaçırılmıyor ki üç uygulamanın
  /// belgelediği biçimde kalsın.
  static String _coordinate(DirectionsTarget target) {
    final latitude = CoordinatePrecision.round6(target.latitude);
    final longitude = CoordinatePrecision.round6(target.longitude);
    return '${latitude.toStringAsFixed(CoordinatePrecision.fractionDigits)},'
        '${longitude.toStringAsFixed(CoordinatePrecision.fractionDigits)}';
  }
}
