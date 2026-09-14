import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Harita SDK'sı bu derlemede kullanılabilir mi.
///
/// iOS'ta `MAPS_API_KEY` boşsa `AppDelegate` `GMSServices.provideAPIKey`
/// çağırmıyor ve ilk `GoogleMap` oluşur oluşmaz SDK `GMSServicesException`
/// fırlatıp uygulamayı **çökertiyor**; Android'de anahtar boşken harita
/// yalnız boş kalıyor (is-koala/koala#172). Yerel taraf anahtarı verip
/// vermediğini tek bir kanaldan söylüyor: uygulama açılışında [read] ile bir
/// kez okunur, `Provider` ile dağıtılır ve harita çizen her ekran çizmeden
/// önce [of] ile sorar. Bayrak kapalıysa ekran haritanın yerine Türkçe yer
/// tutucu gösterir.
///
/// Değer çalışma zamanında değişmez; anahtar derlemeye girer, uygulama
/// açıkken gelmez.
class MapsAvailability {
  const MapsAvailability({required this.isAvailable});

  /// Yerel tarafın cevap verdiği kanal. iOS'ta `AppDelegate`, Android'de
  /// `MainActivity` kaydediyor; ikisi de `isAvailable` metoduna `bool` döner.
  static const MethodChannel channel = MethodChannel(
    'com.iskoala.koala/maps_availability',
  );

  /// Harita çizilebilir: yerel taraf Maps SDK'sına anahtarı verdi.
  final bool isAvailable;

  /// Yerel taraftan bir kez okur.
  ///
  /// Kanal cevap vermezse (`MissingPluginException`, eksik kayıt, `null`)
  /// harita **kapalı** sayılır: çökmeyi önlemek bu sınıfın tek işi, o yüzden
  /// belirsizlikte kapalı kalıyor. Anahtar yerindeyken yer tutucu görünmesi
  /// gözle fark edilir; çökme ise kullanıcıyı uygulamadan atar.
  static Future<MapsAvailability> read() async {
    try {
      final available = await channel.invokeMethod<bool>('isAvailable');
      return MapsAvailability(isAvailable: available ?? false);
    } on PlatformException {
      return const MapsAvailability(isAvailable: false);
    } on MissingPluginException {
      return const MapsAvailability(isAvailable: false);
    }
  }

  /// Ağaçtaki değeri okur. Sağlayıcı yoksa `Provider` kendi hatasını
  /// fırlatır: harita çizen bir ekranın bayrağı sormadan açılması, kapalı
  /// bayrağın sessizce atlanması demek olurdu.
  static MapsAvailability of(BuildContext context) =>
      Provider.of<MapsAvailability>(context, listen: false);
}
