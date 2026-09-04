import 'package:flutter/services.dart';

/// Ortam ve API hedefi açıkça seçilmeden ağ istemcisi kurulmaz.
class ApiConfig {
  /// Ortam seçimini ağ istemcisi kurulmadan önce doğrular.
  static String resolveBaseUrl({
    required String? flavor,
    required String configuredUrl,
  }) {
    if (!const {'dev', 'staging', 'production'}.contains(flavor)) {
      throw StateError('Uygulama ortamı seçilmedi. --flavor kullanmalısın.');
    }
    final uri = Uri.tryParse(configuredUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && !(flavor == 'dev' && uri.scheme == 'http'))) {
      throw StateError(
        'API_BASE_URL bu ortam için geçerli bir kök adres değil.',
      );
    }
    return uri.replace(path: '').toString();
  }

  /// İstemci sürümünün gittiği başlık. Sunucudaki
  /// `MinimumAppVersionFilter` bu adı okuyor.
  static const String appVersionHeader = 'X-App-Version';

  /// API'nin kök adresi. Sonunda `/` yok; yol sabitleri `/` ile başlıyor.
  static String get baseUrl => resolveBaseUrl(
    flavor: appFlavor,
    configuredUrl: const String.fromEnvironment('API_BASE_URL'),
  );

  /// Yanlış yapılandırma ilk ağ isteğine veya oturum yüklemeye ertelenmez.
  static void validateBuildConfiguration() {
    resolveBaseUrl(
      flavor: appFlavor,
      configuredUrl: const String.fromEnvironment('API_BASE_URL'),
    );
  }

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
