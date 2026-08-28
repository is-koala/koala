/// Backend'e bağlanırken kullanılan sabitler.
///
/// Adres koda gömülü değil: varsayılan yayın sunucusu, yerelde çalışırken
/// `--dart-define` ile eziliyor.
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
/// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS simulator
/// ```
class ApiConfig {
  /// API'nin kök adresi. Sonunda `/` yok; yol sabitleri `/` ile başlıyor.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.iskoala.com',
  );

  /// STOMP/WebSocket adresi.
  ///
  /// [baseUrl]'den türetiliyor: şema `http` → `ws`, `https` → `wss`.
  /// Yol backend'deki `realtime.endpoint` ayarıyla aynı olmalı.
  static String get websocketUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: scheme, path: websocketPath).toString();
  }

  /// Backend'in STOMP uç noktası (`RealtimeProperties.endpoint`).
  static const String websocketPath = '/ws';

  /// Bağlantı kurulmasını bekleme süresi. Mobil şebekede ilk el sıkışma
  /// uzayabildiği için varsayılan 10 sn'den biraz cömert tutuldu.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Yanıtın tamamının okunmasını bekleme süresi.
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Backend hata mesajlarını `messages_tr.properties`'ten döndürsün diye
  /// her isteğe eklenen dil başlığı. Uygulama tek dilli olduğu sürece sabit.
  static const String acceptLanguage = 'tr';
}
