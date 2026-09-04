# Koala konum ve adres akışı araştırması

> Karar güncellemesi (5 Eylül 2026): Ortam kimlikleri, ilan bazlı şirket adresi tercihi ve atamaya bağlı tam adres görünürlüğü seçildi. Staging uygulaması bugün mevcut API'yi kullanır; ayrı staging altyapısı kurulmaz. Güncel [uygulama sentezi](../plans/real-api-test-flow.md) ile ADR-0001/0003/0006 esas alınır. Beyaz harita için gerçek kısıtlı platform anahtarı hâlâ gereklidir.

Tarih: 4 Eylül 2026
Kapsam: Flutter iOS/Android uygulaması, Spring Boot API ve PostgreSQL adres modeli
Kaynak ilkesi: Yalnızca mevcut Koala kaynak kodu ile Google, Flutter ve Apple'ın birincil/resmî dokümanları kullanıldı.

## Kısa karar

Koala için önerilen üretim akışı şudur:

1. Kullanıcı adresi metinle arar.
2. Mobil uygulama, Google Places anahtarını taşımadan Koala backend'indeki autocomplete ucunu çağırır.
3. Kullanıcı bir öneri seçince backend aynı oturum belirteciyle Place Details çağrısı yapar, sonucu Koala'nın ülke/il/ilçe kimliklerine eşler.
4. Kullanıcı yapılandırılmış adresi ve pini tek bir doğrulama ekranında görür; eksik mahalle, bina, kapı veya daire bilgisini kendisi tamamlar.
5. Pin elle oynatılırsa backend ters geocoding yapar; bu sonuç tahmin olduğu için elle girilmiş alanları sessizce ezmez.
6. Son onaydan sonra adres Koala veritabanına yazılır. İlan, şirket ve kullanıcı akışları aynı ortak adres sözleşmesini kullanır.

Bu tasarımda çalışma zamanı dummy veri veya test API yoktur. Harita karoları mobilde gerçek Maps SDK ile gelir; adres arama/çözümleme gerçek Google web servislerine yalnızca backend üzerinden gider; kalıcı uygulama verisi PostgreSQL'de tutulur.

Google Address Validation API şu anda Türkiye'yi desteklemiyor. Güncel resmî kapsam tablosunda `TR` bulunmadığı için bu ürün Koala'nın Türkiye adres akışında zorunlu veya önerilen bir bileşen değildir. Kapsam ileride değişirse yeniden değerlendirilebilir. [Google Address Validation kapsamı](https://developers.google.com/maps/documentation/address-validation/coverage)

## 1. Mevcut durum

### 1.1 Harita kurulumu

- Mobil uygulama `google_maps_flutter: ^2.18.0` kullanıyor. Paket Flutter ekibi tarafından yayımlanan, iOS ve Android'in yerel Google Maps SDK'larını saran eklentidir. [Flutter paketi](https://pub.dev/packages/google_maps_flutter)
- iOS'ta [`AppDelegate.swift`](../../ios/Runner/AppDelegate.swift) `GMSServices.provideAPIKey(...)` çağrısını ilk harita oluşmadan önce yapıyor. Bu yerleşim Google'ın önerdiği kurulumla uyumlu. [Maps SDK for iOS kurulumu](https://developers.google.com/maps/documentation/ios-sdk/config)
- Anahtar [`Info.plist`](../../ios/Runner/Info.plist) içindeki `$(MAPS_API_KEY)` build değişkeninden, o da git dışında tutulan [`Secrets.xcconfig`](../../ios/Flutter/Secrets.xcconfig) dosyasından geliyor.
- Yerel `Secrets.xcconfig` gerçek bir Google Maps anahtarı yerine açıkça yetkisiz bir placeholder taşıyor. Bu nedenle mevcut beyaz harita davranışının birincil ve doğrudan nedeni uygulama kodu değil, yetkilendirme yapılandırmasıdır.
- iOS bundle identifier ve Android application id şu anda `com.example.koala`. Bunlar üretim kimliği değil; anahtar kısıtı hangi kimlik için tanımlandıysa binary'nin kimliğiyle birebir eşleşmelidir. Mevcut iOS değeri [`project.pbxproj`](../../ios/Runner.xcodeproj/project.pbxproj), Android değeri [`build.gradle.kts`](../../android/app/build.gradle.kts) içindedir.

Google'ın Flutter kurulum dokümanı, her hedef platform için anahtar verilmesini ve iOS/Android/Web için ayrı, platform kısıtlı anahtarlar kullanılmasını öneriyor. Harita görünmüyorsa ilk kontrolün hedef platforma doğru anahtarın eklenmesi olduğunu da açıkça belirtiyor. [Google Maps for Flutter kurulumu](https://developers.google.com/maps/flutter-package/config)

### 1.2 Bugünkü adres akışları birbiriyle tam uyumlu değil

**Kullanıcı adresi**

[`address_page.dart`](../../lib/employee/features/settings/presentation/pages/address_page.dart) gerçek backend'den ülke → il → ilçe referanslarını çekiyor; açık adres ve posta kodunu kullanıcıdan alıyor; koordinatı ayrı bir harita ekranından seçtiriyor. Ancak kayıt isteği iç referans kimliklerini değil `cityName` ve `districtName` metinlerini geri gönderiyor.

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

### 1.4 Konum mahremiyeti

[`JobsController`](../../../koala-backend/src/main/java/com/exskylab/koala/webAPI/JobsController.java) hem ilan aramasını hem ilan detayını anonim erişime açıyor. [`JobSummaryDto`](../../../koala-backend/src/main/java/com/exskylab/koala/core/dtos/job/response/JobSummaryDto.java) tam koordinatı, [`JobDetailDto`](../../../koala-backend/src/main/java/com/exskylab/koala/core/dtos/job/response/JobDetailDto.java) ise tam `AddressDto`yu döndürüyor. Şirket işyeri için bu ürün kararı olabilir; bireysel işverenin ev adresi için varsayılan olarak fazla açık bir sözleşmedir.

[`location_service.dart`](../../lib/employee/features/home/services/location_service.dart) yaklaşık konum iznini yetersiz sayıyor ve tam konum verilmezse kapatılamayan “uygulamanın çalışabilmesi için” diyaloğu gösteriyor. Oysa adres arama ve manuel pin seçimi cihazın o anki konumunu gerektirmez. Apple, iznin ancak kullanıcı konuma ihtiyaç duyan özelliği kullandığı anda istenmesini ve mümkün olduğunda `When in Use` seviyesinin tercih edilmesini söylüyor. [Apple konum yetkilendirme rehberi](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services), [Apple HIG — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

## 2. Beyaz iOS harita: teşhis ve düzeltme sırası

### P0 — gerçek anahtar

`ios/Flutter/Secrets.xcconfig` içindeki placeholder, Maps SDK for iOS kullanmaya yetkili gerçek geliştirme anahtarıyla değiştirilmelidir. Bu dosya gitignore'da kalmalı; anahtar kaynak koda, README'ye, CI loguna veya commit'e yazılmamalıdır.

Sonra uygulama yeniden derlenip simülatöre kurulmalıdır; `xcconfig` değeri runtime'da uzaktan okunmuyor, binary'nin `Info.plist` çıktısına build sırasında giriyor.

### P0 — Google Cloud tarafı

Aynı Cloud projesinde şu üç koşul birlikte doğrulanmalıdır:

1. Billing bağlı ve etkin.
2. **Maps SDK for iOS** etkin.
3. Kullanılan anahtarın API kısıtı **Maps SDK for iOS**, uygulama kısıtı ise binary'nin tam bundle identifier'ıdır.

Maps SDK for iOS, etkin billing ile her istekte geçerli anahtar/OAuth kimliği ister. [iOS kullanım ve faturalama](https://developers.google.com/maps/documentation/ios-sdk/usage-and-billing) Google ayrıca iOS kısıtında uygulamanın bundle identifier'ının kaydedilmesini ister. [API anahtarı güvenlik rehberi](https://developers.google.com/maps/api-security-best-practices)

Mevcut debug binary için identifier `com.example.koala`dır. Üretim bundle id belirlendiğinde hem Xcode ayarı hem anahtar kısıtı birlikte değiştirilmelidir; yalnızca birini değiştirmek tekrar beyaz/kimlik doğrulamasız haritaya yol açar.

### P0 — logla doğrulama

Harita tekrar çalışmazsa Xcode debug console'daki Maps SDK yetkilendirme mesajına bakılmalıdır. Google'ın iOS örneği, harita görünmediğinde önce API key mesajlarının Xcode konsolundan incelenmesini; sonra bundle-id kısıtı, bağlantı ve izinlerin kontrol edilmesini öneriyor. [Maps SDK for iOS sorun giderme notları](https://developers.google.com/maps/documentation/ios-sdk/current-place-tutorial)

Anahtar değerini loglamayın. Loglanması gereken güvenli tanı bilgisi şunlarla sınırlı kalabilir:

- anahtarın boş olup olmadığı,
- placeholder olup olmadığı,
- bundle identifier,
- build flavor.

### P1 — platform anahtarlarını ayır

Tek anahtarı her yerde kullanmayın:

| Anahtar | Uygulama kısıtı | API kısıtı |
|---|---|---|
| iOS Maps dev/prod | iOS bundle id | Maps SDK for iOS |
| Android Maps dev/prod | package name + ilgili SHA-1 | Maps SDK for Android |
| Backend location service | sunucu IP'si/CIDR veya destekleniyorsa OAuth | Places API (New), Geocoding API |

Android'de debug ve release/Play App Signing sertifikalarının SHA-1'leri farklıdır; yetkilendirilecek her package + SHA-1 çifti açıkça eklenmelidir. [Google API key güvenlik rehberi](https://developers.google.com/maps/api-security-best-practices) Google ayrıca istemci ve sunucu trafiğinin ayrı anahtarlar, ideal olarak ayrı Cloud projeleriyle ayrılmasını; web-service anahtarlarının istemci uygulamaya gömülmemesini öneriyor.

Bu ayrım, mobil Maps SDK anahtarının uygulamadan çıkarılabileceği anlamına gelmez: yerel SDK anahtarı binary'de bulunur ama iOS/Android uygulama kısıtlarıyla korunur. Places/Geocoding REST anahtarı ise gizlidir ve yalnızca backend'de kalır.

### P1 — mevcut native entegrasyonun değerlendirmesi

`GMSServices.provideAPIKey` çağrısının yeri doğru. Beyaz ekran için bu aşamada widget'ı veya yaşam döngüsünü yeniden yazmaya gerek yok. Önce gerçek anahtar, billing, SDK etkinliği ve exact bundle restriction kanıtlanmalıdır.

## 3. Önerilen kullanıcı deneyimi

Bu bölüm, resmî API yeteneklerinden çıkarılan Koala ürün tasarımıdır; Google veya Apple'ın tek bir hazır “iş pazaryeri akışı” olarak tanımladığı bir şablon değildir.

### Adım A — “Adres ara” birincil, “Konumumu kullan” isteğe bağlı

Ekran şu sırada açılmalıdır:

- `Adres ara` metin alanı,
- daha önce kayıtlı adres varsa özet,
- isteğe bağlı `Konumumu kullan` eylemi,
- `Haritadan seç` manuel alternatifi.

Adres yazmak cihaz izni istemez. Konum izni yalnızca kullanıcı `Konumumu kullan` dediğinde istenir. Reddedilirse form çalışmaya devam eder; harita varsayılan olarak seçili il/İstanbul görünümünde açılabilir.

iOS için yalnızca foreground kullanılıyorsa `When in Use` yeterlidir; `Always` yetkisinin ürün gerekçesi yoktur. App Store beyanında backend'e üç veya daha fazla ondalık basamakla gönderilen koordinat Apple'ın “Precise Location” tanımına girer. [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

### Adım B — autocomplete

Mobil her tuşta Google'a doğrudan gitmez. Koala backend'ine örneğin şu isteği yollar:

```http
POST /locations/autocomplete
Authorization: Bearer …
Content-Type: application/json

{
  "input": "Kadıköy Moda Ca",
  "sessionToken": "<uuid-v4>",
  "languageCode": "tr",
  "regionCode": "tr",
  "includedRegionCodes": ["tr"],
  "viewport": {
    "south": 40.80,
    "west": 28.55,
    "north": 41.35,
    "east": 29.50
  }
}
```

Üretim davranışı:

- Yeni odaklanmış arama için yeni UUID v4 session token üret.
- Aynı token'ı bütün autocomplete isteklerinde ve seçimi bitiren resolve isteğinde kullan.
- Seçim tamamlanınca veya oturum terk edilince token'ı tekrar kullanma.
- Üç karakterden önce istek atma; kısa bir debounce uygula ve eski yanıtları request id ile düşür.
- `includeQueryPredictions: false` kullan; adres seçiminde serbest sorgu önerilerine gerek yok.
- Türkiye pazarı için `includedRegionCodes: ["tr"]`, Türkçe çıktı için `languageCode: "tr"` ve `regionCode: "tr"` kullan.
- İstanbul'daki kullanıcıyı öne çıkarmak için `locationBias`/viewport kullan; ürün gerçekten yalnızca İstanbul'da hizmet veriyorsa `locationRestriction` kullan. Bias sonuçları yakınlaştırır, restriction dışarıdakileri eler; ikisi aynı anda kullanılamaz.
- Autocomplete cevap maskesini yalnızca listeyi çizmek için gereken `placeId`, ana metin ve ikincil metinle sınırla.

Google, session token'ın autocomplete sorgularını tek arama oturumu olarak grupladığını; oturumun aynı token'lı Place Details veya Address Validation çağrısıyla bittiğini ve biten token'ın tekrar kullanılmaması gerektiğini belirtiyor. [Places session token](https://developers.google.com/maps/documentation/places/web-service/place-session-tokens) Autocomplete dokümanı ülke kısıtı, dil tercihi, harita viewport bias'ı ve ilk 3–4 karakteri beklemeyi maliyet/performans optimizasyonu olarak öneriyor. [Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)

### Adım C — seçilen place'i backend'de çöz

Kullanıcı öneriye dokununca mobil yalnızca `placeId` ve aynı `sessionToken`ı gönderir:

```http
POST /locations/resolve
Authorization: Bearer …
Content-Type: application/json

{
  "placeId": "…",
  "sessionToken": "…"
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

Google sonucu her zaman daire/bağımsız bölüm gibi `subpremise` ayrıntısını tamamlamayabilir; Autocomplete dokümanı bu durumlarda serbest girdiyi geocoding'e fallback etmeyi özellikle sayıyor. Bu nedenle `addressLine2` benzeri kullanıcı alanı korunmalı ve provider cevabıyla silinmemelidir. [Autocomplete performans/fallback rehberi](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)

Pin hareket ettirilirse kamera durduktan sonra backend'e ters geocoding çağrısı yapılır. Ters geocoding en yakındaki adresi tahmin eder, birden fazla farklı ayrıntı seviyesinde sonuç verebilir ve hiç sonuç bulamayabilir; bu yüzden cevap öneri olarak gösterilir, kullanıcı onayı olmadan mevcut adresi ezmez. [Reverse Geocoding](https://developers.google.com/maps/documentation/geocoding/reverse-geocoding)

### Adım E — DB'ye kaydet

Kullanıcı onayı tek bir `AddressDraft`/`AddressCandidate` nesnesi üretir. Aynı nesne:

- `PUT /users/me/address`,
- `POST /companies`,
- `POST /users/me/jobs`,
- `POST /companies/{companyId}/jobs`

isteklerinde kullanılır. Böylece şirket kaydında sabit İstanbul, ilan kaydında başka DTO ve çalışan adresinde başka validasyon kalmaz.

## 4. Backend ve mobil sorumlulukları

### Mobil

- Arama metni, debounce, session token yaşam döngüsü ve stale-response engelleme.
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
- Koordinat sınırlarını, ülke/hizmet alanını ve il–ilçe ebeveyn ilişkisini doğrulama.
- Son kullanıcı onayını server timestamp ile damgalama ve final adresi PostgreSQL'e yazma.
- Provider query/adres gövdelerini loglarda maskeleme.

Google, client SDK bulunmayan veya mobilde doğrudan REST çağrısı güvenle kısıtlanamayan durumlarda güvenli proxy kullanılmasını; proxy'nin keyfi API relay'i olmamasını, sadece gereken alanları döndürmesini ve istemci erişiminin kimlik doğrulamalı olmasını öneriyor. Koala'nın mevcut ortak Dio/backend yapısı bu model için uygundur. [Google Maps Platform güvenlik rehberi](https://developers.google.com/maps/api-security-best-practices)

## 5. Önerilen veri sözleşmesi

### 5.1 Yazma isteği

```json
{
  "countryId": "uuid",
  "cityId": "uuid",
  "districtId": "uuid-or-null",
  "neighborhood": "Caferağa Mahallesi",
  "addressLine1": "Moda Caddesi No: 12",
  "addressLine2": "Kat 2, Daire 4",
  "postalCode": "34710",
  "latitude": 40.982512,
  "longitude": 29.025411,
  "provider": "GOOGLE",
  "providerPlaceId": "…",
  "source": "AUTOCOMPLETE_CONFIRMED"
}
```

Kurallar:

- İsim değil iç UUID gönderilir. Görünen isimler response DTO'da kalır.
- `districtId` gerçekten isteğe bağlı olacaksa manager bunu kabul eder; Türkiye ürün kuralında zorunlu olacaksa DTO da `@NotNull` olmalıdır. Mevcut çelişki kaldırılmalıdır.
- `providerPlaceId` isteğe bağlıdır; manuel pin ve provider no-result halinde adres kaydı yine yapılabilmelidir.
- `source`: `AUTOCOMPLETE_CONFIRMED`, `REVERSE_GEOCODE_CONFIRMED`, `MANUAL_PIN` gibi denetlenebilir bir enum olmalıdır.
- `confirmedAt` ve `confirmedBy` istemciden güvenilmez; backend üretir.
- Koordinatlar entity'de primitive `double` yerine doğrulanmış `BigDecimal`/PostgreSQL `NUMERIC(9,6)` tutulabilir. Projede check-in/out zaten bu kalıbı kullanıyor.
- Google Place ID için kısa sabit uzunluk varsayılmamalıdır; resmî doküman uzunluğunun değişken olduğunu ve maksimum tanımlanmadığını belirtiyor. `TEXT` veya güvenli geniş bir kolon kullanılmalıdır. [Place IDs](https://developers.google.com/maps/documentation/places/web-service/place-id)

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
  providerPlaceId?
```

Önerilen varsayılan:

- Bireysel işveren ilanı: anonim/listede ilçe veya yaklaşık pin; tam adres yalnızca kabul edilmiş atamanın çalışanına ve işverene.
- Şirket ilanı: şirket açıkça izin verirse tam işyeri konumu public olabilir; aksi halde aynı yaklaşık politika.
- Kullanıcı profili: bugünkü gibi yalnızca il/ilçe.
- Adres sahibi/edit ekranı: tam adres.

Yaklaşık koordinat yalnızca UI'da yuvarlanmamalı; API public DTO'su baştan yaklaşık değer üretmeli ki tam değer ağ cevabından alınamasın.

### 5.3 İlan adresi snapshot olmalı

Bir şirket veya kullanıcı daha sonra profil adresini değiştirince geçmiş/aktif ilanın yeri kendiliğinden değişmemelidir. İlan, yayın anında onaylanan adresin ayrı snapshot kaydına bağlanmalı; düzenleme ayrıca yetkili ilan güncellemesi olmalıdır. Mevcut backend her oluşturma akışında yeni `Address` ürettiği için bu davranışa yakındır ve korunmalıdır.

## 6. Maliyet, saklama ve gizlilik

### Maliyet

- Autocomplete oturum başlangıç/tamamlanma/terk oranını ölç.
- Ortalama autocomplete request/session sayısını ölçmeden sabit fiyat varsayma. Google, yalnızca adres ve koordinat gereken akışta dört veya daha az tahmin isteği ortalamasında per-request autocomplete + Geocoding'in daha ekonomik olabileceğini; daha uzun oturumlarda session + Place Details yaklaşımını öneriyor. [Autocomplete maliyet seçimi](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)
- Field mask'i dar tut; `displayName`, yorum, telefon ve çalışma saatini isteme.
- Kullanıcı başına rate limit, Google Cloud kota ve bütçe uyarısı ekle.
- Provider yanıtlarını uzun süreli genel cache'e alma; session içi kısa yaşamlı UI durumu yeterli.

### Saklama ve Google şartları

Place ID'nin saklanmasına açık istisna vardır; Google bunu daha sonra kullanmak üzere saklamaya izin veriyor ve 12 aydan eski ID'lerin yalnızca `id` alanı istenen ücretsiz/IDs-only detay çağrısıyla yenilenmesini öneriyor. [Place ID saklama ve yenileme](https://developers.google.com/maps/documentation/places/web-service/place-id)

Adres metni ve koordinat gibi diğer Google Maps Content alanlarının kalıcı saklama koşulları kullanılan servise, billing bölgesine ve yürürlükteki hizmet şartlarına bağlıdır. Güncel şartlar değişebildiği için implementasyon öncesi hesabın tabi olduğu mevcut [Google Maps Platform Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms) ve [Places policies](https://developers.google.com/maps/documentation/places/web-service/policies) hukuk/ürün tarafından kontrol edilmelidir.

Teknik olarak güvenli sınır:

- ham Places/Geocoding response'u kalıcı tutma,
- final formda kullanıcıya alanları gösterip açıkça onaylat,
- kullanıcı düzeltmesini ayrı business data olarak kaydet,
- provider place ID ve veri kaynağını işaretle,
- attribution ve legal notices gereksinimini uygula.

Google Maps for Flutter dokümanı, uygulamada erişilebilir bir Legal Notices/About alanında lisans attribution metninin gösterilmesini ister. [Google Maps for Flutter overview](https://developers.google.com/maps/flutter-package/overview)

### Uygulama gizliliği

- Arama sorgusu, tam adres ve koordinat loglanmamalı.
- Analytics'e tam `LatLng` değil event sonucu (`selected`, `manual`, `no_result`) gönderilmeli.
- Public API'de bireysel ev adresi ve tam koordinat varsayılan olmamalı.
- Silme/anonimleştirme politikası adres snapshot'larının iş, ödeme ve yasal saklama zorunluluğuyla birlikte tanımlanmalı.
- App Store privacy beyanı Google Maps SDK ve Koala backend'inin işlediği kesin konumu kapsamalı. Apple, üçüncü taraf SDK'ların veri uygulamalarının da beyan edilmesini ister. [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

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
- Türkçe karakter/alias testleri: `Kadıköy`, `KADIKÖY`, provider'ın farklı administrative level çıktıları.
- Eksik district, yanlış parent city, TR dışı sonuç, hizmet alanı dışı koordinat.
- Aynı session token'ın resolve ile kapanması; bitmiş token'ın reddi.
- Google timeout, 429 ve 5xx dönüşümü; retry sınırı.
- Ucun keyfi Google URL/field mask relay edemediği güvenlik testi.
- Final adresin PostgreSQL'e yazıldığı integration test ve Liquibase doğrulaması.
- Public DTO'nun tam bireysel adres/koordinat sızdırmadığı sözleşme testi.

### Mobil

- 0–2 karakterde istek yok; debounce sonrası tek istek.
- Eski autocomplete yanıtı yeni sorguyu ezmiyor.
- Seçim aynı token ile resolve oluyor; sonra token yenileniyor.
- Konum izni reddedilse de arama/manual pin çalışıyor.
- Pin değişince reverse geocode loading/error/confirm durumları.
- Kullanıcının `addressLine2` düzeltmesi provider cevabıyla silinmiyor.
- Kullanıcı, şirket ve iki ilan oluşturma akışı aynı `AddressDraft` JSON'unu gönderiyor.

### Gerçek smoke test

- iOS simulator: gerçek, bundle-restricted development key ile harita karoları.
- Android emulator: package + debug SHA-1 restricted development key ile harita karoları.
- Gerçek backend + gerçek Places/Geocoding projesiyle bir İstanbul adresi autocomplete → resolve → pin → DB → tekrar okuma.
- Xcode/Android loglarında key rejection yok; Cloud metrics'te istek doğru anahtara/API'ye yazılıyor.

## 9. Önerilen uygulama sırası ve commit sınırları

Her madde ayrı, çalışan ve test edilmiş bir commit adayıdır. Agent commit/push yapmamalı; sadece kullanıcıya stage listesi ve mesaj önerisi vermelidir.

1. **Harita konfigürasyonu ve gözlemlenebilirlik**
   Gerçek iOS/Android development key kurulumu git dışında; placeholder/boş key için güvenli startup teşhisi; README/CI secret sözleşmesi. Native smoke test geçmeden adres UI'sına başlanmaz.

2. **Backend adres sözleşmesi v2**
   Liquibase ile provider/source/mahalle ve iç reference ID alanları; DTO validasyonu; isim yerine UUID; mevcut istemci için bilinçli migration/compatibility kararı.

3. **Backend gerçek location gateway**
   Dar autocomplete/resolve/reverse uçları; server-side Google kimliği; rate limit, timeout, maskeleme ve mapping testleri.

4. **Mobil ortak adres seçici**
   `product/` altında autocomplete state + ortak onay/pin ekranı; no-permission ve provider-error fallback testleri.

5. **Üç yazma akışını taşı**
   Kullanıcı adresi, şirket oluşturma ve şirket/bireysel ilan oluşturma aynı `AddressDraft` sözleşmesine geçirilir; sabit `İSTANBUL` ve serbest district kaldırılır.

6. **Konum görünürlüğü**
   Public approximate/exact DTO ayrımı; bireysel işveren adresi koruması; accepted assignment için exact endpoint/authorization testleri.

7. **Operasyon ve hukuk**
   Google attribution/legal notices, App Store privacy declaration, dashboard/kota/bütçe alarmları, Place ID yenileme ve saklama politikası.

## 10. Kabul kriterleri

- iOS ve Android haritası gerçek, platforma özel kısıtlı anahtarla açılır.
- Mobil binary'de Places/Geocoding web-service anahtarı yoktur.
- Adres önerileri ve ters geocoding yalnızca Koala backend'i üzerinden gerçek Google servisine gider.
- Kullanıcı, şirket ve ilan adreslerinin final hali PostgreSQL'dedir; runtime fake/dummy fallback yoktur.
- Hiçbir akış il/ilçe adını güvenilir kimlik olarak kullanmaz; iç UUID kullanır.
- Şirket oluşturma ekranında `İSTANBUL` hardcode'u ve serbest district yoktur.
- Adres metni ile pin aynı onay ekranında görülür; kullanıcı onayı olmadan provider sonucu kaydedilmez.
- Konum izni adres arama için zorunlu değildir.
- Türkiye'de desteklenmeyen Address Validation API'ye bağımlılık yoktur.
- Bireysel işverenin tam adresi ve koordinatı public job endpoint'inden sızmaz.
- Autocomplete token, field mask, quota ve log maskeleme kuralları testlerle korunur.
