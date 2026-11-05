import 'package:koala/product/network/api_config.dart';

/// Bir ilanın paylaşılabilir bağlantısı: web'in herkese açık ilan sayfası.
///
/// Uygulaması olmayan biri bağlantıyı açınca web'deki ilanı görüyor (sayfa
/// başlık, açıklama ve kapak görseliyle bağlantı önizlemesi de üretiyor);
/// uygulaması olan kullanıcıda işletim sistemi bağlantıyı uygulamaya veriyor
/// ve `AppLinkDestination` onu `/shared-job` rotasına çeviriyor.
class JobShareLink {
  const JobShareLink._();

  /// Web'in kanonik hostu. Paylaşılan bağlantı her zaman canlı web'e gider:
  /// geliştirme ortamının `WEB_HOSTS`'u boş, staging de canlı web'i kullanıyor.
  static const String canonicalHost = 'iskoala.com';

  /// Web'in ilan sayfasının yolu; `AppLinkDestination.httpsPathPrefixes`
  /// ile aynı önek.
  static const String pathPrefix = '/is-ilanlari/';

  /// [jobId] için paylaşılacak adres. Çalışan flavor'ın `WEB_HOSTS`'unda
  /// kanonik host varsa o, yoksa kanonik host kullanılıyor.
  static Uri forJob(String jobId, {Set<String>? webHosts}) {
    final hosts = webHosts ?? ApiConfig.webHosts;
    final host = hosts.contains(canonicalHost) || hosts.isEmpty
        ? canonicalHost
        : hosts.first;
    return Uri(scheme: 'https', host: host, path: '$pathPrefix$jobId');
  }

  /// Paylaşım menüsüne giden metin: ilan başlığı ve bağlantı.
  static String message({required String title, required Uri link}) =>
      '$title\n$link';
}
