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
}
