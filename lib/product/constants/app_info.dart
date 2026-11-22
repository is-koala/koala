class AppInfo {
  const AppInfo._();

  /// Kullanıcının sıkıştığında yazacağı adres (sürüm kapısı, çip doğrulaması).
  static const String supportEmail = 'destek@iskoala.com';

  /// İstemci sürümü (`X-App-Version`); sunucu en düşük sürümün altındaysa `426`
  /// döndürüyor. `pubspec.yaml`'daki `version` ile elle eşit tutulmalı.
  static const String version = '1.1.1';

  /// Play Store paket adı (ADR-0006); zorunlu güncelleme düğmesi buna bağlı.
  static const String androidPackageId = 'com.iskoala.koala';

  /// App Store kimliğinin sayısı; Apple kaydedene kadar boş.
  static const String iosAppStoreId = '';
}
