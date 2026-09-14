# Koala konum ve adres akışı araştırması

> Doğrulama güncellemesi (5 Eylül 2026): iOS staging haritası gerçek İstanbul karolarıyla çalıştırıldı ve [mobil #5](https://github.com/is-koala/koala/issues/5) kapatıldı. Adres seçimi ile adres görünürlüğü hâlâ açık [mobil #9](https://github.com/is-koala/koala/issues/9), [mobil #10](https://github.com/is-koala/koala/issues/10), [backend #6](https://github.com/is-koala/koala-backend/issues/6) ve [backend #7](https://github.com/is-koala/koala-backend/issues/7) kapsamındadır. Güncel [uygulama sentezi](../plans/real-api-test-flow.md) ile ADR-0001/0003/0006 esas alınır.

Tarih: 4 Eylül 2026 · Son doğrulama: 5 Eylül 2026
Kapsam: Flutter iOS/Android uygulaması, Spring Boot API ve PostgreSQL adres modeli
Kaynak ilkesi: Yalnızca mevcut Koala kaynak kodu ile Google, Flutter, Apple, Android, NVI, PTT, İBB, KVKK ve EUR-Lex'in birincil/resmî dokümanları kullanıldı.

## Kısa karar

Koala için önerilen üretim akışı şudur:

1. Kullanıcı adresi metinle arar.
2. Mobil uygulama, Google Places anahtarını taşımadan Koala backend'indeki autocomplete ucunu çağırır.
3. Kullanıcı bir öneri seçince backend aynı oturum belirteciyle Place Details çağrısı yapar, sonucu Koala'nın ülke/il/ilçe kimliklerine eşler.
4. Kullanıcı yapılandırılmış adresi ve pini tek bir doğrulama ekranında görür; eksik mahalle, bina, kapı veya daire bilgisini kendisi tamamlar.
5. Pin elle oynatılırsa backend ters geocoding yapar; bu sonuç tahmin olduğu için elle girilmiş alanları sessizce ezmez.
6. Son onaydan sonra adres Koala veritabanına tek `AddressWriteV2` sözleşmesiyle yazılır. Eski `countryCode/cityName/districtName/addressLine` write modeli kaldırılır; ilan, şirket ve kullanıcı için adapter veya dual-write tutulmaz. Google kaynaklı alanların kalıcı saklanabilmesi ise aşağıdaki lisans kararından sonra kesinleştirilir.

Bu tasarımda çalışma zamanı dummy veri veya test API yoktur. Harita karoları mobilde gerçek Maps SDK ile gelir; adres arama/çözümleme gerçek Google web servislerine yalnızca backend üzerinden gider; seçilen lisans kararının izin verdiği canonical uygulama verisi PostgreSQL'de tutulur.

Google Address Validation API şu anda Türkiye'yi desteklemiyor. Güncel resmî kapsam tablosunda `TR` bulunmadığı için bu ürün Koala'nın Türkiye adres akışında zorunlu veya önerilen bir bileşen değildir. Kapsam ileride değişirse yeniden değerlendirilebilir. [Google Address Validation kapsamı](https://developers.google.com/maps/documentation/address-validation/coverage)

## 1. Mevcut durum

### 1.1 Harita kurulumu

- Mobil uygulama `google_maps_flutter: ^2.18.0` kullanıyor. Paket Flutter ekibi tarafından yayımlanan, iOS ve Android'in yerel Google Maps SDK'larını saran eklentidir. [Flutter paketi](https://pub.dev/packages/google_maps_flutter)
- iOS'ta [`AppDelegate.swift`](../../ios/Runner/AppDelegate.swift) `GMSServices.provideAPIKey(...)` çağrısını ilk harita oluşmadan önce yapıyor. Bu yerleşim Google'ın önerdiği kurulumla uyumlu. [Maps SDK for iOS kurulumu](https://developers.google.com/maps/documentation/ios-sdk/config)
- Anahtar [`Info.plist`](../../ios/Runner/Info.plist) içindeki `$(MAPS_API_KEY)` build değişkeninden geliyor. Her flavor'ın xcconfig'i git dışında tutulan kendi `Secrets.<flavor>.xcconfig` dosyasını include ediyor; repodaki varsayılan değer boştur.
- Staging binary'sinin gerçek bundle identifier'ı `com.iskoala.koala.staging` olarak doğrulandı. Derlenmiş `Info.plist` içinde anahtarın boş olmadığı, anahtar değerini loglamadan doğrulandı; iPhone 16 Pro / iOS 18.6 simülatörde gerçek İstanbul karoları açıldı ve Maps SDK kimlik doğrulama hatası görülmedi.
- iOS kimlikleri dev/staging/production için sırasıyla `com.iskoala.koala.dev`, `com.iskoala.koala.staging`, `com.iskoala.koala`; Android application id'leri de aynı flavor ayrımını kullanıyor. Anahtar kısıtları her binary'nin gerçek kimliğiyle birebir eşleşmelidir. Android `namespace` değerinin farklı olması Google Cloud'daki Android uygulama kısıtının package name + imza SHA-1 ile yapılması gerçeğini değiştirmez.

Google'ın Flutter kurulum dokümanı, her hedef platform için anahtar verilmesini ve iOS/Android/Web için ayrı, platform kısıtlı anahtarlar kullanılmasını öneriyor. Harita görünmüyorsa ilk kontrolün hedef platforma doğru anahtarın eklenmesi olduğunu da açıkça belirtiyor. [Google Maps for Flutter kurulumu](https://developers.google.com/maps/flutter-package/config)

### 1.2 Bugünkü adres akışları birbiriyle tam uyumlu değil

**Kullanıcı adresi**

[`address_page.dart`](../../lib/product/features/account/presentation/pages/address_page.dart) gerçek backend'den ülke → il → ilçe referanslarını çekiyor; açık adres ve posta kodunu kullanıcıdan alıyor; koordinatı ayrı bir harita ekranından seçtiriyor. Ancak kayıt isteği iç referans kimliklerini değil `cityName` ve `districtName` metinlerini geri gönderiyor.

**İlan adresi**

[`b_create_pagemodel.dart`](../../lib/business/features/home/presentation/pages/b_create_pagemodel.dart) yine gerçek referans uçlarını kullanıyor ve koordinat seçtiriyor. [`CreateJobAddress`](../../lib/business/features/home/models/create_job_request.dart) backend'e `countryCode`, `cityName`, `districtName`, serbest adres ve koordinat gönderiyor. Adres metni ile seçilen pinin aynı yeri gösterdiğini doğrulayan bir çözümleme yok.

**Şirket adresi**

[`company_informations_pagemodel.dart`](../../lib/employee/features/auth/presentation/pages/company_informations_pagemodel.dart) diğer iki akıştan ayrılıyor: ülkeyi `TR`, ili `İSTANBUL` olarak sabitliyor, ilçeyi serbest metin kabul ediyor ve koordinatı ayrı seçtiriyor. Bu akış yazım farkı yüzünden backend referans eşlemesinde hata üretebilir ve diğer iki ekranla aynı doğruluk garantisini taşımaz.

**Ortak pin ekranı**

[`b_location_picker_page.dart`](../../lib/business/features/home/presentation/pages/b_location_picker_page.dart) haritayı sabit bir Ankara koordinatında açıyor, kamera merkezini ham `LatLng` olarak döndürüyor ve ekranda yalnızca sayısal koordinat gösteriyor. Arama, ters geocoding, seçili adres özeti, cihaz konumuna gitme veya adres–pin tutarlılık kontrolü yok. Ayrıca çalışan tarafı da `business/` altındaki bu sayfayı kullanıyor; ortak ürün bileşeni olması gereken seam yanlış klasörde.

### 1.3 Backend adres sözleşmesi

- [`CreateAddressRequestDto`](../../../koala-backend/src/main/java/com/exskylab/koala/core/dtos/address/request/CreateAddressRequestDto.java) `countryCode`, `cityName`, isteğe bağlı `districtName`, `addressLine`, isteğe bağlı `postalCode`, `latitude` ve `longitude` alıyor.
- [`AddressManager`](../../../koala-backend/src/main/java/com/exskylab/koala/business/concretes/AddressManager.java) ülkeyi kodla, il ve ilçeyi adla arıyor. Bu nedenle mobilin elinde referans UUID'leri bulunmasına rağmen kalıcı sözleşme yazım ve Türkçe büyük/küçük harf farklılıklarına bağlı.
- DTO ilçeyi isteğe bağlı tanımlasa da manager her zaman `findDistrictByNameAndCity(...)` çağırıyor. Dolayısıyla sözleşmedeki “isteğe bağlı” davranış kodda gerçek değil.
- [`Address`](../../../koala-backend/src/main/java/com/exskylab/koala/entities/Address.java) ülke/il/ilçe FK'lerini, tek satır serbest adresi, posta kodunu ve `double` koordinatları tutuyor. Provider, place ID, mahalle, kaynak, doğruluk/granularity veya kullanıcı onayı bilgisi yok.
- Backend'in kendi [`CLAUDE.md`](../../../koala-backend/CLAUDE.md) yol haritası da mevcut isimle aramayı kırılgan buluyor ve istemcinin il/ilçe kimliği göndermesini Faz 20 hedefi olarak kaydediyor.

### 1.4 İstanbul referans verisi doğruluğu

Backend seed'i İstanbul için 40 ilçe kaydı içeriyor ve bunlardan biri `EMİNÖNÜ`. İstanbul Büyükşehir Belediyesi, 5747 sayılı Kanun ile Eminönü Belediyesinin kaldırıldığını ve Fatih Belediyesine katıldığını; İstanbul'un 39 ilçesi bulunduğunu belirtiyor. Bu nedenle `EMİNÖNÜ` yeni adreslerde seçilebilir aktif ilçe olmamalı; mevcut kayıtlar silinmeden önce `EMİNÖNÜ → FATİH` alias/migration kararı verilmelidir. [İBB yetki alanı ve ilçe sayısı](https://ibb.istanbul/ibb/belediye-hakkinda/yetki-alani/)

### 1.5 Konum mahremiyeti

[`JobsController`](../../../koala-backend/src/main/java/com/exskylab/koala/webAPI/JobsController.java) hem ilan aramasını hem ilan detayını anonim erişime açıyor. [`JobSummaryDto`](../../../koala-backend/src/main/java/com/exskylab/koala/core/dtos/job/response/JobSummaryDto.java) tam koordinatı, [`JobDetailDto`](../../../koala-backend/src/main/java/com/exskylab/koala/core/dtos/job/response/JobDetailDto.java) ise tam `AddressDto`yu döndürüyor. Şirket işyeri için bu ürün kararı olabilir; bireysel işverenin ev adresi için varsayılan olarak fazla açık bir sözleşmedir.

[`location_service.dart`](../../lib/employee/features/home/services/location_service.dart) yaklaşık konum iznini yetersiz sayıyor ve tam konum verilmezse kapatılamayan “uygulamanın çalışabilmesi için” diyaloğu gösteriyor. Oysa adres arama ve manuel pin seçimi cihazın o anki konumunu gerektirmez. Apple, iznin açık bir kullanıcı eylemi bağlamında istenmesini, mümkün olduğunda `When in Use` seviyesinin kullanılmasını ve azaltılmış doğruluğun ayrı bir yetkilendirme durumu olarak ele alınmasını ister. Android de izni ihtiyaç anında istemeyi, reddedildiğinde akışı zarifçe azaltmayı ve Android 12+ üzerinde kullanıcının yaklaşık konumu seçebileceğini belirtir. [Apple HIG — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy), [Apple konum yetkisi seçimi](https://developer.apple.com/documentation/bundleresources/choosing-the-location-services-authorization-to-request), [Apple accuracy authorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/accuracyauthorization), [Android runtime permissions](https://developer.android.com/training/permissions/requesting), [Android konum doğruluğu](https://developer.android.com/develop/sensors-and-location/location/permissions/runtime)

## 2. Harita sağlayıcı durumu ve kalan kontroller

iOS staging için beyaz harita sorunu kapanmıştır: flavor-specific secret build'e girmiş, gerçek bundle identifier ile imzalanan binary'de İstanbul karoları görülmüş ve SDK yetkilendirme reddi oluşmamıştır. `GMSServices.provideAPIKey` çağrısının yeri doğrudur; bu entegrasyon yeniden yazılmamalıdır.

Kalan doğrulamalar iOS staging kanıtından bağımsızdır:

- production iOS anahtarı `com.iskoala.koala` ile, dev anahtarı `com.iskoala.koala.dev` ile ayrı doğrulanmalı,
- Android dev/staging/production package + ilgili debug/release/Play App Signing SHA-1 çiftleriyle smoke test edilmeli,
- billing ve gereken SDK/API'ler her ilgili Cloud projesinde etkin olmalı,
- anahtar değeri hiçbir log, doküman, issue veya build artifact raporuna yazılmamalı; yalnızca boş/placeholder durumu, flavor ve uygulama kimliği loglanabilmeli.

Maps SDK, billing ile geçerli anahtar ister; Google ayrıca anahtarı hem uygulama hem API ile kısıtlamayı ve ayrı kullanım senaryoları için ayrı anahtarlar kullanmayı önerir. [iOS kullanım ve faturalama](https://developers.google.com/maps/documentation/ios-sdk/usage-and-billing), [API anahtarı güvenlik rehberi](https://developers.google.com/maps/api-security-best-practices)

### Platform anahtarlarını ayır

Tek anahtarı her yerde kullanmayın:

| Anahtar | Uygulama kısıtı | API kısıtı |
|---|---|---|
| iOS Maps dev/prod | iOS bundle id | Maps SDK for iOS |
| Android Maps dev/prod | package name + ilgili SHA-1 | Maps SDK for Android |
| Backend location service | sunucu IP'si/CIDR veya destekleniyorsa OAuth | Places API (New), Geocoding API |

Android'de debug ve release/Play App Signing sertifikalarının SHA-1'leri farklıdır; yetkilendirilecek her package + SHA-1 çifti açıkça eklenmelidir. [Google API key güvenlik rehberi](https://developers.google.com/maps/api-security-best-practices) Google ayrıca istemci ve sunucu trafiğinin ayrı anahtarlar, ideal olarak ayrı Cloud projeleriyle ayrılmasını; web-service anahtarlarının istemci uygulamaya gömülmemesini öneriyor.

Bu ayrım, mobil Maps SDK anahtarının uygulamadan çıkarılabileceği anlamına gelmez: yerel SDK anahtarı binary'de bulunur ama iOS/Android uygulama kısıtlarıyla korunur. Places/Geocoding REST anahtarı ise gizlidir ve yalnızca backend'de kalır.

## 3. Önerilen kullanıcı deneyimi

Bu bölüm, resmî API yeteneklerinden çıkarılan Koala ürün tasarımıdır; Google veya Apple'ın tek bir hazır “iş pazaryeri akışı” olarak tanımladığı bir şablon değildir.

### Adım A — “Adres ara” birincil, “Konumumu kullan” isteğe bağlı

Ekran şu sırada açılmalıdır:

- `Adres ara` metin alanı,
- daha önce kayıtlı adres varsa özet,
- isteğe bağlı `Konumumu kullan` eylemi,
- `Haritadan seç` manuel alternatifi.

Adres yazmak cihaz izni istemez. Konum izni yalnızca kullanıcı `Konumumu kullan` dediğinde istenir. Reddedilirse form çalışmaya devam eder; harita varsayılan olarak seçili il/İstanbul görünümünde açılabilir.

iOS için yalnızca foreground kullanılıyorsa `When in Use` yeterlidir; `Always` yetkisinin ürün gerekçesi yoktur. Kullanıcı azaltılmış/yaklaşık konum verirse harita yaklaşık bölgeye merkezlenebilir ama bu değer kesin iş adresi diye kaydedilmez; kullanıcı adresi arayarak veya pini elle taşıyarak onaylar. Apple, azaltılmış doğruluğun tipik olarak şehir düzeyinde, yaklaşık 1–20 km'lik bölge sağlayabildiğini ve yüksek `desiredAccuracy` istemenin bunu aşmadığını açıklar. [Apple reduced accuracy](https://developer.apple.com/documentation/corelocation/kcllocationaccuracyreduced)

App Store beyanında backend'e üç veya daha fazla ondalık basamakla gönderilen koordinat Apple'ın “Precise Location” tanımına girer; fiziksel adres ayrıca ayrı bir veri türüdür ve üçüncü taraf SDK'ların toplaması da beyanda hesaba katılır. [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

### Adım B — autocomplete

Mobil her tuşta Google'a doğrudan gitmez. Arama alanı odaklandığında kimlik doğrulanmış `POST /locations/search-sessions` çağrısıyla kısa ömürlü bir Koala oturum ID'si alır; ardından backend'e örneğin şu isteği yollar:

```http
POST /locations/autocomplete
Authorization: Bearer …
Content-Type: application/json

{
  "input": "Kadıköy Moda Ca",
  "searchSessionId": "<backend-issued-opaque-id>",
  "languageCode": "tr",
  "regionCode": "tr",
  "includedRegionCodes": ["tr"],
  "mapViewport": {
    "south": 40.80,
    "west": 28.55,
    "north": 41.35,
    "east": 29.50
  }
}
```

Üretim davranışı:

- Yeni odaklanmış arama için backend'den kısa ömürlü bir `searchSessionId` al; provider session token'ını backend üretir ve bu ID ile ilişkilendirir.
- Aynı `searchSessionId`yi bütün autocomplete isteklerinde ve seçimi bitiren resolve isteğinde kullan.
- Seçim tamamlanınca veya oturum terk edilince ID'yi tekrar kullanma; backend de oturumu kapatıp süresi dolan eşlemeyi siler.
- İlk 3–4 karakteri bekletmenin istek sayısını azaltırken algılanan gecikmeyi artırdığı Google tarafından özellikle belirtiliyor. Koala için başlangıç politikası üç karakter + kısa debounce olabilir; eşik ve debounce ölçümle ayarlanmalı, eski yanıtlar request id ile düşürülmelidir.
- `includeQueryPredictions: false` kullan; adres seçiminde serbest sorgu önerilerine gerek yok.
- Türkiye pazarı için `includedRegionCodes: ["tr"]`, Türkçe çıktı için `languageCode: "tr"` ve `regionCode: "tr"` kullan.
- İstanbul'daki kullanıcıyı öne çıkarmak için backend `mapViewport` değerini `locationBias`a dönüştürebilir; ürün gerçekten yalnızca İstanbul'da hizmet veriyorsa `locationRestriction` da kullanılabilir. Bias ve restriction aynı istekte kullanılamaz. `locationRestriction` dikdörtgen/çember tabanlı olduğu için İstanbul hizmet alanının kesin otoritesi değildir; final seçim iç `cityId`/`districtId` ve bağımsız hizmet alanı kuralıyla doğrulanmalıdır.
- Autocomplete cevap maskesini yalnızca listeyi çizmek için gereken `suggestions.placePrediction.placeId`, ana metin ve ikincil metinle sınırla. Google içeriği Google haritası dışında gösteriliyorsa ilgili attribution/logo kuralı uygulanmalıdır.

Google, kendi session token'ının URL/file-safe Base64 ve en fazla 36 ASCII karakter olmasını, UUID v4 kullanılmasını; oturumun aynı Cloud projesindeki aynı token'lı Place Details veya Address Validation çağrısıyla bitmesini ve token'ın tekrar kullanılmamasını belirtiyor. Koala'nın public `searchSessionId`si provider token'ı değildir; ikisini backend eşler. Her ikisi de kimlik doğrulama aracı değildir ve backend kullanıcıyı ayrıca yetkilendirip ömrü/tekrar kullanımı doğrular. [Autocomplete REST sözleşmesi](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/autocomplete), [Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)

### Adım C — seçilen place'i backend'de çöz

Kullanıcı öneriye dokununca mobil yalnızca `placeId` ve aynı `searchSessionId`yi gönderir:

```http
POST /locations/resolve
Authorization: Bearer …
Content-Type: application/json

{
  "placeId": "…",
  "searchSessionId": "…"
}
```

Backend `Place Details (New)` çağrısını dar alan maskesiyle yapar:

```text
id,formattedAddress,addressComponents,location,types,viewport
```

Bu alanların tamamı Place Details Essentials katmanındadır; işletme puanı, yorum, telefon, çalışma saati veya `displayName` bu akışta gereksizdir ve istenmemelidir. Place Details'ta field mask zorunludur; `*` üretimde daha yüksek gecikme ve beklenmedik ücret oluşturabileceği için önerilmez. [Place Details alanları](https://developers.google.com/maps/documentation/places/web-service/place-details), [field mask rehberi](https://developers.google.com/maps/documentation/places/web-service/choose-fields)

Backend:

1. `country` bileşeninin kısa kodunu iç `countries.code` ile eşler.
2. İl ve ilçe için provider bileşen tiplerinden adaylar çıkarır.
3. Adayları Koala `city`/`district` UUID'lerine, gerektiğinde alias tablosuyla eşler.
4. Eşlenemeyen bileşeni tahmin ederek kabul etmez; mobilde açık seçim/onarım gerektirir.

`formattedAddress` programatik olarak parçalanmamalıdır. Google, `addressComponents` elemanlarının sayısının, sırasının, tipinin ve varlığının zaman içinde değişebileceğini açıkça belirtiyor. Eşleme dizi pozisyonuna değil component `types` değerlerine dayanmalı, eksik alanı tolere etmelidir. [Places veri modeli](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places), [Geocoding yanıt rehberi](https://developers.google.com/maps/documentation/geocoding/guides-v3/requests-geocoding)

### Adım D — ortak onay ekranı

Resolve cevabından sonra aynı ekran şunları birlikte gösterir:

- okunabilir seçili adres,
- Google haritası ve pin,
- ülke/il/ilçe/mahalle,
- cadde/sokak + bina/kapı no,
- isteğe bağlı kat/daire/açıklama,
- posta kodu,
- `Bu adresi kullan` eylemi.

Google sonucu her zaman daire/bağımsız bölüm gibi `subpremise` ayrıntısını tamamlamayabilir; Autocomplete dokümanı bu durumlarda serbest girdiyi geocoding'e fallback etmeyi özellikle sayıyor. Bu nedenle kullanıcının `floor`, `unitNumber` ve `additionalDirections` alanları korunmalı ve provider cevabıyla silinmemelidir. [Autocomplete performans/fallback rehberi](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)

Pin hareket ettirilirse kamera durduktan sonra backend'e ters geocoding çağrısı yapılır. Ters geocoding en yakındaki adresi tahmin eder, birden fazla farklı ayrıntı seviyesinde sonuç verebilir ve hiç sonuç bulamayabilir; bu yüzden cevap öneri olarak gösterilir, kullanıcı onayı olmadan mevcut adresi ezmez. [Reverse Geocoding](https://developers.google.com/maps/documentation/geocoding/reverse-geocoding)

### Türkiye ve İstanbul canonical adresi

Koala resmî Adres Kayıt Sistemi değildir; yine de canonical alanları Türkiye'nin resmî adres bileşenleriyle uyumlu tasarlamak ileride eşleme ve doğrulama borcunu azaltır. NVI yönergesi il, ilçe, köy/yerleşim, belediye, mahalle, meydan/bulvar/cadde/sokak, site/blok, dış kapı, iç kapı ve posta kodunu ayrı bileşenler olarak tanımlar. MAKS da metinsel adres verisinin coğrafi koordinatla ilişkilendirildiği modeli tarif eder. PTT'nin resmî adres standardı, posta kodu ve hiyerarşik yazım örneklerini verir. [NVI Adres Kayıt Sistemi Uygulama Yönergesi](https://www.nvi.gov.tr/kurumlar/nvi.gov.tr/mevzuat/nufusmevzuat/yonerge/AdresKayitSistemiUygulamaYonergesi.pdf), [NVI Adres Kayıt Sistemi](https://nvi.gov.tr/adres-kayit-sistemi), [MAKS](https://icisleri.gov.tr/mekansal-adres-kayit-sistemi-maks), [PTT adres standardı](https://postakodu.ptt.gov.tr/Dosyalar/adres.pdf)

Bu nedenle İstanbul v1 için `countryId`, `cityId`, `districtId` zorunlu; `neighborhood`, cadde/sokak, dış kapı, iç kapı ve posta kodu ayrı alanlar olmalıdır. Provider'ın `formattedAddress` değeri yalnızca gösterim/taslak içindir; canonical kimlik değildir. İstanbul dışı adres desteği açılacaksa zorunluluklar ülke bazlı policy ile gevşetilmelidir.

### Adım E — DB'ye kaydet

Kullanıcı onayı tek bir `AddressWriteV2` nesnesi üretir. Aynı nesne:

- `PUT /users/me/address`,
- `POST /companies`,
- `POST /users/me/jobs`,
- `POST /companies/{companyId}/jobs`

isteklerinde kullanılır. Böylece şirket kaydında sabit İstanbul, ilan kaydında başka DTO ve çalışan adresinde başka validasyon kalmaz. Eski isim tabanlı payload yeni sözleşmeye backend'de çevrilmez; bütün mobil çağrı noktaları koordineli cutover'da birlikte taşınır.

## 4. Backend ve mobil sorumlulukları

### Mobil

- Arama metni, debounce, backend-issued search session yaşam döngüsü ve stale-response engelleme.
- Öneri listesini ve kullanıcı onay ekranını çizme.
- Native Google Map'i iOS/Android'e özel kısıtlı anahtarla gösterme.
- Cihaz konum iznini yalnızca kullanıcı açıkça istediğinde alma.
- Backend'in döndürdüğü iç referans kimliklerini ve kullanıcı düzeltmelerini kaydetme isteğine taşıma.
- Google web-service anahtarını veya ham provider hata cevabını taşımama.

### Backend

- Places/Geocoding anahtarını veya OAuth kimliğini gizli tutma.
- Kimlik doğrulama, kullanıcı/IP hız sınırı, timeout, retry/backoff ve circuit breaker.
- İstemcinin serbest Google URL'si, field mask'i veya API parametresi geçmesine izin vermeyen dar uçlar.
- Provider cevabından yalnızca mobilin ihtiyaç duyduğu alanları döndürme.
- Provider component'lerini Koala ülke/il/ilçe UUID'lerine eşleme.
- Koordinat sınırlarını, ülke/hizmet alanını ve il–ilçe ebeveyn ilişkisini doğrulama. İstanbul üyeliğini yalnızca Places koordinatını bağımsız bir poligonda test ederek kurmama; Google'ın yürürlükteki genel şartları Places latitude/longitude değerini point-in-polygon analizine girdi yapmayı yasak kullanım örneği sayıyor. İç referans/hizmet alanı verisi veya ayrı lisanslı coğrafi veri otorite kabul edilmelidir. [Google Maps Platform Terms, 3.2.3(c)](https://cloud.google.com/maps-platform/terms)
- Son kullanıcı onayını server timestamp ile damgalama ve final adresi PostgreSQL'e yazma.
- Provider query/adres gövdelerini loglarda maskeleme.

Google, client SDK bulunmayan veya mobilde doğrudan REST çağrısı güvenle kısıtlanamayan durumlarda güvenli proxy kullanılmasını; proxy'nin keyfi API relay'i olmamasını, sadece gereken alanları döndürmesini ve istemci erişiminin kimlik doğrulamalı olmasını öneriyor. Koala'nın mevcut ortak Dio/backend yapısı bu model için uygundur. [Google Maps Platform güvenlik rehberi](https://developers.google.com/maps/api-security-best-practices)

### Contract değişmezleri

- `autocomplete`, `resolve` ve `reverse` cevapları ham Google JSON'u değil, tek bir Koala `AddressCandidate` şemasını döndürür: iç referans ID/adları, ayrıştırılmış kullanıcı alanları, koordinat, sonuç granularity/type, `needsUserReview` ve provider attribution bilgisi.
- Mobil yalnız `searchSessionId` kullanır; Google session token'ını backend üretir, aynı Cloud projesindeki tamamlayıcı çağrıda kullanır ve tamamlanma/terk/TTL sonrasında tekrar kullandırmaz.
- Provider hata metni mobile taşınmaz; Koala'nın sabit `invalid_input`, `no_result`, `rate_limited`, `provider_unavailable`, `reference_unmatched`, `outside_service_area` kodlarına çevrilir.
- `reverse` cevabı yeni bir adaydır; backend veya mobil, kullanıcının daha önce düzenlediği kapı/daire/açıklama alanlarını otomatik merge etmez.
- İstek/cevap sözleşmesi OpenAPI ve iki repo contract fixture/testleriyle birlikte değişir; UUID, nullability, koordinat sırası ve enum değerleri tek kaynaktan doğrulanır.

## 5. Önerilen veri sözleşmesi

### 5.1 Tek canonical `AddressWriteV2`

Write contract provider JSON'unu veya gösterim metnini kalıcı adres modeli saymaz. Mobilin bütün adres yazma noktaları aynı body'yi gönderir:

```json
{
  "countryId": "uuid",
  "cityId": "uuid",
  "districtId": "uuid",
  "components": {
    "neighborhood": "Caferağa Mahallesi",
    "thoroughfare": "Moda Caddesi",
    "siteName": null,
    "block": null,
    "buildingName": null,
    "buildingNumber": "12",
    "floor": "2",
    "unitNumber": "4",
    "postalCode": "34710",
    "additionalDirections": null
  },
  "position": {
    "latitude": 40.982512,
    "longitude": 29.025411,
    "source": "USER_CONFIRMED_PIN"
  },
  "candidateToken": "short-lived-opaque-token-or-null"
}
```

Canonical kurallar:

- Write isteğinde `countryCode`, `cityName`, `districtName`, `formattedAddress`, `addressLine` ve `providerPlaceId` yoktur. İstemci yalnız iç referans UUID'lerini yollar; backend isim/kodları bu referanslardan üretir ve yalnız read projection'da döndürür.
- `candidateToken`, autocomplete resolve/reverse sonucu için backend'in verdiği kısa ömürlü, tek kullanımlık opaque referanstır. Google place ID veya ham provider içeriği mobil write/read contract'ına sızmaz. Manuel seçimde token `null` olabilir.
- İstanbul v1'de `countryId`, `cityId`, `districtId`, `neighborhood`, `thoroughfare`, beş basamaklı `postalCode` ve kullanıcı tarafından onaylanmış `position` zorunludur. Bina tipi konumda `buildingNumber`; park, fuar alanı veya benzeri numarasız iş yerinde bunun yerine `siteName` zorunludur. İç kapı/kat/tarif isteğe bağlıdır ve exact görünürlük kapsamındadır. PTT'nin resmî standardı Türkiye posta kodunu beş basamaklı adres bileşeni olarak gösterir. [PTT adres standardı](https://postakodu.ptt.gov.tr/Dosyalar/adres.pdf)
- `position.source`: `AUTOCOMPLETE_CONFIRMED`, `REVERSE_GEOCODE_CONFIRMED` veya `USER_CONFIRMED_PIN`. Cihaz konumu sadece haritayı merkezler; kullanıcı pini/adresi açıkça onaylamadan final kaynak olamaz.
- `confirmedAt`, `confirmedBy` ve `canonicalVersion` istemciden alınmaz; backend kimlik doğrulanmış principal ve server clock ile üretir.
- Koordinat sırası isimli alanlarla sabittir; latitude `[-90, 90]`, longitude `[-180, 180]` aralığında ve PostgreSQL `NUMERIC(9,6)`/`NUMERIC(10,6)` hassasiyetinde tutulur. Google `LatLng` de latitude değerini `[-90, 90]` aralığına clamp, longitude değerini `[-180, 180)` aralığına wrap ederek tanımlar. [Google LatLng reference](https://developers.google.com/maps/documentation/javascript/reference/coordinates#LatLng)
- `displayAddress` mobil tarafından gönderilmez. Backend, canonical bileşenler ve iç referans adlarından Türkiye sırasına göre deterministik üretir; provider `formattedAddress` değeri business identity değildir.
- Visibility adres varlığında değil ilan/atama ilişkisinde tutulur. Aynı exact adres farklı ilanlarda farklı public görünürlük kararı taşıyabilir.

Provider veri soyu canonical tablodan ayrıdır. Kalıcı tutulması izin verilen Place ID varsa ayrı provider-reference tablosunda geniş metin alanı olarak saklanabilir; Google Place ID uzunluğu için sabit maksimum garanti etmez. Ham provider response ve geçici candidate, TTL'li cache sınırında kalır. [Place IDs](https://developers.google.com/maps/documentation/places/web-service/place-id)

### 5.2 Okuma modelleri ve görünürlük

Tek `AddressDto`yu her role döndürmek yerine en az iki görünüm önerilir:

```text
PublicJobLocationDto
  cityName
  districtName
  neighborhood?
  approximateLatitude?
  approximateLongitude?
  visibility

ExactWorkLocationDto
  addressId
  fullAddress fields
  exactLatitude
  exactLongitude
```

Önerilen varsayılan:

- Bireysel işveren ilanı: anonim/listede ilçe veya yaklaşık pin; tam adres yalnızca kabul edilmiş atamanın çalışanına ve işverene.
- Şirket ilanı: şirket açıkça izin verirse tam işyeri konumu public olabilir; aksi halde aynı yaklaşık politika.
- Kullanıcı profili: bugünkü gibi yalnızca il/ilçe.
- Adres sahibi/edit ekranı: tam adres.

Yaklaşık koordinat yalnızca UI'da yuvarlanmamalı; API public DTO'su baştan yaklaşık değer üretmeli ki tam değer ağ cevabından alınamasın. En güvenli public seçenek yalnızca ilçe/mahalle etiketi döndürmektir. Harita üzerinde nokta gerekiyorsa exact koordinattan istemcide türetilmiş yuvarlama yerine, ayrı lisanslı bir veri kaynağından üretilmiş ilçe merkezi veya yeterince kaba server-side değer kullanılmalı; public response/cache hiçbir zaman exact alanı içermemelidir.

Exact iş konumu, ADR-0003'e göre işveren/yetkili şirket kullanıcısı ile kabul edilmiş atamanın çalışanına yalnızca operasyonel yaşam döngüsünde açılmalıdır. Terminal durumda endpoint tekrar gizlemeli; mobil de yetki/atama durumu değişince cached exact DTO ve harita state'ini temizlemelidir. Şirketin ilan bazlı public exact seçimi varsayılan kapalı, açık ve geri alınabilir olmalı; bireysel işveren için böyle bir seçenek sunulmamalıdır.

### 5.3 İlan adresi snapshot olmalı

Bir şirket veya kullanıcı daha sonra profil adresini değiştirince geçmiş/aktif ilanın yeri kendiliğinden değişmemelidir. İlan, yayın anında onaylanan adresin ayrı snapshot kaydına bağlanmalı; düzenleme ayrıca yetkili ilan güncellemesi olmalıdır. Mevcut backend her oluşturma akışında yeni `Address` ürettiği için bu davranışa yakındır ve korunmalıdır.

### 5.4 Geriye uyumsuz migration ve cutover

Mevcut `CreateAddressRequestDto` v2'nin temeli veya compatibility DTO'su değildir. `countryCode/cityName/districtName/addressLine/latitude/longitude` body kabulü kaldırılır; tek OpenAPI şeması `AddressWriteV2` olur. Eski endpoint/body için adapter, fallback name lookup veya dual-write yapılmaz.

Veri cutover'ı yine kontrollü olmalıdır:

1. Migration öncesi adres ve referans tablolarının doğrulanabilir backup'ı alınır; mevcut satır sayıları ve orphan FK kontrolleri raporlanır.
2. Mevcut `country/city/district` FK'leri yeni canonical kolonlara doğrudan taşınır. `EMİNÖNÜ` district ID'li satırlar audit kaydıyla `FATİH`e eşlenir; seed'de Eminönü inactive alias olur ve API aktif seçimlerde döndürmez.
3. Geçerli aralıktaki mevcut latitude/longitude `position`a taşınır; kaynağı bilinmediği için `LEGACY_UNVERIFIED` ve `needsReview=true` işaretlenir.
4. Eski serbest `addressLine` heuristik olarak mahalle/sokak/kapı alanlarına bölünmez. Geçici `legacyUnstructuredAddress` alanında yalnız sahibine gösterilir ve adres bir sonraki kullanım/düzenlemede ortak picker ile yeniden onaylanır.
5. Mevcut verinin tamamen disposable test verisi olduğu ürün sahibi tarafından ayrıca doğrulanırsa kontrollü reseed, bu backfill'in yerine seçilebilir; bu belge silme yetkisi vermez.
6. Backend v2 schema + endpoint ve v2 mobil build koordineli bakım/cutover penceresinde yayımlanır. Eski mobil build minimum sürüm kapısıyla durdurulur; eski write endpoint'i `410 Gone`/sabit upgrade error verir, sessizce isim eşlemez.
7. Bütün aktif adresler yeniden onaylandıktan ve rollback süresi bittikten sonra legacy kolonlar ayrı migration ile düşürülür.

Cutover tamamlanma metriği; toplam/yeniden onaylı/`needsReview` adres sayısı, başarısız referans eşleme ve eski istemci write denemeleridir. Metrikler adres metni veya koordinat içermez.

## 6. Maliyet, saklama ve gizlilik

### Maliyet

- Autocomplete oturum başlangıç/tamamlanma/terk oranını ölç.
- Ortalama autocomplete request/session sayısını ölçmeden sabit fiyat varsayma. Google, yalnızca adres ve koordinat gereken akışta ortalama dört veya daha az tahmin isteğinde programmatic autocomplete + Geocoding'in daha ekonomik olabileceğini; daha uzun aramalarda session + Place Details yaklaşımını değerlendirmeyi öneriyor. Güncel session fiyatlandırmasında Place Details Essentials ile tamamlanan oturumda ilk 12 autocomplete isteği istek başına ücretlenir, 13 ve sonrası session usage olarak ücretsizdir; terk edilen veya uygun biçimde tamamlanmayan oturumlar istek başına ücretlenir. Bu nedenle metrikler `requests/session`, tamamlanma ve terk oranını içermelidir. [Autocomplete maliyet seçimi](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete), [Places session pricing](https://developers.google.com/maps/documentation/places/web-service/session-pricing)
- Field mask'i dar tut; `displayName`, yorum, telefon ve çalışma saatini isteme.
- Kullanıcı başına rate limit, Google Cloud kota ve bütçe uyarısı ekle.
- Provider yanıtlarını uzun süreli genel cache'e alma; session içi kısa yaşamlı UI durumu yeterli.

### Saklama ve Google şartları

Place ID'nin saklanmasına açık istisna vardır; Google bunu daha sonra kullanmak üzere saklamaya izin veriyor ve 12 aydan eski ID'lerin yalnızca `id` alanı istenen ücretsiz/IDs-only detay çağrısıyla yenilenmesini öneriyor. [Place ID saklama ve yenileme](https://developers.google.com/maps/documentation/places/web-service/place-id)

Adres metni ve koordinat gibi diğer Google Maps Content alanlarının kalıcı saklama koşulları kullanılan servise, billing bölgesine ve yürürlükteki hizmet şartlarına bağlıdır. Güncel şartlar değişebildiği için implementasyon öncesi hesabın tabi olduğu mevcut [Google Maps Platform Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms) ve [Places policies](https://developers.google.com/maps/documentation/places/web-service/policies) hukuk/ürün tarafından kontrol edilmelidir.

5 Eylül 2026 doğrulamasında mevcut Google şartları şu önemli sınırları koyuyor:

- Places API'den gelen latitude/longitude en fazla 30 gün cache edilebilir; diğer Places Content için genel kalıcı saklama izni yoktur, Place ID istisnadır.
- Geocoding API için latitude/longitude 30 gün cache edilebilir. Belirli formatted/structured address ve koordinat alanlarının daha uzun saklanmasına yalnızca, o veriyi sağlayan belirli son kullanıcının doğrudan başlattığı ve o kullanıcıya mantıksal olarak izole edilmiş işlevi destekleme koşuluyla izin verilir.
- Bir işverenin Google kaynaklı exact iş adresini PostgreSQL'de kalıcılaştırıp birçok iş arayana ilan verisi olarak yeniden sunmak, bu “belirli son kullanıcıya izole” istisnaya açıkça oturmaz.

Bu üç tespit doğrudan mevcut Places ve Geocoding özel şartlarının cache/storage bölümlerine dayanır. [Google Maps Platform Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms)

Dolayısıyla “kullanıcı Google sonucunu onayladı, artık aynı veriyi sınırsız saklayabiliriz” varsayımı güvenli değildir. Kodlamadan önce ürün/hukuk/Cloud hesap sahibi aşağıdaki yollardan birini yazılı olarak seçmelidir:

1. Google yalnızca geçici arama yardımı olur; kalıcı alanlar kullanıcı tarafından bağımsız biçimde girilmiş/işaretlenmiş birinci taraf veri sayılır. Bunun gerçekten lisans sınırını aşıp aşmadığı hukuk tarafından doğrulanır.
2. Kalıcı ve çok kullanıcılı saklama/yayınlamaya açıkça izin veren başka bir adres/coğrafi veri sağlayıcısı ve lisansı seçilir.
3. İzin verilen cache süresi, yenileme ve gösterim sınırlarıyla Google tabanlı bir model kurulur; bunun maliyet ve public ilan kullanımına uygunluğu ayrıca doğrulanır.

Address Validation API'nin “kullanıcı doğruladı/düzeltti” saklama mekanizması Türkiye'yi kapsamadığı için bu boşluğu kapatmaz. [Google Address Validation kapsamı](https://developers.google.com/maps/documentation/address-validation/coverage)

Lisans kararı verilene kadar teknik olarak güvenli sınır:

- ham Places/Geocoding response'u kalıcı tutma,
- final formda kullanıcıya alanları gösterip açıkça onaylat; fakat onayı tek başına saklama lisansı sayma,
- kullanıcı tarafından gerçekten girilen/düzeltilen alanı provider cevabından veri soyunda ayır,
- provider place ID ve veri kaynağını işaretle,
- geçici cache'e TTL ve silme görevi koy,
- attribution ve legal notices gereksinimini uygula. Places içeriği Google haritası dışında gösteriliyorsa Google Maps attribution/logo gereksinimini de uygula.

Google Maps for Flutter dokümanı, uygulamada erişilebilir bir Legal Notices/About alanında lisans attribution metninin gösterilmesini ister. [Google Maps for Flutter overview](https://developers.google.com/maps/flutter-package/overview)

### Uygulama gizliliği

- Arama sorgusu, tam adres ve koordinat loglanmamalı.
- Analytics'e tam `LatLng` değil event sonucu (`selected`, `manual`, `no_result`) gönderilmeli.
- Public API'de bireysel ev adresi ve tam koordinat varsayılan olmamalı.
- Silme/anonimleştirme politikası adres snapshot'larının iş, ödeme ve yasal saklama zorunluluğuyla birlikte tanımlanmalı.
- App Store privacy beyanı Google Maps SDK ve Koala backend'inin işlediği kesin konumu kapsamalı. Apple, üçüncü taraf SDK'ların veri uygulamalarının da beyan edilmesini ister. [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

KVKK açısından açık adres ve kesin koordinat kimliği belirli/belirlenebilir gerçek kişiyle ilişkilendirildiğinde kişisel veri olarak ele alınmalıdır. Veri toplanırken veri sorumlusunun kimliği, amaç, aktarım tarafları/amaçları, yöntem-hukuki sebep ve ilgili kişi hakları açıkça bildirilmelidir; aydınlatma ile açık rıza gerekiyorsa bunlar ayrı süreçlerdir. Adres sorgusu ve koordinatın Google'a gönderilmesi de yurt dışına aktarım analizi gerektirir; mevcut KVKK rejimindeki yeterlilik, uygun güvence veya sınırlı arızi hâllerden hangisine dayanıldığı belgelenmelidir. [KVKK aydınlatma yükümlülüğü](https://www.kvkk.gov.tr/Icerik/2033/Aydinlatma-Yukumlulugu-), [KVKK 2026 aydınlatma/açık rıza ilke kararı](https://www.kvkk.gov.tr/Icerik/8710/veri-sorumlulari-tarafindan-acik-riza-ve-aydinlatma-metinlerinin-ayri-ayri-duzenlenmesi-gerektigi-hakkinda-kisisel-verileri-koruma-kurulunun-18-02-2026-tarihli-ve-2026-347-sayili-ilke-kararina-iliskin-kamuoyu-duyurusu), [KVKK yurt dışına aktarım](https://www.kvkk.gov.tr/Icerik/2053/Yurtdisina-Aktarim), [KVKK veri güvenliği yükümlülükleri](https://www.kvkk.gov.tr/Icerik/2040/Veri-Guvenligine-Iliskin-Yukumlulukler)

Google Maps Platform'ın mevcut genel şartları, Google'ın hizmet sırasında arama terimi, IP ve koordinat toplayıp ürünleri sağlama/iyileştirme amacıyla kullanabileceğini; müşteri uygulamasının konum türünü ve başka verilerle birleşimini önceden bildirmesini ve son kullanıcı konumunu ancak açık, önceden verilmiş, geri alınabilir onayla elde edip cache etmesini şart koşuyor. Aynı şartlar müşterinin Google'a son kullanıcı PII'si ve Avrupa kullanıcısının Personal Data'sını sağlamamasını da söylüyor. Bu yüzden bireysel ev adresi sorgusuna kullanıcı adı, e-posta, hesap ID'si veya başka tanımlayıcı eklenmemeli; yazılan exact ev adresinin bu sözleşme yasağına girip girmediği Cloud hesap sahibi/hukuk tarafından onaylanmadan production'a çıkılmamalıdır. OS konum izni, bu sağlayıcıya veri aktarımı açıklamasının yerine geçmez. [Google Maps Platform Terms, 4.4](https://cloud.google.com/maps-platform/terms)

GDPR Koala'ya otomatik olarak yalnızca “konum verisi var” diye uygulanmaz; AB'de kuruluş, AB'deki kişilere mal/hizmet sunma veya davranış izleme gibi Article 3 bağları ayrıca değerlendirilmelidir. Uygulanıyorsa amaçla sınırlılık, veri minimizasyonu, doğruluk, saklama sınırı, privacy by default ve riskle orantılı güvenlik kuralları exact/public ayrımını destekler. Uygulanmasa bile bunlar iyi ürün güvenliği ölçütüdür. [GDPR Articles 3, 5, 25 ve 32 — EUR-Lex](https://eur-lex.europa.eu/eli/reg/2016/679/oj)

## 7. Hata ve fallback davranışı

Gerçek servis kullanmak, provider geçici olarak çalışmadığında kullanıcıyı kilitlemek zorunda değildir. Dummy sonuç üretmeden şu fallback uygulanabilir:

| Durum | Davranış |
|---|---|
| Places timeout/5xx | Retry CTA; manuel adres + pin seçimine izin ver |
| Autocomplete sonucu yok | Kullanıcının yazdığı metni koru; haritada manuel seçim sun |
| Place component iç city/district ile eşleşmedi | İç referans seçiciyi aç; kullanıcıdan doğrulama iste |
| Reverse geocode sonucu yok | Pini koru; açık adres alanını kullanıcı doldursun |
| Konum izni reddedildi | Arama ve harita manuel çalışmaya devam etsin |
| Harita anahtarı yetkisiz | Uygulama içinde açıklayıcı hata/yeniden dene; native log ve monitoring alarmı üret |

Backend hiçbir durumda sahte adres/koordinat döndürmez. Final kayıt daima kullanıcının görüp onayladığı gerçek formdan gelir.

## 8. Test stratejisi

“Runtime'da dummy yok” ilkesi, otomatik testlerde Google sınırının kontrollü test double ile test edilmesine engel değildir. Üretim kodunda fake service seçeneği bulunmamalı; test yalnızca dış HTTP istemci portunu taklit etmelidir.

### Backend

- Component type → iç ülke/il/ilçe ID eşleme unit testleri.
- Türkçe Unicode/locale ve alias testleri: `İstanbul/Istanbul/ISTANBUL`, `Kadıköy/KADIKÖY`, `I/İ/ı/i`, baş/son/tekrarlı boşluk ve provider'ın farklı administrative level çıktıları. Normalizasyon yalnız arama/eşleme içindir; canonical gösterim adı iç referanstan gelir.
- İstanbul referans bütünlüğü: 39 aktif ilçe; `EMİNÖNÜ` yeni seçimlerde yok; eski Eminönü kaydı için kontrollü `FATİH` alias/migration testi.
- Eksik district, yanlış parent city, TR dışı sonuç, hizmet alanı dışı koordinat.
- Aynı `searchSessionId`ye bağlı provider token'ının resolve ile kapanması; bitmiş ID/token'ın reddi.
- Kısa ömürlü `candidateToken`ın kullanıcıya bağlı, tek kullanımlık ve süre aşımında geçersiz olması; başka kullanıcı/başka candidate ile replay edilememesi.
- Google timeout, 429 ve 5xx dönüşümü; retry sınırı.
- Ucun keyfi Google URL/field mask relay edemediği güvenlik testi.
- `AddressWriteV2`nin eski `countryCode/cityName/districtName/addressLine` body alanlarını reddetmesi ve final write yolunda isimle repository lookup bulunmaması.
- Final adresin PostgreSQL'e yazıldığı integration test ve Liquibase doğrulaması.
- Public DTO'nun tam bireysel adres/koordinat sızdırmadığı sözleşme testi.
- Anonim, ilan sahibi, şirket yetkilisi, başvuran, kabul edilmiş çalışan ve terminal atama durumlarının her biri için exact endpoint authorization matrisi.
- Provider cache alanlarının seçilen lisans politikasındaki TTL/silme kuralına uyduğu test.

### Mobil

- 0–2 karakterde istek yok; debounce sonrası tek istek.
- Eski autocomplete yanıtı yeni sorguyu ezmiyor.
- Seçim aynı `searchSessionId` ile resolve oluyor; sonra ID yenileniyor.
- Konum izni reddedilse de arama/manual pin çalışıyor.
- iOS reduced accuracy ve Android approximate konumda kullanıcı arama/manual pin akışına devam ediyor; yaklaşık cihaz konumu exact adres diye sessizce kaydedilmiyor.
- Pin değişince reverse geocode loading/error/confirm durumları.
- Kullanıcının `floor`, `unitNumber` ve `additionalDirections` düzeltmeleri provider cevabıyla silinmiyor.
- Kullanıcı, şirket ve iki ilan oluşturma akışı aynı `AddressWriteV2` JSON'unu gönderiyor; eski isim tabanlı alanlar hiçbir istekte yok.

### Gerçek smoke test

- iOS simulator: gerçek, bundle-restricted development key ile harita karoları.
- Android emulator: package + debug SHA-1 restricted development key ile harita karoları.
- Gerçek backend + gerçek Places/Geocoding projesiyle bir İstanbul adresi autocomplete → resolve → pin → DB → tekrar okuma.
- Xcode/Android loglarında key rejection yok; Cloud metrics'te istek doğru anahtara/API'ye yazılıyor.

## 9. Önerilen uygulama sırası ve commit sınırları

Her madde ayrı, çalışan ve test edilmiş bir commit adayıdır. Agent commit/push yapmamalı; sadece kullanıcıya stage listesi ve mesaj önerisi vermelidir.

1. **Sağlayıcı/lisans ve gizlilik kararı**
   Google kaynaklı adres ve koordinatın kalıcı, çok kullanıcılı ilan verisi olarak saklanma/yayınlanma modeli; KVKK yurt dışı aktarım mekanizması; retention ve privacy notice hukuk/ürün tarafından yazılı kapatılır. Bu karar DB şemasından önce verilmelidir.

2. **Tek v2 contract'ı dondur**
   `AddressWriteV2`, `AddressCandidate`, public/exact read projection'ları ve sabit error enum'ları OpenAPI'de tanımlanır. Eski isim tabanlı body'nin kaldırıldığı ve compatibility adapter/dual-write olmayacağı ADR'de yazılır; iki repo aynı contract fixture'a bağlanır.

3. **Referans veri ve canonical schema**
   Eminönü→Fatih auditli migration/alias; yalnız 39 aktif İstanbul ilçesi; Liquibase ile yapılandırılmış bileşenler, position/source, confirmation/version ve `needsReview` alanları. Name lookup final write yolundan tamamen çıkarılır.

4. **Backend gerçek location gateway**
   Dar autocomplete/resolve/reverse uçları; server-side Google kimliği; rate limit, timeout, maskeleme ve mapping testleri.

5. **Harita konfigürasyonu ve gözlemlenebilirlik**
   iOS staging tamamlandı. Android ve production flavor'ları gerçek, git dışındaki platform-kısıtlı anahtarlarla smoke test edilir; placeholder/boş key için güvenli startup teşhisi ve CI secret sözleşmesi doğrulanır.

6. **Mobil ortak adres seçici**
   `product/` altında autocomplete state + ortak onay/pin ekranı; no-permission ve provider-error fallback testleri.

7. **Bütün yazma akışlarını v2'ye taşı**
   Kullanıcı adresi, şirket oluşturma ve şirket/bireysel ilan oluşturma aynı `AddressWriteV2` sözleşmesine geçirilir; sabit `İSTANBUL`, serbest district ve bütün `countryCode/cityName/districtName/addressLine` write alanları kaldırılır.

8. **Konum görünürlüğü**
   Public approximate/exact DTO ayrımı; bireysel işveren adresi koruması; accepted assignment için exact endpoint/authorization testleri.

9. **Migration provası ve hard cutover**
   Production-benzeri snapshot üzerinde backfill/review sayımları, Eminönü dönüşümü ve rollback provası yapılır. Backend v2 ile mobil v2 bakım penceresinde açılır; minimum sürüm kapısı eski istemciyi durdurur, legacy write endpoint kaldırılır.

10. **Operasyon ve hukuk**
   Google attribution/legal notices, App Store privacy declaration, dashboard/kota/bütçe alarmları, Place ID yenileme ve saklama politikası.

## 10. Kabul kriterleri

- iOS ve Android haritası gerçek, platforma özel kısıtlı anahtarla açılır.
- Mobil binary'de Places/Geocoding web-service anahtarı yoktur.
- Adres önerileri ve ters geocoding yalnızca Koala backend'i üzerinden gerçek Google servisine gider.
- Kullanıcı, şirket ve ilan adreslerinin lisans kararına uygun final canonical hali PostgreSQL'dedir; runtime fake/dummy fallback yoktur.
- Hiçbir akış il/ilçe adını güvenilir kimlik olarak kullanmaz; iç UUID kullanır.
- Tek write şeması `AddressWriteV2`dir; `countryCode/cityName/districtName/addressLine` kabul eden legacy DTO/endpoint, adapter ve dual-write yoktur.
- Autocomplete/resolve/reverse aynı `AddressCandidate` döndürür; provider place ID ve ham provider JSON mobil final write/read sözleşmesine sızmaz.
- Türkçe normalizasyon `İstanbul/Istanbul/ISTANBUL` ve `I/İ/ı/i` varyantlarını eşleme katmanında çözer; DB/read response her zaman iç referansın canonical Türkçe adını döndürür.
- İstanbul'da 39 aktif ilçe gösterilir; `EMİNÖNÜ` yeni adres seçeneği değildir ve eski kayıtlar veri kaybı olmadan `FATİH` ile uzlaştırılır.
- Şirket oluşturma ekranında `İSTANBUL` hardcode'u ve serbest district yoktur.
- Adres metni ile pin aynı onay ekranında görülür; kullanıcı onayı olmadan provider sonucu kaydedilmez.
- Konum izni adres arama için zorunlu değildir.
- Reduced/approximate cihaz konumu adres formunu kilitlemez ve kullanıcı onayı olmadan exact adres olarak kaydedilmez.
- Türkiye'de desteklenmeyen Address Validation API'ye bağımlılık yoktur.
- Bireysel işverenin tam adresi ve koordinatı public job endpoint'inden sızmaz.
- Exact adres yalnız yetkili işveren/şirket kullanıcısı ve aktif, kabul edilmiş çalışana server-side authorization ile açılır; durum/yetki değişince mobil cache'ten de temizlenir.
- Autocomplete token, field mask, quota ve log maskeleme kuralları testlerle korunur.
- Migration provası mevcut FK/koordinat taşımasını, `LEGACY_UNVERIFIED + needsReview`, Eminönü→Fatih auditini, rollback'i ve legacy endpoint'in kapanmasını doğrular; serbest adres heuristik parçalanmaz.
- Google kaynaklı alanların DB saklama süresi, cache silme davranışı, attribution ve public yeniden gösterim hakkı yazılı sağlayıcı/lisans kararıyla ve testlerle korunur.
- KVKK aydınlatma, aktarım tarafı/amacı, hukuki sebep, yurt dışı aktarım mekanizması ve retention ürün ekranı/mahremiyet metninde belgelenir; gerekiyorsa açık rıza aydınlatmadan ayrı alınır.

## 11. Uygulama öncesi açık kararlar

1. **P0 — sağlayıcı ve kalıcı veri lisansı:** Google Places/Geocoding'den türeyen exact adres/koordinat public ilan ve çok kullanıcılı DB için hangi hukuki/lisanslı modelle saklanacak? Kullanıcı tarafından bağımsız girilen first-party veri ayrımı yeterli mi, başka sağlayıcı mı seçilecek, yoksa süreli cache + yenileme mi uygulanacak?
2. **P0 — sağlayıcıya kişisel veri aktarımı:** Google'a giden sorgu/adres/koordinat PII yasağıyla nasıl uyumlu olacak; bireysel ev adresi Google'a gönderilebilecek mi; sağlayıcıya giden payload hangi kullanıcı tanımlayıcılarından arındırılacak?
3. **P0 — KVKK aktarım mekanizması:** Google'a giden sorgu/adres/koordinat için veri akışı, işleme amacı, hukuki sebep, yurt dışı aktarım mekanizması ve saklama süresi nedir? Google'ın istediği geri alınabilir konum onayı KVKK hukuki sebebi ve ayrı aydınlatma/rıza UX'iyle nasıl uyumlanacak?
4. **P1 — İstanbul hizmet alanı:** Yalnızca 39 İstanbul ilçesi mi kabul edilecek; İstanbul dışı adres kayıt edilecek fakat ilan açılamayacak mı? Otorite iç reference ID mi, ayrı lisanslı polygon mu?
5. **P1 — public yaklaşık görünüm:** Yalnız ilçe/mahalle etiketi yeterli mi; haritada nokta gerekiyorsa hangi bağımsız/lisanslı centroid kaynağı ve hangi hassasiyet kullanılacak?
6. **P1 — numarasız iş alanı istisnası:** Park, meydan, fuar alanı gibi dış kapı numarası olmayan konumlarda hangi `siteName + pin + açıklama` kombinasyonu kabul edilecek ve destek ekibi bunu nasıl doğrulayacak?
7. **P1 — exact erişim yaşam döngüsü:** Kabulden ne kadar önce açılacak, hangi terminal durumda kapanacak ve destek/uyuşmazlık işlemleri için kim ne kadar süre görebilecek?
