import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Cihazı sunucuya tanıtan bilgiler.
///
/// Backend oturumu cihaza bağlıyor: `SessionAuthFilter` her istekte cihazı
/// bulup oturumun cihazıyla karşılaştırıyor, tutmazsa oturumu kapatıyor.
/// Cihaz artık **`X-Device-Id` başlığından** çözülüyor — `(kullanıcı,
/// clientDeviceId)` çiftiyle aranıyor — bu yüzden kimliğin kurulum boyunca
/// aynı kalması şart. `User-Agent` yalnızca cihazın adını ve tipini
/// yazdırmaya yarıyor, kimlik değil.
///
/// Başlık gönderilmezse backend eski davranışına, yani User-Agent'ı
/// ayrıştırmaya düşüyor; o yolda aynı kullanıcının aynı platformdaki bütün
/// kurulumları tek cihaz sayılıyor. Yani başlığı göndermek zorunlu değil ama
/// göndermemek çoklu cihaz desteğini kaybettiriyor.
class DeviceIdentity {
  DeviceIdentity._internal();

  static final DeviceIdentity _instance = DeviceIdentity._internal();

  factory DeviceIdentity() => _instance;

  /// Testlerde her senaryonun temiz bir örnekle başlaması için. Uygulamada
  /// tek örnek kullanılıyor, bellek kopyası oturum boyunca yaşıyor.
  @visibleForTesting
  DeviceIdentity.fresh();

  /// Backend'in cihaz kimliğini okuduğu başlık.
  static const String deviceIdHeader = 'X-Device-Id';

  /// Kimliğin saklandığı anahtar. Çıkışta **silinmiyor**: cihaz kimliği
  /// oturuma değil kuruluma ait.
  static const String _deviceIdKey = 'koala_device_id';

  /// Backend'in kabul ettiği karakter kümesi (`[A-Za-z0-9._:-]{8,128}`) ile
  /// uyumlu, okunması kolay bir alfabe.
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  /// Üretilen kimliğin uzunluğu. 32 karakter, çakışma ihtimalini yok sayacak
  /// kadar geniş ve 128'lik sınırın çok altında.
  static const int _idLength = 32;

  /// Aynı oturumda tekrar tekrar disk okumamak için tutulan kopya.
  String? _cachedDeviceId;

  /// Kuruluma özel, kalıcı cihaz kimliği. İlk çağrıda üretilip yazılıyor.
  Future<String> deviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deviceIdKey);
    if (stored != null) {
      _cachedDeviceId = stored;
      return stored;
    }

    final generated = _generateId();
    await prefs.setString(_deviceIdKey, generated);
    _cachedDeviceId = generated;
    return generated;
  }

  static String _generateId() {
    final random = Random.secure();
    return List.generate(
      _idLength,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }

  /// Cihazın sunucuda görünen adını belirleyen başlık. Kimlik taşımıyor,
  /// yalnızca platformu söylüyor.
  static String get userAgent {
    if (Platform.isAndroid) return 'Koala (Android)';
    if (Platform.isIOS) return 'Koala (iOS)';
    return 'Koala';
  }
}
