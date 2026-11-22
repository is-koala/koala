import 'package:koala/product/network/api_config.dart';

/// İlanın paylaşılabilir bağlantısı: web'in ilan sayfası. Uygulaması olanda
/// sistem bağlantıyı uygulamaya verir (`/shared-job`).
class JobShareLink {
  const JobShareLink._();

  /// Paylaşım hep canlı web'e: dev'in `WEB_HOSTS`'u boş, staging de canlıyı
  /// kullanıyor.
  static const String canonicalHost = 'iskoala.com';

  /// `AppLinkDestination.httpsPathPrefixes` ile aynı önek.
  static const String pathPrefix = '/is-ilanlari/';

  static Uri forJob(String jobId, {Set<String>? webHosts}) {
    final hosts = webHosts ?? ApiConfig.webHosts;
    final host = hosts.contains(canonicalHost) || hosts.isEmpty
        ? canonicalHost
        : hosts.first;
    return Uri(scheme: 'https', host: host, path: '$pathPrefix$jobId');
  }

  static String message({required String title, required Uri link}) =>
      '$title\n$link';
}
