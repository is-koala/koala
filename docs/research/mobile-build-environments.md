# Mobil derleme ortamları: Flutter 3.47.1

Tarih: 5 Eylül 2026. Kapsam: mobil issue #7'nin ortam kimliği ve açık API hedefi alt işi. Bu not yeni altyapı kararı vermez; [ADR 0006](../adr/0006-use-distinct-mobile-identities-per-environment.md) uygulanır. Yeni paket veya flavor üreticisi gerekmiyor.

## Sonuç

| Flavor / shared scheme | Android application ID / iOS bundle ID | API hedefi |
|---|---|---|
| `dev` | `com.iskoala.koala.dev` | Açıkça verilen yerel backend |
| `staging` | `com.iskoala.koala.staging` | Açıkça verilen `https://api.iskoala.com` |
| `production` | `com.iskoala.koala` | Açıkça verilen hedef; lansman öncesi yayımlanmaz |

Bu eşleme Koala'nın onaylı kararıdır. Flutter flavor'ları hem native kimliği hem Dart tarafındaki ortamı bağlamak için yeterlidir; uygulama içine ikinci bir ortam seçici veya `default-flavor` koymayalım. Eksik ortam/API bilgisi bir internet adresine dönüşmemeli. [Koala ADR 0006](../adr/0006-use-distinct-mobile-identities-per-environment.md), [Flutter Android flavor kılavuzu](https://docs.flutter.dev/deployment/flavors).

## Doğrulanan SDK davranışı

Kurulu SDK `/private/tmp/flutter-3.47.1`, kaynak revizyonu `6655482ec06e547f90abf8ae7590466f4415978d`. Çevrimiçi Flutter belgeleri inceleme tarihinde 3.47.2'yi anlatıyordu; aşağıdaki CLI sonucu ayrıca kurulu 3.47.1'de doğrulandı.

- `package:flutter/services.dart` içindeki `appFlavor`, seçilmiş flavor'ı verir; seçilmediyse `null` olur. [Flutter API](https://api.flutter.dev/flutter/services/appFlavor-constant.html).
- **Headless `flutter test --flavor staging` çalışıyor.** Test komutu flavor seçeneğini tanımlıyor; cihazın flavor desteği kontrolü yalnız integration-test dalında. Flutter seçilen değeri derleme tanımlarına kendisi ekliyor. [Kurulu SDK `test.dart`](https://github.com/flutter/flutter/blob/6655482ec06e547f90abf8ae7590466f4415978d/packages/flutter_tools/lib/src/commands/test.dart#L79), [integration-test kontrolü](https://github.com/flutter/flutter/blob/6655482ec06e547f90abf8ae7590466f4415978d/packages/flutter_tools/lib/src/commands/test.dart#L635).
- **`FLUTTER_APP_FLAVOR` elle verilmez.** Bu isim ortam değişkeninde, `--dart-define` veya `--dart-define-from-file` içinde bulunursa CLI reddeder. Dolayısıyla CI'da elle tanım ekleyerek flavor taklit etmeyelim. [Kurulu SDK `flutter_command.dart`](https://github.com/flutter/flutter/blob/6655482ec06e547f90abf8ae7590466f4415978d/packages/flutter_tools/lib/src/runner/flutter_command.dart#L1498), [rezerve anahtar koruması](https://github.com/flutter/flutter/blob/6655482ec06e547f90abf8ae7590466f4415978d/packages/flutter_tools/lib/src/runner/flutter_command.dart#L1555).
- iOS derlemesinin son aşaması flavor'ı Xcode configuration adından yeniden türetir. Yalnız Dart tanımıyla native kimliği değiştirmek mümkün değildir. [Kurulu SDK `common.dart`](https://github.com/flutter/flutter/blob/6655482ec06e547f90abf8ae7590466f4415978d/packages/flutter_tools/lib/src/build_system/targets/common.dart#L326).

Araştırmada gerçekten çalıştırılan komut:

```bash
/private/tmp/flutter-3.47.1/bin/flutter test --no-pub --flavor staging --dart-define=API_BASE_URL=https://api.iskoala.com test/product/network/api_config_test.dart
```

Sonuç: exit `0`, o andaki **4 test geçti**. Bu, headless CLI desteğini kanıtlar; native flavor kurulumunun veya gerçek sunucu akışının tamamlandığını kanıtlamaz.

## iOS: mevcut hibrit yapıyı koru

`dev`, `staging`, `production` shared scheme'leri mevcut Runner scheme'inden türetilmeli. Her biri `Debug-<env>`, `Profile-<env>`, `Release-<env>` configuration'larını kullanmalı; ortam eki küçük harf olmalı. Run/Test/Analyze → Debug, Profile → Profile, Archive → Release eşleşir. Project, Runner ve RunnerTests configuration listeleri tutarlı tutulur; test bundle ID'si de ilgili app kimliğine göre ayrılır. Podfile'da Debug varyantları `:debug`, Profile/Release varyantları `:release` olarak eşlenir. [Flutter iOS flavor kılavuzu](https://docs.flutter.dev/deployment/flavors-ios).

Koala'nın Runner scheme'inde `xcode_backend.sh prepare` pre-action'ı ve projede `FlutterGeneratedPluginSwiftPackage` bağlantısı zaten var. **Her yeni scheme bunları korumalı.** SPM desteği olmayan eklentiler için CocoaPods kullanılması Flutter'ın desteklediği fallback'tir; bu işte Podfile/SPM silinmez veya plugin kayıt yaşam döngüsü değiştirilmez. [Flutter SPM kılavuzu](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers), [yerel Runner scheme](../../ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme), [yerel Podfile](../../ios/Podfile).

Önerilen en açık xcconfig düzeni: dokuz küçük wrapper; her biri doğru Pods configuration dosyasını, `Generated.xcconfig` dosyasını ve yalnız ilgili ortamın gitignored secret dosyasını içerir. Örneğin Debug-staging wrapper'ı:

```xcconfig
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug-staging.xcconfig"
#include "Generated.xcconfig"
#include? "Secrets.staging.xcconfig"
```

Bu, Koala için uygulama önerisidir. Apple'ın desteklediği `#include?` eksik dosya uyarısını bastırır; aynı ayar tekrar tanımlanırsa son tanım kullanılır. Wrapper target'a resource olarak eklenmemeli. Target Build Settings değerleri xcconfig değerlerini ezebildiğinden bundle ID iki yerde çelişkili bırakılmamalı. [Apple xcconfig belgesi](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project).

Mevcut `Debug.xcconfig`/`Release.xcconfig` genel `Secrets.xcconfig` dosyasını koşulsuz içeriyor. Yeni ortam wrapper'ları bu ortak sırrı da dahil edip başka ortamın Maps anahtarına düşmemeli; `Secrets.*.xcconfig` gitignore kapsamına alınmalı. Secret dosyalarının değerleri bu araştırmada okunmadı. Eksik Maps anahtarıyla build geçmesi, haritanın çalıştığı anlamına gelmez. [Mevcut Debug yapılandırması](../../ios/Flutter/Debug.xcconfig), [mevcut Release yapılandırması](../../ios/Flutter/Release.xcconfig), [Maps araştırması](location-and-map.md).

## Android: tek flavor boyutu

`defaultConfig.applicationId = "com.iskoala.koala"`; `environment` boyutunda `dev` için `.dev`, `staging` için `.staging` suffix; `production` için suffix yok. Debug build type'a ayrıca `.debug` eklenmez: onaylı kimliği değiştirir. Flavor kendi uygulama adını ve Maps manifest placeholder'ını seçebilir. Gradle, flavor ile build type'ı birleştirir; suffix'ler de birleşir. [Android build variants](https://developer.android.com/build/build-variants).

Mevcut `namespace = "com.example.koala"` kodun MainActivity paketiyle birlikte kalabilir: `applicationId` açıkça tanımlandığında namespace'den bağımsızdır. Bu en küçük geçiştir; ileride namespace temizliği ayrı yapılabilir. Üretilmiş manifest'te gerçek paket kimliği ve Activity çözümü kontrol edilmelidir. [Android application ID / namespace ayrımı](https://developer.android.com/build/configure-app-module), [Koala Gradle dosyası](../../android/app/build.gradle.kts).

Koala'nın AGP built-in Kotlin, Java 17, compileSdk 37, Gradle 9.3.1 / AGP 9.1.0 ayarlarını bu işte değiştirmeyelim. Yeni dependency gerekmiyor. Önerilen yerel secret adları `MAPS_API_KEY_DEV`, `MAPS_API_KEY_STAGING`, `MAPS_API_KEY_PRODUCTION`; seçilmiş flavor yalnız kendi anahtarını okumalı, genel `MAPS_API_KEY` fallback'i olmamalı. Bunlar mevcut toolchain üzerine öneridir, yeni anahtar sağlandığı iddiası değildir. [Koala platform kuralları](../../AGENTS.md#platform-toolchain), [Koala Gradle dosyası](../../android/app/build.gradle.kts).

## Oturum izolasyonu ve sınırları

iOS'ta varsayılan Keychain erişim grubu imzalama team ID'si + bundle ID'den oluşur; farklı uygulamalar varsayılan olarak birbirinin öğelerini okuyamaz. Ortak Keychain Sharing/App Group eklemek bu izolasyonu değiştirebilir; ortamları böyle bir grupta birleştirmeyelim. [Apple Keychain erişim grupları](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps).

Android uygulama sandbox'ı uygulamaların iç verilerini ayırır. Bu nedenle farklı application ID'ler aynı cihazda bağımsız uygulama verisiyle çalışabilir. [Android güvenlik kontrol listesi](https://developer.android.com/privacy-and-security/security-tips), [Android build variants](https://developer.android.com/build/build-variants).

Yerel incelemede TokenStorage varsayılan FlutterSecureStorage kullanıyor; ortak access group tanımı bulunmadı. DeviceIdentity ise kurulumun prefs alanında kalıcı bir kimlik saklıyor. Çıkarım: eski `com.example.koala` oturumu yeni kimliğe taşınmamalı; kullanıcı gerçek giriş yapmalı. Ayrı bundle ID, **aynı flavor'ın API origin'i sonradan değiştirildiğinde** eski token'ın yeni origin'e gitmesini tek başına engellemez. API hedefini sabitlemek veya origin değişiminde yalnız ilgili oturumu güvenli biçimde kapatmak ayrıca ele alınmalı; her açılışta cihaz kimliğini sıfırlamak doğru çözüm değildir. [TokenStorage](../../lib/product/network/token_storage.dart), [DeviceIdentity](../../lib/product/network/device_identity.dart).

## Uygulama ve doğrulama sırası

1. ApiConfig public davranış testleri: eksik flavor/API reddi, staging/production HTTPS zorunluluğu, kullanıcı bilgisi/query/fragment taşıyan kök URL reddi. `main()` ağ istemcisi yaratılmadan önce yapılandırmayı doğrular; runtime demo bootstrap kaldırılır.
2. Native kimlikler/shared scheme/xcconfig/Podfile ve açık, sır içermeyen derleme JSON'ları birlikte eklenir. `FLUTTER_APP_FLAVOR` JSON'a yazılmaz.
3. CI test ve build komutlarına flavor/API girdileri eklenir; APK artifact yolu `app-staging-debug.apk` olarak güncellenir. Bu yol build çıktısıyla ayrıca teyit edilir.
4. Native build ve iki simülatörde gerçek giriş kontrolü yapılır; görsel/SMTP/Maps başarıları yalnız gerçekten çalıştırıldıktan sonra raporlanır.

Yukarıdakiler uygulama planıdır; aşağıdaki native komutlar bu araştırma kapsamında çalıştırılmadı. Örnekler staging API'yi açıkça verir, secret içermez:

```bash
/private/tmp/flutter-3.47.1/bin/flutter analyze --no-pub
/private/tmp/flutter-3.47.1/bin/flutter test --flavor staging --dart-define=API_BASE_URL=https://api.iskoala.com
/private/tmp/flutter-3.47.1/bin/flutter build apk --debug --flavor staging --dart-define=API_BASE_URL=https://api.iskoala.com
/private/tmp/flutter-3.47.1/bin/flutter build ios --simulator --debug --no-codesign --flavor staging --dart-define=API_BASE_URL=https://api.iskoala.com
xcodebuild -list -project ios/Runner.xcodeproj
```

Native kimlik doğrulaması için build sonrası iOS `.app/Info.plist` içinden yalnız `CFBundleIdentifier`/`CFBundleDisplayName`, APK'dan yalnız paket kimliği okunmalı. `xcodebuild -showBuildSettings` çıktısının tamamı loga dökülmemeli: Maps anahtarı gibi değerler içerebilir. Dev ve production varyantları da ayrı build edilmeden üç ortamın tamamı doğrulandı denmez.
