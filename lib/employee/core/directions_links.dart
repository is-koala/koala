import 'package:koala/product/utils/coordinate_precision.dart';

/// Yol tarifinin hedefi: işyerinin koordinatı ve işin başlangıç anı.
///
/// Yalnızca **hedef** taşıyor. Çalışanın kendi konumu hiçbir bağlantıya
/// yazılmıyor; harita uygulaması başlangıcı cihazdan kendisi okuyor
/// (is-koala/koala#188 — konum verisi cihaz dışına çıkmaz).
class DirectionsTarget {
  const DirectionsTarget({
    required this.latitude,
    required this.longitude,
    this.arrival,
  });

  final double latitude;
  final double longitude;

  /// Varış hedefi = işin başlangıcı. Bağlantıya yazılmıyor (bkz.
  /// [DirectionsLinks]); ekranda kullanıcıya söyleniyor.
  final DateTime? arrival;
}

/// iOS'ta seçim sayfasının iki şıkkı. Android'de seçim yok: evrensel
/// bağlantı sistem seçicisine düşüyor.
enum DirectionsApp {
  apple('Apple Haritalar'),
  google('Google Haritalar');

  const DirectionsApp(this.label);

  final String label;
}

/// Harici harita uygulamalarına toplu taşıma yol tarifi derin bağlantıları.
///
/// Uygulama içinde rota çizilmiyor, Directions API çağrılmıyor (karar
/// 14.09.2026, is-koala/koala#188): hedef koordinat hazır bir bağlantıyla
/// harita uygulamasına devrediliyor.
///
/// **Varış saati bağlantıda yok.** Üç şemanın belgelenmiş parametre kümesi
/// de yalnız hedef ve ulaşım modunu tanıyor:
/// - Google `api=1` (`/maps/dir/`): `destination`, `travelmode`, `origin`,
///   `waypoints`, `dir_action` — `arrival_time` diye bir parametre yok,
///   yazılırsa sessizce düşer.
/// - Google `comgooglemaps://`: `daddr`, `saddr`, `directionsmode`,
///   `center`, `zoom` — saat parametresi yok.
/// - Apple `maps://`: `daddr`, `saddr`, `dirflg`, `t`, `ll`, `q` — saat yok.
/// Belgelenmemiş eski Google parametreleri (`ttype=arr&time=`) güvenilir
/// değil ve `api=1` ile birleşmiyor. Bu yüzden bağlantıya hiç saat yazılmıyor
/// — kullanıcıyı "saati ayarladım" sanrısına düşürmemek için — ve işin
/// başlangıcı düğmenin altında metinle söyleniyor. `directions_links_test`
/// bu kararı sabitliyor.
abstract final class DirectionsLinks {
  /// Apple Haritalar; `dirflg=r` toplu taşıma.
  static Uri appleMaps(DirectionsTarget target) =>
      Uri.parse('maps://?daddr=${_coordinate(target)}&dirflg=r');

  /// Google Haritalar uygulaması (iOS şeması); yoksa [googleMapsWeb].
  static Uri googleMapsApp(DirectionsTarget target) => Uri.parse(
    'comgooglemaps://?daddr=${_coordinate(target)}&directionsmode=transit',
  );

  /// Google Haritalar evrensel bağlantısı: Android'de intent seçici, iOS'ta
  /// uygulama yoksa tarayıcı.
  static Uri googleMapsWeb(DirectionsTarget target) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${_coordinate(target)}&travelmode=transit',
  );

  /// `lat,lng` — altı ondalık (sunucuyla aynı kesinlik), ondalık ayırıcı
  /// yerelden bağımsız nokta. Virgül sorgu diliminde geçerli bir karakter;
  /// kaçırılmıyor ki bağlantı üç uygulamanın da belgelediği biçimde kalsın.
  static String _coordinate(DirectionsTarget target) {
    final latitude = CoordinatePrecision.round6(target.latitude);
    final longitude = CoordinatePrecision.round6(target.longitude);
    return '${latitude.toStringAsFixed(CoordinatePrecision.fractionDigits)},'
        '${longitude.toStringAsFixed(CoordinatePrecision.fractionDigits)}';
  }
}
