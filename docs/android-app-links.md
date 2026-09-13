# Android App Links çalışma kitabı

13 Eylül 2026, [#155](https://github.com/is-koala/koala/issues/155). Kayıt
e-postasındaki `https://iskoala.com/hesap-dogrula?token=…` bağlantısının
tarayıcı yerine uygulamayı açması için üç parça birlikte doğru olmalı: mobil
manifest (bu depo), web `assetlinks.json` (koala-web, Dokploy env) ve cihazda
kurulum anında yapılan doğrulama. Sözleşmenin kendisi `docs/deep-links.md`.

## Depoda ne var

- Host tek kaynaktan gelir: `config/<flavor>.json` → `WEB_HOSTS`
  (virgülle ayrılmış). `android/app/build.gradle.kts` bu dosyayı okuyup flavor
  manifestindeki `${appLinkHost}` (ve production'da `${appLinkHostAlias}`)
  placeholder'ını doldurur; Dart tarafı `ApiConfig.webHosts` ile aynı anahtarı
  okur. Bugün staging `iskoala.com`, production `iskoala.com,www.iskoala.com`.
- `android/app/src/staging/AndroidManifest.xml` ve `src/production/…`
  `android:autoVerify="true"` https filtresini taşır; yollar
  `AppLinkDestination.httpsPathPrefixes` ile birebir
  (`/hesap-dogrula`, `/sifre-belirle`, `/sifre-sifirla`, `/eposta-onayla`,
  `/payment/result`, `/davet`). Dev flavor'ı public host sahiplenmez.
- `test/product/router/platform_link_configuration_test.dart` manifest,
  Gradle, config ve iOS entitlements'ı birbirine bağlar.

## İnsan adımı: assetlinks.json

Android, `https://<host>/.well-known/assetlinks.json` dosyasında paket adı ve
imza sertifikasının SHA-256 parmak izini görmeden bağlantıyı uygulamaya
vermez. Web bu dosyayı iki Dokploy env anahtarından üretir
(`koala-web/src/app/.well-known/assetlinks.json/route.ts`):

| Anahtar | Değer |
| --- | --- |
| `ANDROID_APP_LINKS_PACKAGE_NAME` | Tek paket adı (aşağıdaki tablo) |
| `ANDROID_APP_LINKS_SHA256_CERT_FINGERPRINTS` | `AA:BB:…` biçiminde, virgülle birden çok |

Anahtarlar boşken uç `503 app_association_not_configured` döner; dolunca
`https://iskoala.com/.well-known/assetlinks.json` ve
`https://www.iskoala.com/.well-known/assetlinks.json` **yönlendirmesiz** 200
vermeli (web'in www → apex 301 kuralı `.well-known` yolunu zaten dışarıda
bırakır; Android doğrulayıcı yönlendirme izlemez).

### Paket adları

`applicationId` `com.iskoala.koala`, flavor son ekleri
`android/app/build.gradle.kts` içinde:

| Flavor | Paket | İmza |
| --- | --- | --- |
| staging (cihaz testi) | `com.iskoala.koala.staging` | debug keystore ya da yerel release imzası |
| production (Play) | `com.iskoala.koala` | Play **App Signing** sertifikası |

> Web uç noktası bugün **tek** paket adı kabul ediyor. Staging cihaz testi ile
> Play üretimi aynı anda doğrulanacaksa `assetlinks.json` iki hedef taşımalı;
> bu koala-web tarafında ayrı bir iş.

### SHA-256 parmak izini almak

Debug build (`flutter run` / `flutter build apk --debug`) Android SDK'nın
debug keystore'uyla imzalanır:

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android \
  | grep SHA256
```

Yerel release imzası için `android/key.properties` ya da
`KOALA_ANDROID_KEYSTORE_*` ile gösterilen keystore'a aynı komut, kendi alias ve
parolasıyla. Play'e yüklenen build'i kullanıcının cihazında **Play App Signing**
anahtarı imzalar; onun parmak izi Play Console → App integrity ekranındadır,
upload key'inki değil (`docs/release.md`). Debug ve Play parmak izleri farklı
cihaz kurulumları için ikisi de gerekiyorsa env'e virgülle ikisi birden yazılır.

Debug parmak izi `iskoala.com` (production hostu) için yalnız cihaz testi
süresince kalmalı; test bitince env'den çıkarılır ve staging yeniden
kurulur. Kalıcı düzen, staging'in de release imzasıyla dağıtılmasıdır.
Parmak izi ve keystore parolaları depoya, PR'a veya günlüğe yazılmaz.

## Cihazda doğrulama

Doğrulama uygulama **kurulurken** yapılır. Env değiştikten sonra uygulama
silinip yeniden kurulmalı ya da yeniden doğrulama tetiklenmeli:

```bash
adb shell pm get-app-links com.iskoala.koala.staging
adb shell pm verify-app-links --re-verify com.iskoala.koala.staging
```

Beklenen çıktıda host `iskoala.com` için durum `verified`; `none` ya da
`legacy_failure` görülürse `assetlinks.json` (200, doğru paket, doğru parmak
izi) ve cihazın internet erişimi kontrol edilir. Android 12 öncesinde tek bir
host bile doğrulanamazsa uygulama hiçbir host için varsayılan olmaz; bu yüzden
manifest yalnız gerçekten `assetlinks.json` yayımlayan hostları taşır.

Bağlantıyı sistemden tetiklemek için:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://iskoala.com/hesap-dogrula?token=deneme"
```

Uygulama açılıp `/auth/register-type/register/creating-password` rotasına
gidiyorsa manifest ve Dart tarafı birlikte çalışıyor demektir. Production paket
için aynı komutlar `com.iskoala.koala` ile.

## Birleşmiş manifesti okumak

`flutter build apk --flavor staging --dart-define-from-file=config/staging.json --debug`
sonrası:

```bash
grep -n -A14 'autoVerify' \
  build/app/intermediates/merged_manifests/stagingDebug/processStagingDebugManifest/AndroidManifest.xml
```

Placeholder'lar yerine gerçek host görülmeli. `WEB_HOSTS` ile flavor
manifestindeki host satırı sayısı ayrışırsa Gradle derlemeyi açık bir mesajla
durdurur.
