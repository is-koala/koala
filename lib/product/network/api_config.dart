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

  /// Ortam seçimini ağ istemcisi kurulmadan önce doğrular.
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

  /// İstemci sürümünün gittiği başlık. Sunucudaki
  /// `MinimumAppVersionFilter` bu adı okuyor.
  static const String appVersionHeader = 'X-App-Version';

  /// API'nin kök adresi. Sonunda `/` yok; yol sabitleri `/` ile başlıyor.
  static String get baseUrl => resolveBaseUrl(
    flavor: appFlavor,
    configuredUrl: const String.fromEnvironment('API_BASE_URL'),
  );

  /// Çalışan flavor'ın native uygulama bağlantısı şeması.
  ///
  /// Android manifest ve iOS xcconfig değerleriyle aynı eşlemeyi kullanır;
  /// böylece staging'e gönderilen bir production bağlantısı yanlışlıkla
  /// kabul edilmez.
  static String get appUrlScheme => resolveAppUrlScheme(flavor: appFlavor);

  /// Flavor'ı native uygulama bağlantısı şemasına çevirir.
  @visibleForTesting
  static String resolveAppUrlScheme({required String? flavor}) {
    final scheme = _appUrlSchemes[flavor];
    if (scheme == null) {
      throw StateError('Uygulama ortamı seçilmedi. --flavor kullanmalısın.');
    }
    return scheme;
  }

  /// Flavor'ın doğrulanmış web hostları; `https://<host>/...` bağlantıları
  /// yalnız bu hostlardan kabul edilir.
  ///
  /// Değer `config/<flavor>.json` içindeki `WEB_HOSTS` anahtarından gelir;
  /// Android `build.gradle.kts` aynı dosyayı okuyup manifest'in
  /// `appLinkHost` placeholder'ını doldurur, iOS entitlements aynı listeyi
  /// taşır. Böylece Dart tarafının kabul ettiği host ile işletim sisteminin
  /// uygulamaya verdiği host tek kaynaktan gelir; staging'in production
  /// web'ini kullandığı bugünkü durumda şemadan türetilen sabit liste
  /// `iskoala.com` bağlantısını sessizce reddediyordu (#155).
  static Set<String> get webHosts => resolveWebHosts(
    flavor: appFlavor,
    configuredHosts: const String.fromEnvironment('WEB_HOSTS'),
  );

  /// Virgülle ayrılmış `WEB_HOSTS` değerini doğrulanmış host kümesine çevirir.
  ///
  /// Yalnız çıplak alan adı kabul edilir; dev ortamı public HTTPS host
  /// sahiplenmediği için boş liste yalnız orada geçerlidir.
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
      // Uri host'u normalize eder: şema, port, yol, kullanıcı bilgisi veya
      // büyük harf taşıyan bir giriş geri okunduğunda kendisine eşit çıkmaz.
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
