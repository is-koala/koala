import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Harita SDK'sı bu derlemede kullanılabilir mi.
///
/// iOS'ta `MAPS_API_KEY` boşsa `AppDelegate` `GMSServices.provideAPIKey`
/// çağırmıyor ve ilk `GoogleMap` oluşur oluşmaz SDK `GMSServicesException`
/// fırlatıp uygulamayı **çökertiyor**; Android'de anahtar boşken harita
/// yalnız boş kalıyor (is-koala/koala#172). Yerel taraf anahtarı verip
/// vermediğini tek bir kanaldan söylüyor.
///
/// `main.dart` nesneyi **okumadan** kurar ve `ChangeNotifierProvider` ile
/// dağıtır — `main` senkron kalır, platform okumaları açılış ekranında
/// yapılır (AGENTS.md, *Routing*). `SplashPage._initialize` oturumu
/// okumadan önce [resolve] çağırır; muhafız kullanıcıyı bir harita ekranına
/// yollayana kadar cevap gelmiş olur. Harita çizen her ekran çizmeden önce
/// [of] ile sorar; bayrak kapalıysa `GoogleMap` yerine Türkçe yer tutucu
/// çizer. Değer çözüldükten sonra değişmez; anahtar derlemeye girer,
/// uygulama açıkken gelmez.
class MapsAvailability extends ChangeNotifier {
  /// Henüz okunmamış: kapalı sayılır. Üretim kurucusu.
  MapsAvailability();

  /// Cevabı belli nesne; testler ve `main` dışı kurulumlar için.
  MapsAvailability.resolved({required bool isAvailable})
    : _isAvailable = isAvailable,
      _isResolved = true;

  /// Yerel tarafın cevap verdiği kanal. iOS'ta `AppDelegate`, Android'de
  /// `MainActivity` kaydediyor; ikisi de `isAvailable` metoduna `bool` döner.
  static const MethodChannel channel = MethodChannel(
    'com.iskoala.koala/maps_availability',
  );

  /// Kanal henüz kayıtlı değilse kaç kez daha denenir ve arada ne kadar
  /// beklenir. Yerel kayıt motorla birlikte geliyor; açılış ekranı ilk
  /// kareyi çizdikten sonra sorduğumuz için yarış küçük, ama sıfır değil.
  /// Toplam bekleme bir saniyenin altında kalıyor ki açılış uzamasın.
  static const int missingPluginRetries = 3;
  static const Duration missingPluginRetryDelay = Duration(milliseconds: 300);

  bool _isAvailable = false;
  bool _isResolved = false;

  /// Harita çizilebilir: yerel taraf Maps SDK'sına anahtarı verdi.
  /// Okunmadan önce `false`.
  bool get isAvailable => _isAvailable;

  /// [resolve] tamamlandı mı.
  bool get isResolved => _isResolved;

  /// Yerel taraftan bir kez okur ve dinleyicileri uyandırır; ikinci çağrı
  /// hiçbir şey yapmaz.
  ///
  /// Kanal cevap vermezse harita **kapalı** sayılır: çökmeyi önlemek bu
  /// sınıfın tek işi, o yüzden belirsizlikte kapalı kalıyor. Anahtar
  /// yerindeyken yer tutucu görünmesi gözle fark edilir; çökme ise kullanıcıyı
  /// uygulamadan atar. `MissingPluginException` kayıt yarışı olabileceği için
  /// [missingPluginRetries] kez [retryDelay] arayla yeniden denenir; hâlâ
  /// yoksa nedeni `debugPrint` ile yazılır.
  Future<void> resolve({Duration retryDelay = missingPluginRetryDelay}) async {
    if (_isResolved) return;
    _isAvailable = await _read(retryDelay);
    _isResolved = true;
    notifyListeners();
  }

  static Future<bool> _read(Duration retryDelay) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final available = await channel.invokeMethod<bool>('isAvailable');
        return available ?? false;
      } on MissingPluginException catch (error) {
        if (attempt < missingPluginRetries) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        debugPrint(
          'Harita bayrağı okunamadı, harita kapalı sayılıyor: '
          '${channel.name} kanalı ${attempt + 1} denemede de kayıtlı '
          'değil ($error).',
        );
        return false;
      } on PlatformException catch (error) {
        debugPrint('Harita bayrağı okunamadı, harita kapalı sayılıyor: $error');
        return false;
      }
    }
  }

  /// Ağaçtaki değeri okur. Sağlayıcı yoksa `Provider` kendi hatasını
  /// fırlatır: harita çizen bir ekranın bayrağı sormadan açılması, kapalı
  /// bayrağın sessizce atlanması demek olurdu.
  static MapsAvailability of(BuildContext context) =>
      Provider.of<MapsAvailability>(context, listen: false);
}
