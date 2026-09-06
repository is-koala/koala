# Dalga 2 dış platform sözleşmeleri

Tarih: 6 Eylül 2026. Kapsam: mobil [#27](https://github.com/is-koala/koala/issues/27) ve [#28](https://github.com/is-koala/koala/issues/28), web [#12](https://github.com/is-koala/koala-web/issues/12), backend [#27](https://github.com/is-koala/koala-backend/issues/27), [#29](https://github.com/is-koala/koala-backend/issues/29) ve [#30](https://github.com/is-koala/koala-backend/issues/30). Yalnız Apple, Android/Google Play, Google Maps Platform ve Sentry'nin birincil belgeleri incelendi. Bu notta mağaza, bulut veya Sentry hesabına girilmedi; anahtar, sertifika, parmak izi ya da başka bir gizli değer okunmadı. Belge uygulama sözleşmesini ve insan adımlarını ayırır; mağaza kabulü, hukuk görüşü veya gerçek cihaz testi yerine geçmez.

## Kısa sonuç

Dalga 2'nin dış bağımlılıkları tek bir kod PR'ıyla tamamlanamaz:

| Alan | Repoda yapılabilen | Dışarıda doğrulanması gereken |
| --- | --- | --- |
| Doğrulanmış HTTPS bağlantıları | iOS entitlement, Android intent filter, `.well-known` yanıtları, rota ayrıştırma ve testler | Apple App ID/prefix, Play App Signing sertifikası, public DNS/TLS, gerçek iPhone ve Play imzalı Android kurulum |
| Mağaza yayını | imzalama yapılandırması, CI iş akışı, sürüm yordamı | Apple/Google geliştirici hesapları, sözleşmeler, roller, sertifika/profil, mağaza kayıtları ve ilk yüklemeler |
| Gizlilik ve hesap silme | veri akışı envanteri, uygulama içi silme yolu, web silme sayfası, backend yaşam döngüsü | App Store Connect ve Play Console beyanları; saklama gerekçesinin hukuk/ürün sahibi onayı |
| Maps JavaScript API | değersiz ortam değişkeni, eksik yapılandırma hatası, dokümantasyon | Cloud Console'da API/key oluşturma, referrer ve API kısıtları, quota ve bütçe uyarıları |
| Sentry | SDK yapılandırması, istemci tarafı filtre, sentetik PII regresyon testleri | ayrı projeler/DSN'ler, sunucu tarafı data scrubbing, IP saklama ayarı, alarm kanalı ve sentetik olay incelemesi |

## 1. Apple Universal Links

Apple'ın sözleşmesi iki taraflıdır: uygulamada Associated Domains entitlement, web'de de eşleşen `apple-app-site-association` (AASA) dosyası bulunmalıdır. Her tam alan adı entitlement'a ayrı girer ve kendi AASA dosyasını sunar. Dosya uzantısız olarak `https://<alan-adı>/.well-known/apple-app-site-association` yolunda, geçerli TLS ile ve yönlendirmesiz yayımlanmalıdır. Apple'ın güncel belgesi ayrıca AASA değişikliklerinin Apple CDN'ine ulaşmasının 24 saate, kurulu cihazların yenilemesinin yaklaşık bir haftaya varabileceğini söylüyor. [Apple — Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)

Koala için sonuçlar:

- `applinks:iskoala.com`, `applinks:www.iskoala.com` ve `applinks:staging.iskoala.com` üç ayrı doğrulama hedefidir. `www` normal sayfalarda apex'e yönlense bile `www/.well-known/apple-app-site-association` isteği 301/302 ile apex'e gönderilemez; dosya o hostta doğrudan `200 application/json` dönmelidir. JSON MIME türü Apple'ın AASA rehberinde açıkça tarif edilir. [Apple — Universal Links arşiv rehberi](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html)
- AASA içindeki uygulama kimliği yalnız bundle ID değildir; biçimi `<Application Identifier Prefix>.<Bundle Identifier>` şeklindedir. Prefix repodan tahmin edilmemeli, imzalı entitlement veya Apple Developer hesabından doğrulanmalıdır. [Apple — `applinks.Details`](https://developer.apple.com/documentation/bundleresources/applinks/details-swift.dictionary)
- Production bundle ID'si `com.iskoala.koala`, staging bundle ID'si `com.iskoala.koala.staging` olarak mevcut native yapılandırmayla eşleşmelidir. AASA yalnız hesap ve ödeme karşılama yollarını `components` ile açmalı; sitenin tamamını uygulamaya devretmemelidir.
- Universal Link'in beklenen fallback'i mağaza değildir: uygulama kurulu değilse aynı HTTPS URL tarayıcıda açılır. Uygulama kuruluysa doğrulanmış bağlantı uygulamaya gider. Bu nedenle doğrulanmış HTTPS bağlantılarında 1500 ms custom-scheme zamanlayıcısı varsayılan akış olmamalıdır. [Apple — Allowing apps and websites to link to your content](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content)
- Adres çubuğuna URL yazmak gerçek Universal Link testi değildir. Apple, bağlantının Notes gibi başka bir uygulamadan açılmasını ve Developer Settings içindeki Associated Domains Diagnostics aracını önerir. [Apple TN3155 — Debugging universal links](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links)

Associated Domains yetkisi Apple App ID üzerinde açılmalı ve profil bu capability'yi taşımalıdır. App ID capability değişikliğinden sonra ilgili provisioning profile'ların yeniden üretilmesi gerekir; bu işlem Account Holder/Admin erişimi ister. [Apple — Enable app capabilities](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/), [Apple — Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id)

## 2. Android App Links ve Play imzası

Android sözleşmesi de iki taraflıdır: manifestte `http`/`https`, host ve yolları tanımlayan `android:autoVerify="true"` intent filter; web'de ise `https://<alan-adı>/.well-known/assetlinks.json` bulunur. Sistem kurulumda JSON'u indirir, package name ve SHA-256 sertifika parmak izini uygulamayla eşleştirir. [Android — About App Links](https://developer.android.com/training/app-links/about)

Koala için sonuçlar:

- Production eşlemesi `iskoala.com` → `com.iskoala.koala`; staging eşlemesi `staging.iskoala.com` → `com.iskoala.koala.staging` olmalıdır. `www.iskoala.com` manifestte yer alacaksa onun `assetlinks.json` dosyası da aynı hostta HTTPS/200 ile yönlendirmesiz sunulmalıdır. Android doğrulama rehberi hostlar arası yönlendirmeyi kabul etmiyor. [Android — Troubleshoot App Links](https://developer.android.com/training/app-links/troubleshoot)
- `assetlinks.json` içindeki fingerprint, AAB'yi CI'ın yüklediği **upload key** sertifikası değil, kullanıcı cihazına kurulan APK'yı imzalayan **app signing key** sertifikasıdır. Play App Signing kullanıldığında yerel `keytool` çıktısı çoğu zaman farklıdır; doğru SHA-256 ve hazır Digital Asset Links JSON'u Play Console'daki App signing sayfasından alınmalıdır. [Android — Configure website associations](https://developer.android.com/training/app-links/configure-assetlinks)
- Play App Signing iki anahtarı ayırır: geliştirici upload key'i saklar ve AAB'yi onunla imzalar; Google dağıtılan APK'ları app signing key ile imzalar. Private upload key CI sırrıdır; sertifika ve SHA-256 parmak izi gizli değildir. [Android — Sign your app](https://developer.android.com/studio/publish/app-signing)
- Doğrudan dağıtılan staging APK'sı Play'deki staging uygulamasından farklı bir sertifikayla imzalanıyorsa association da farklıdır. `sha256_cert_fingerprints` birden fazla değeri destekler, fakat genel Android debug sertifikası production hostuna eklenmemelidir. En temiz düzen, staging hostunun staging app signing sertifikasını; production hostunun production app signing sertifikasını yetkilendirmesidir.
- Kabul yalnız JSON şema testi değildir. Play imzalı build gerçek cihazda kurulduktan sonra yeniden doğrulama ve durum incelemesi yapılmalıdır; Android resmi sorun giderme adımı `adb shell pm verify-app-links --re-verify <paket>` komutunu önerir. [Android — Troubleshoot App Links](https://developer.android.com/training/app-links/troubleshoot)

İlk iç test kurulumu sıralaması önemlidir: Play Console uygulama kaydı ve Play App Signing etkinleştirilir, app signing sertifikasının SHA-256 değeri alınır, `assetlinks.json` yayımlanır, sonra Play imzalı iç test build'iyle doğrulanır. Yerel upload sertifikasını önce dosyaya koymak sahte bir yeşil sonuç üretir.

## 3. TestFlight, Play internal ve yayın kimliği

Apple tarafında App Store Connect'e build yüklemek için önce uygulama kaydı gerekir; upload edilen build bundle ID, version ve build string ile eşleştirilir. TestFlight build'leri en fazla 90 gün test edilebilir; iç test en fazla 100 App Store Connect kullanıcısıdır, dış test ise ilk build için Beta App Review gerektirebilir. [Apple — Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [Apple — TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

CI yüklemesi App Store Connect API anahtarı/JWT ve Transporter ile otomatikleştirilebilir. Ancak API erişimini ilk kez Account Holder ister; team key'i Admin üretir ve private key yalnız bir kez indirilebilir. Private key repoya veya istemci koduna konmamalı, CI secret store'da tutulmalı ve sızıntıda iptal edilmelidir. [Apple — App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/), [Apple — Creating API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)

Google Play'de AAB upload key ile imzalanır, Play App Signing dağıtım imzasını yönetir. Internal testing tek uygulamada en fazla 100 tester kabul eder ve yeni AAB'ler genellikle dakikalar içinde tester'lara açılır. Yalnız internal trackte bulunan uygulama Data Safety bölümünden geçici olarak muaftır; closed/open/production'a çıkmadan beyan zorunludur. [Google Play — Internal testing](https://support.google.com/googleplay/android-developer/answer/9845334), [Google Play — Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469)

Apple'ın güncel yükleme yordamı Xcode ile gelen `xcrun altool` aracını, iOS platform türünü ve App Store Connect API anahtarında `--apiKey` / `--apiIssuer` seçeneklerini destekler; private P8 dosyası beklenen `AuthKey_<id>.p8` adıyla araç tarafından bulunur. [Apple — Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [Apple — Transporter authentication](https://help.apple.com/itc/transporteruserguide/en.lproj/static.html)

Play yüklemesini otomatikleştirmek için Google Play Developer API etkinleştirilir ve güvenli sunucu/CI için service account'a yalnız gerekli Play Console izinleri verilir. Kimlik bilgileri güvenli ortamda tutulmalıdır. [Google Play Developer API — Getting started](https://developers.google.com/android-publisher/getting_started)

`pubspec.yaml` sürümünün ne zaman arttığı, build number kaynağı ve hangi Git etiketinin yayın tetiklediği Koala'nın kendi kararıdır; mağazalar bunu tasarlamaz. Güvenli sıra: önce imzalı artifact üretip doğrula, sonra iç test yükle, build işlendiğini doğrula, en son minimum uygulama sürümünü yükselt. `APP_MINIMUM_VERSION` iç test kullanıcılarının güncel build'e eriştiği kanıtlanmadan yükseltilmemelidir.

## 4. Gizlilik beyanları ve hesap silme

### 4.1 App Store

Hesap oluşturan uygulama, hesap silmeyi uygulama içinden başlatabilmelidir. Geçici devre dışı bırakma yeterli değildir; tüm hesap ve yasal olarak tutulması gerekmeyen ilişkili kişisel veri silinmelidir. İşlem zaman alıyorsa kullanıcı süre ve durum hakkında bilgilendirilmelidir. Web'de tamamlama gerekiyorsa uygulama doğrudan ilgili sayfaya bağlanmalıdır. [Apple — Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/), [App Review Guidelines 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/)

App Store Connect'te iOS için privacy policy URL zorunludur ve beyan yalnız Koala kodunu değil entegre üçüncü tarafların veri davranışını da kapsar. Apple'ın kategorileri arasında ad/e-posta/telefon/fiziksel adres, precise location, kullanıcı içeriği, user/device ID, purchase history, crash/performance/diagnostics bulunur; her veri için kullanım amacı, kullanıcıyla ilişkilendirilme ve tracking ayrıca değerlendirilir. [Apple — App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/), [Apple — Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

Kimlik belgesi ve CV için kategori, dosya biçimine ve uygulamanın ayrıştırıp sakladığı alanlara göre çıkarılmalıdır; yalnız dosya adı üzerinden tahmin edilmemelidir. Örneğin belgeden alınan ad, doğum tarihi, adres ve görsel ayrı veri türleri doğurabilir. Sentry eklenirse crash/diagnostic ile SDK'nın gönderdiği identifier/IP davranışı da aynı matrise eklenir. Apple'ın privacy manifest/SDK gereksinimleri mağaza beyanının yerine geçmez; gerekli üçüncü taraf SDK manifestleri ayrıca build içinde bulunmalıdır. [Apple — Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)

### 4.2 Google Play

Google Play, uygulama içinden hesap oluşturulabiliyorsa iki erişim yolu ister: uygulama içinde silme yolu ve uygulama kaldırılmış olsa da çalışan, herkese açık bir web silme kaynağı. Web sayfası Koala adını anmalı, silme talebini görünür biçimde başlatmalı ve kullanıcıyı uygulamayı yeniden kurmaya zorlamamalıdır. [Google Play — Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)

Silme talebi hesapla ilişkili kullanıcı verisini de kapsar. Güvenlik, dolandırıcılık önleme veya mevzuat nedeniyle tutulan veri olabilir; fakat saklama nedeni ve süresi kullanıcıya privacy/retention policy içinde açıklanmalıdır. Servis sağlayıcıya aktarılmış veri için kendi sunucularındaki kopya silinir ve sağlayıcıdan da silmesi istenir. Bu kurallar backend #27'deki `REQUESTED → ANONYMIZED/REJECTED` hattının yalnız veritabanı işi olmadığını gösterir: dosya depolama, mesajlar, gözlemleme sistemi ve diğer işleyiciler kapsam tablosuna girmelidir. [Google Play — Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)

Data Safety formu, uygulamanın ve tüm SDK'ların cihaz dışına aktardığı veriyi toplama/paylaşma/amaç/zorunluluk boyutlarıyla doğru beyan etmelidir. Koala için aday matris en az precise/approximate location; ad, e-posta, user ID, adres, telefon ve other info; purchase/payment bilgileri; in-app messages; photos; files and docs; other user-generated content; app interactions; crash logs/diagnostics ve device IDs satırlarını gerçek trafik karşısında incelemelidir. Dosya olarak yüklenen CV `Files and docs` kapsamındadır; kimlik belgesinin içindeki alanlar ise ayrıca ilgili kişisel veri türleridir. [Google Play — Data Safety veri türleri](https://support.google.com/googleplay/android-developer/answer/10787469)

Apple ile Google taksonomileri birebir değildir; Google da iOS beyanının kopyalanamayacağını açıkça belirtir. Kaynak doğrusu, kod + backend + üçüncü taraf SDK veri akışlarından üretilen tek envanter; mağaza formları ise bu envanterin iki farklı görünümüdür.

## 5. Google Maps JavaScript API anahtarı

Tarayıcıdaki Maps JavaScript anahtarı kullanıcıya iner; sır gibi gizlenemez. Güvenlik sözleşmesi hem **Websites/HTTP referrer application restriction** hem de **API restriction** uygulamaktır. Google ayrıca her uygulama için ayrı key ve istemci/sunucu trafiğinin ayrılmasını önerir; sınırsız anahtarın kötüye kullanım ücretinden hesap sahibi sorumludur. [Google Maps Platform — API security best practices](https://developers.google.com/maps/api-security-best-practices)

Koala için uygulanabilir matris:

| Key | Website kısıtı | API kısıtı |
| --- | --- | --- |
| production | `https://iskoala.com/*`, gerekliyse `https://www.iskoala.com/*`; localhost yok | yalnız Maps JavaScript API |
| staging | yalnız gerçek staging origin'i | yalnız Maps JavaScript API |
| development | yalnız açık yerel origin(ler) | yalnız Maps JavaScript API |

Web adres arama/resolve işlemleri Koala backend uçlarından geçtiği için bu key'e Places API veya Geocoding API açılmamalıdır. Google'ın listesi, Maps JavaScript içindeki Places/Geocoding servisleri gerçekten kullanılırsa ilgili API'lerin ayrıca yetkilendirileceğini söyler; burada bu özellikler kapsam dışıdır. Referrer kuralı protokol, host ve varsa portu içermelidir. Tarayıcılar cross-origin istekte path'i kırpabildiği için güvenlik tam-path eşleşmesine dayandırılmamalıdır. [Google Maps Platform — API security best practices](https://developers.google.com/maps/api-security-best-practices), [Maps JavaScript API — Loading](https://developers.google.com/maps/documentation/javascript/load-maps-js-api)

Kota ve bütçe farklı kontrollerdir:

- Maps JavaScript Dynamic Maps için yayımlanmış varsayılan sınır 30.000 map load/dakika/projedir. Cloud Console'da daha düşük quota override/daily cap konarak harcama kesilebilir; eşik, beklenen trafik ve kabul edilebilir harita kesintisi birlikte seçilmelidir. [Google Maps Platform FAQ](https://developers.google.com/maps/faq), [Cloud Quotas — View and manage](https://cloud.google.com/docs/quotas/view-manage)
- Budget alert yalnız bildirimdir, harcamayı veya API kullanımını durdurmaz. Ayrı quota/hard cap olmadan "bütçe tanımlandı" maliyet koruması sayılmaz. Metric/quota ve budget uyarılarının sahipli bir bildirim kanalına gitmesi gerekir. [Google Cloud Billing — Budgets](https://cloud.google.com/billing/docs/how-to/budgets), [Google Maps Platform monitoring](https://developers.google.com/maps/reporting-and-monitoring/monitoring)

Kabul kanıtı, key değerini yazmadan Cloud Console ekranında key adı + restriction türleri + yetkili API + quota/budget yapılandırması; staging tarayıcı konsolunda gerçek tile yükleme; aynı key ile Places web-service çağrısının reddidir. Ekran görüntüsü veya CI logu gerçek key'i içermemelidir.

## 6. Sentry'de kişisel veri filtresi

`sendDefaultPii=false` gerekli başlangıçtır ama tek başına yeterli bir silme garantisi değildir. Sentry Java 7 geçiş belgesi, SDK'nın bu ayar kapalıyken bile IP alanını `{{auto}}` yapabildiğini ve proje ayarındaki **Prevent Storing of IP Addresses** seçeneğini önerdiğini kaydeder. [Sentry Java — 6.x to 7.0 migration](https://docs.sentry.io/platforms/java/migration/6.x-to-7.0)

Koala'nın her SDK'sında gönderimden hemen önce çalışan filtre (`beforeSend`/Java eşdeğeri) en az şunları kaldırmalıdır: `Authorization`/`Cookie`, JWT ve reset/doğrulama token'ları, request/response body, e-posta, telefon, TCKN/kimlik belgesi alanları, tam adres ve koordinat, mesaj metni, CV/dosya içeriği veya özel dosya adı, ödeme sağlayıcısı payload/token'ı. Ek context ve breadcrumb'lar da aynı kurala tabidir; attachment varsayılan olarak kapalı kalmalıdır. Sentry, `beforeSend` ile event veya attachment'ın gönderilmeden değiştirilebildiğini belgeler. [Sentry JavaScript — Attachments and `beforeSend`](https://docs.sentry.io/platforms/javascript/enriching-events/attachments/)

İstemci filtresinin yanına Sentry proje/organizasyonunda server-side data scrubbing, built-in sensitive fields, Koala'ya özgü ek sensitive field adları ve IP saklamama ayarı konmalıdır. Sentry API belgeleri bu ayarların yalnız yeni gelen event'lere uygulandığını açıklar; yanlışlıkla alınmış eski PII kendiliğinden temizlenmez. [Sentry — Project data-scrubbing settings](https://docs.sentry.io/api/projects/update-a-project/), [Sentry — Organization privacy settings](https://docs.sentry.io/api/organizations/update-an-organization/)

Kabul testi gerçek kullanıcı verisiyle yapılmamalıdır. Her repo ayrı Sentry project/environment/release etiketiyle sentetik ve açıkça sahte e-posta, telefon, token, adres ve koordinat içeren kontrollü bir 500 üretir; Sentry UI'da bu değerlerin hiçbirinin event, breadcrumb, request, user, extra veya attachment alanında görünmediği doğrulanır. Ardından sentetik event silinir. Bu konsol incelemesi yapılmadan "PII yok" denemez.

## 7. Uygulama sırası ve insan kapıları

1. Hesap sahibi Apple Developer/App Store Connect ve Play Console kayıtlarını, production/staging app kimliklerini ve yetkili rollerini oluşturur. Sözleşme, ücret ve kimlik doğrulama adımları otomatikleştirilemez.
2. Apple Application Identifier Prefix ve Play App Signing SHA-256 değerleri doğrulanır. Yalnız public kimlik/fingerprint repo tarafından tüketilir; private key ve parolalar CI secret store'a girer.
3. Web `.well-known` yanıtları üç hostta yönlendirmesiz yayımlanır. Native entitlement/manifest ve yalnız izinli yollar aynı PR setinde test edilir.
4. Play imzalı internal build ve TestFlight build üretilir. AASA/App Links kabulü simülatörle değil gerçek cihaz ve mağaza imzalı build ile yapılır.
5. Backend hesap silme yaşam döngüsü, mobilde görünür silme yolu ve uygulamasız erişilebilen web silme kaynağı birlikte tamamlanır; saklanan kayıtların gerekçesi hukuk/ürün sahibi tarafından onaylanır.
6. Kod ve SDK veri akışından mağaza beyan matrisi çıkarılır; Apple ve Google formları ayrı doldurulup yayın sahibi tarafından incelenir.
7. Maps key/restriction/quota/budget ve Sentry proje/scrubbing/alarm ayarları sağlayıcı konsollarında tamamlanır; değerler yerine yalnız kanıt ve sahiplik kaydedilir.
8. CI iç test yüklemesini kanıtladıktan sonra sürüm/etiket yordamı belgelenir. Minimum sürüm kapısı, tester'ların yeni build'i alabildiği görülmeden yükseltilmez.

Bu sıralamada 1, 2, 4'ün cihaz/mağaza bölümü, 5'in saklama kararı, 6'nın form onayı ve 7'nin konsol ayarları insan kapısıdır. Ajan bunlar için kod, doğrulama komutu ve değersiz şablon hazırlayabilir; hesap sahibinin kimliğiyle sözleşme kabul edemez, gizli anahtar üretemez/teslim alamaz, hukuk kararı veremez veya gerçek cihaz kanıtı uyduramaz.
