# Mobil yayın yordamı

Bu belge production mobil sürümünü Play internal ve TestFlight'a gönderen
sözleşmeyi anlatır. Mağaza hesabı açma, sözleşme kabul etme, sertifika veya
profil üretme ve mağaza beyanını yayımlama hesap sahibinin insan kapısıdır;
repo yalnız doğrulanabilir yapılandırmayı ve gizli değer almayan şablonu taşır.

İlk sağlayıcı kurulumu ve gerçek cihaz smoke kapısı için repo kökünde
`./tool/setup_release_providers.sh` çalıştırılır. Sihirbaz gizli değerleri yerel
dosyaya yazmadan doğrudan GitHub Actions secret'larına aktarır.

## Yayın kimliği ve sürümleme

- Production Android kimliği `com.iskoala.koala`, iOS kimliği
  `com.iskoala.koala`dır. ADR-0006 gereği staging kimlikleri ayrıdır.
- Pazarlama sürümü `pubspec.yaml` içindeki `major.minor.patch` değeridir ve
  `AppInfo.version` ile aynı tutulur. Backend'e giden `X-App-Version` budur.
- CI build number olarak GitHub Actions'ın artan `github.run_number` değerini
  kullanır. `pubspec.yaml` içindeki `+build` yerel geliştirme tabanıdır.
- Yayın etiketi `mobile-v<semver>` biçimindedir. Örneğin `1.2.0` için yalnız
  `mobile-v1.2.0` kabul edilir. Etiket taşınmaz veya yeniden yazılmaz.
- Bir production etiketi, iki mağazanın **iç test** kanalına yayın demektir;
  production mağaza yayını anlamına gelmez.

`dart run tool/validate_release_tag.dart mobile-v1.1.0` etiketi, pubspec ve
istemci başlık sürümünü tek sınırda doğrular.

## Bir kez yapılacak insan adımları

### Android

1. Play Console'da `com.iskoala.koala` uygulamasını aç ve Play App Signing'i
   etkinleştir.
2. Upload keystore'u güvenli bir yönetici cihazında üret. Örnek komut aşağıda;
   dosya ve parolalar repoya hiçbir zaman eklenmez:

   ```bash
   keytool -genkeypair -v -keystore koala-upload.jks -alias koala-upload -keyalg RSA -keysize 4096 -validity 10000
   ```

3. Play Developer API service account'una yalnız internal release yükleme
   yetkisi ver.
4. App Links için Play Console'daki **app signing** sertifikasının SHA-256
   değerini web `assetlinks.json` kaynağına ver. Upload key parmak izini verme;
   kullanıcının cihazındaki APK'yı Play'in app signing key'i imzalar.

### iOS

1. Apple Developer'da `com.iskoala.koala` App ID'sini aç, Associated Domains
   capability'sini etkinleştir ve provisioning profile'ı yeniden üret.
2. Apple Distribution sertifikası, App Store profile ve en az yetkili App
   Store Connect API anahtarı üret. Private key yalnız CI secret store'da kalır.
3. App Store Connect'te uygulama kaydını ve TestFlight iç test grubunu aç.

## CI sırları

| Secret | Kullanım |
| --- | --- |
| `KOALA_ANDROID_KEYSTORE_BASE64` | Upload keystore'un base64 içeriği |
| `KOALA_ANDROID_KEYSTORE_PASSWORD` | Keystore parolası |
| `KOALA_ANDROID_KEY_ALIAS` | Upload key alias'ı |
| `KOALA_ANDROID_KEY_PASSWORD` | Upload key parolası |
| `KOALA_ANDROID_MAPS_API_KEY_PRODUCTION` | Production paket adı ve imza sertifikasıyla kısıtlı Android Maps SDK anahtarı |
| `KOALA_IOS_MAPS_API_KEY_PRODUCTION` | Production bundle kimliğiyle kısıtlı iOS Maps SDK anahtarı |
| `PLAY_SERVICE_ACCOUNT_JSON` | Yalnız Play internal yükleme yetkili JSON |
| `APPLE_DISTRIBUTION_CERTIFICATE_BASE64` | Dağıtım sertifikası ve private key içeren P12 |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | P12 parolası |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Production App Store profile |
| `APPLE_TEAM_ID` | Apple takım kimliği |
| `APP_STORE_CONNECT_API_KEY_ID` | API key kimliği |
| `APP_STORE_CONNECT_API_ISSUER_ID` | API issuer kimliği |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | API private key'in base64 içeriği |

Workflow sırları ekrana yazmaz; çalışma sonunda geçici keychain, profile ve P8
dosyasını siler. GitHub `production` environment'ına gerekli reviewer ve branch
koruması ayrıca hesap sahibi tarafından konur.

## Her sürümde

1. `main` yeşilken `pubspec.yaml` ve `AppInfo.version` değerlerini aynı semver'e
   yükselt. Gizlilik envanterini ve mağaza sürüm notlarını gözden geçir.
2. `dart format --output=none --set-exit-if-changed lib test tool`,
   `flutter analyze --fatal-infos`, tam Flutter testleri, production Android ve
   imzasız iOS derlemesini çalıştır.
3. `mobile-v<semver>` etiketini doğrulanmış commit'e push et. Mobil release
   workflow'u imzalı AAB'yi Play internal'a, IPA'yı TestFlight'a gönderir.
4. İki mağazada build'in işlendiğini ve tester'a açıldığını doğrula. App Links
   kabulünü gerçek cihaz üzerinde Mail/Notes bağlantısından yap; simülatör veya
   URL'yi adres çubuğuna yazmak kabul kanıtı değildir.
5. Crash, oturum açma, hesap silme, ödeme dönüşü ve mağazadan güncelleme smoke
   testlerini bitir. Ancak bundan sonra daha geniş mağaza kanalına ilerle.

## `APP_MINIMUM_VERSION` sırası

Backend'deki `APP_MINIMUM_VERSION`, iç test build'i yüklenmeden önce
yükseltilmez. Güvenli sıra şöyledir:

1. Yeni sürümü iki iç test kanalına yükle.
2. Tester'ların mağazadan bu sürümü alabildiğini ve temel akışların geçtiğini
   doğrula.
3. Production rollout kararını ver.
4. En son backend ayarını yayımlanan pazarlama sürümüne yükselt ve eski istemci
   ile `426 UPGRADE_REQUIRED` davranışını doğrula.

## Hata ve geri alma

- Etiket veya mağaza artifact'i değiştirilmez. Hata varsa patch sürümü çıkarılır.
- Play rollout durdurulur; TestFlight'ta sorunlu build test grubundan kaldırılır.
- Zorunlu güncelleme henüz açıldıysa backend `APP_MINIMUM_VERSION` önceki çalışan
  değere geri alınır. Bu yalnız eski sürüm güvenliyse yapılır.
- Sızan upload key veya API key iptal edilir ve secret store'da döndürülür;
  repoya anahtar ekleyerek "onarım" yapılmaz.
- Geri alma adımları sonrası aynı gerçek cihaz smoke matrisi yeniden çalıştırılır.

## Repo dışında kalan kabul kanıtları

Apple/Google hesaplarının, sözleşmelerin, gerçek sertifika/profile'ların,
production secret'ların ve mağaza kayıtlarının oluşturulması; gizlilik
formlarının yayımlanması; App Links'in gerçek cihaz kanıtı ve ilk iç test
yüklemeleri insan adımıdır. Bunlar tamamlanmadan issue'nun mağaza tarafı bitmiş
sayılamaz.
