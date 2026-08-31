/// Uygulamanın kendisi hakkındaki sabitler.
class AppInfo {
  const AppInfo._();

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
  static const String version = '1.0.0';

  /// Play Store paket adı. Zorunlu güncelleme ekranındaki mağaza düğmesi
  /// buna bağlı.
  ///
  /// **Boş** — `android/app/build.gradle.kts` hâlâ Flutter'ın varsayılan
  /// `com.example.koala` değerini taşıyor, yani uygulama yayınlanmadı.
  /// Gerçek paket adı belli olunca buraya yazılmalı; boş kaldığı sürece
  /// ekran mağaza düğmesini çizmiyor, yalnızca metni gösteriyor.
  static const String androidPackageId = '';

  /// App Store'daki sayısal uygulama kimliği (`id123456789`'daki sayı).
  /// Apple uygulamayı kaydederken veriyor; o zamana kadar boş.
  static const String iosAppStoreId = '';
}
