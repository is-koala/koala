import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ortam ve API hedefi açıkça seçilmeden ağ istemcisi kurulmaz.
class ApiConfig {
  static const Set<String> _flavors = {'dev', 'staging', 'production'};

  static const Map<String, String> _appUrlSchemes = {
    'dev': 'koala-dev',
    'staging': 'koala-staging',
    'production': 'koala',
  };

  static String resolveBaseUrl({
    required String? flavor,
    required String configuredUrl,
  }) {
    if (!_flavors.contains(flavor)) {
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

  /// Sunucudaki `MinimumAppVersionFilter`'ın okuduğu sürüm başlığı.
  static const String appVersionHeader = 'X-App-Version';

  /// API kökü; sonunda `/` yok, yollar `/` ile başlıyor.
  static String get baseUrl => resolveBaseUrl(
    flavor: appFlavor,
    configuredUrl: const String.fromEnvironment('API_BASE_URL'),
  );

  /// Flavor'ın uygulama bağlantısı şeması; native eşlemeyle aynı, böylece
  /// staging'e gelen production bağlantısı kabul edilmez.
  static String get appUrlScheme => resolveAppUrlScheme(flavor: appFlavor);

  @visibleForTesting
  static String resolveAppUrlScheme({required String? flavor}) {
    final scheme = _appUrlSchemes[flavor];
    if (scheme == null) {
      throw StateError('Uygulama ortamı seçilmedi. --flavor kullanmalısın.');
    }
    return scheme;
  }

  /// Flavor'ın doğrulanmış web hostları; `https://<host>/...` bağlantıları
  /// yalnız bunlardan kabul edilir. `config/<flavor>.json` → `WEB_HOSTS`;
  /// Android manifest ve iOS entitlements aynı listeyi kullanıyor (#155).
  static Set<String> get webHosts => resolveWebHosts(
    flavor: appFlavor,
    configuredHosts: const String.fromEnvironment('WEB_HOSTS'),
  );

  /// `WEB_HOSTS`'u host kümesine çevirir. Yalnız çıplak alan adı; boş liste
  /// yalnız dev'de geçerli.
  @visibleForTesting
  static Set<String> resolveWebHosts({
    required String? flavor,
    required String configuredHosts,
  }) {
    if (!_flavors.contains(flavor)) {
      throw StateError('Uygulama ortamı seçilmedi. --flavor kullanmalısın.');
    }
    final hosts = configuredHosts
        .split(',')
        .map((host) => host.trim())
        .where((host) => host.isNotEmpty)
        .toSet();
    for (final host in hosts) {
      // Şema, port, yol ya da büyük harf taşıyan giriş geri okununca kendisine
      // eşit çıkmaz.
      final uri = Uri.tryParse('https://$host/');
      if (uri == null || uri.host != host) {
        throw StateError('WEB_HOSTS yalnız küçük harfli alan adları taşır.');
      }
    }
    if (hosts.isEmpty && flavor != 'dev') {
      throw StateError('WEB_HOSTS bu ortam için boş olamaz.');
    }
    return hosts;
  }

  /// Yanlış yapılandırma ilk ağ isteğine veya oturum yüklemeye ertelenmez.
  static void validateBuildConfiguration() {
    resolveBaseUrl(
      flavor: appFlavor,
      configuredUrl: const String.fromEnvironment('API_BASE_URL'),
    );
    resolveAppUrlScheme(flavor: appFlavor);
    resolveWebHosts(
      flavor: appFlavor,
      configuredHosts: const String.fromEnvironment('WEB_HOSTS'),
    );
  }

  /// Harici uygulamaya verilebilecek sunucu kaynaklı adres şemaları: `intent:`,
  /// `file:` ve şifresiz `http` girmez (`http` yalnız dev'de).
  static Set<String> get externalUrlSchemes =>
      resolveExternalUrlSchemes(flavor: appFlavor);

  @visibleForTesting
  static Set<String> resolveExternalUrlSchemes({required String? flavor}) =>
      flavor == 'dev' ? const {'https', 'http'} : const {'https'};

  /// STOMP adresi; [baseUrl]'den türüyor (`http`→`ws`, `https`→`wss`).
  static String get websocketUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: scheme, path: websocketPath).toString();
  }

  static const String websocketPath = '/ws';

  /// Mobil şebekede ilk el sıkışma uzayabildiği için 10 sn'den cömert.
  static const Duration connectTimeout = Duration(seconds: 15);

  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Backend hata mesajlarını Türkçe döndürsün diye.
  static const String acceptLanguage = 'tr';
}
