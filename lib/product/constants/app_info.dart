/// Uygulamanın kendisi hakkındaki sabitler.
class AppInfo {
  const AppInfo._();

  /// Kullanıcının bir yere sıkıştığında yazacağı adres. İki ekran kullanıyor:
  /// sürüm kapısı mağaza bağlantısı bilinmediğinde, ve çip doğrulaması
  /// sorunu sürdüğünde.
  static const String supportEmail = 'destek@iskoala.com';

  /// İstemci sürümü; her istekte `X-App-Version` başlığıyla gidiyor.
  ///
  /// Sunucudaki `MinimumAppVersionFilter` bunu ayarlardaki en düşük sürümle
  /// karşılaştırıyor ve altındaysa `426` döndürüyor. Başlık **hiç
  /// gönderilmezse filtre isteği geçiriyor**, yani zorunlu güncelleme
  /// ancak biz bu başlığı gönderdiğimizde çalışabiliyor.
  ///
  /// `pubspec.yaml`'daki `version` ile elle eşit tutuluyor. Doğrusu bunu
  /// paketten okumak (`package_info_plus`) ama o yeni bir bağımlılık;
  /// sürüm yükseltilirken burası da güncellenmeli.
  static const String version = '1.1.1';

  /// Play Store paket adı. Zorunlu güncelleme ekranındaki mağaza düğmesi
  /// buna bağlı.
  ///
  /// Paket adı ADR-0006 ile sabitlenmiştir. Play mağaza kaydı henüz insan
  /// kapısı olsa da paket kimliği artık release sözleşmesinin parçasıdır.
  static const String androidPackageId = 'com.iskoala.koala';

  /// App Store'daki sayısal uygulama kimliği (`id123456789`'daki sayı).
  /// Apple uygulamayı kaydederken veriyor; o zamana kadar boş.
  static const String iosAppStoreId = '';
}
