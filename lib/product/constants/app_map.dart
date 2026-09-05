import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Harita ekranlarının paylaştığı konum sabitleri.
///
/// Koala bugün yalnızca İstanbul'da hizmet veriyor; backend de adres
/// kaydını bu alanın dışında reddediyor. Değerler hem iş arayanın keşif
/// haritasında hem de işverenin konum seçicisinde kullanıldığı için
/// koordinatı ekrana gömmek yerine buradan okunur.
class AppMap {
  /// Kullanıcı konumu yokken haritanın açıldığı nokta (Sultanahmet).
  ///
  /// Şehir merkezine yakın olduğu için ilk karede ilan pinlerinin çoğu
  /// görüş alanına giriyor. Hizmet alanı dışında bir varsayılan (örneğin
  /// Ankara) harita boş görünmesine yol açtığı için kullanılmaz.
  static const LatLng istanbulCenter = LatLng(41.008238, 28.978359);

  /// Backend'in kabul ettiği İstanbul hizmet alanı.
  ///
  /// Pin bu dikdörtgenin dışına taşındığında kayıt sunucuda
  /// reddedileceği için kamera ve pin hareketi aynı sınırla kısıtlanır.
  static final LatLngBounds istanbulBounds = LatLngBounds(
    southwest: const LatLng(40.80, 28.55),
    northeast: const LatLng(41.35, 29.50),
  );

  /// Şehir ölçeğinde başlangıç yakınlaştırması; sokak seviyesine inmek
  /// kullanıcıya bırakılır.
  static const double initialZoom = 15;
}
