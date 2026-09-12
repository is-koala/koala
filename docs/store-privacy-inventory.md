# Mağaza gizlilik ve Data Safety envanteri

Bu çalışma tablosu uygulama kodu, backend akışları ve kullanılan SDK'lar için
tek kaynak envanteridir. App Store gizlilik etiketleri ile Play Data Safety
formu bu tablodan **ayrı** üretilir; iki mağazanın taksonomisi birebir değildir.
Son beyan, gerçek production trafiği ve saklama politikası hukuk/ürün sahibiyle
doğrulandıktan sonra hesap sahibi tarafından mağaza konsollarında yayımlanır.

| Veri ailesi | Koala örnekleri | Amaç | İşleme / paylaşım kontrolü | Mağaza inceleme adayı |
| --- | --- | --- | --- | --- |
| İletişim ve hesap | Ad, soyad, e-posta, telefon, kullanıcı kimliği | Hesap, güvenlik ve iletişim | Koala backend; e-posta/SMS sağlayıcıları gerçek üretim ayarına göre doğrulanır | Contact Info, User ID |
| Konum | Yaklaşık konum, onaylı adres, iş konumu ve gerekli akışlarda koordinat | Yakındaki ilan, adres ve mesai güvenliği | Cihaz izni + Koala backend + Google Maps SDK; precise/approximate ayrımı trafikle doğrulanır | Location |
| Kimlik belgesi | TCKN, belge no, doğum tarihi; çip okunduğunda SOD/DG1 ve varsa DG11/DG15 + imza | Kimlik doğrulama ve dolandırıcılık önleme | Backend saklama/anonimleştirme kapsamı ayrıca onaylanır; **DG2 hiç gönderilmez**, çip kanıtı isteğe bağlı ve kart okunmadan da doğrulama tamamlanıyor | Other Personal Info, Sensitive Info |
| Kamera görüntüsü | Kimlik kartının arka yüzünün canlı kamera kareleri | Kartın makine okunabilir alanını (MRZ) okumak | **Cihazdan çıkmıyor**: yalnız kadraj bölgesi yerel ML Kit modeliyle, sırayla tek kare işlenir; yalnız türetilen belge no / doğum / son geçerlilik çipi açmak için kullanılır. Ham kare dosyaya, geçici alana veya loga yazılmaz; backend'e gönderilmez ve saklanmaz | Photos (yalnız cihaz içi işleme) |
| Özgeçmiş ve profil | CV dosyası, profil resmi, deneyim, eğitim, nitelik ve ilgi alanı | İş başvurusu ve profil | Koala dosya deposu/backend; yetkili işveren erişimi | Files and Docs, Photos, User Content |
| Mesaj ve başvuru içeriği | Sohbet metni, ön yazı, değerlendirme, uyuşmazlık gerekçesi | Pazaryeri iletişimi ve işlem desteği | Koala backend; yetki ve saklama süresi ayrıca doğrulanır | Messages, Other User Content |
| Ödeme ve çalışma | Ödeme denemesi/sonucu, IBAN'ın girilen değeri, atama, mesai, fatura bağı | Escrow, ödeme, yasal kayıt ve destek | Iyzico ve Koala backend; ödeme kartı uygulama tarafından tutulmaz | Purchases, Payment Info |
| Cihaz ve güvenlik | Install/device id, oturum, IP'nin sunucu tarafı kullanımı, User-Agent | Oturum güvenliği, kötüye kullanım önleme | Secure storage ve backend; provider logları dahil incelenir | Device or Other IDs |
| Tanılama ve kullanım | Hata, performans, ağ ve uygulama etkileşimi kayıtları | Güvenilirlik ve destek | Mevcut SDK/servisler tek tek incelenir; Sentry eklenirse PII filtresi ve IP saklamama zorunludur | Crash Data, Performance, Diagnostics, App Interactions |

## Üçüncü taraf ve SDK kontrolü

- `google_maps_flutter`: konum ve harita etkileşimi; production key paket/bundle
  kimliği ve yalnız gerekli API'lerle kısıtlanır.
- `geolocator`: cihaz konum izni; yalnız kullanıcı akışında istenir.
- `image_picker` ve `file_picker`: seçilen logo, profil görseli, kimlik/CV dosyası;
  bütün galeriye sürekli erişim varsayılmaz.
- `camera`: TCKK MRZ taramasında canlı arka kamera önizlemesi ve bellek içi
  kare akışı; ham kare saklanmaz, loglanmaz veya ağ üzerinden gönderilmez.
- `flutter_nfc_kit` ve `dmrtd`: kimlik kartının çipini ICAO 9303 üzerinden
  okur. Trafik yalnız cihaz ile kart arasında; okunan veri gruplarından
  **yalnız** SOD, DG1 ve varsa DG11/DG15 doğrulama isteğine eklenir. Ağ
  bağlantısı yok, üçüncü tarafa aktarım yok. `dmrtd` LGPL-3.0/ticari ikili
  lisanslı — mağaza yayınından önce hukuk onayı gerekiyor.
- `google_mlkit_text_recognition`: MRZ okuması için **cihaz içi** metin
  tanıma. Android Latin modeli Play Services üzerinden hazırlanabilir ama
  kamera kareleri ML Kit'in yerel işlem sınırında kalır; Koala backend'ine
  veya Google'a görüntü yüklenmez. Kullanılmayan dört dil modeli R8
  kurallarıyla dışarıda bırakıldı (`android/app/proguard-rules.pro`).
- `flutter_secure_storage`: tokenları Keychain/Keystore'da yerel saklar.
- `sqflite`: gönderilemeyen mesai olaylarını kullanıcıya göre bölümlenmiş yerel
  kuyrukta saklar; makullük inceleme bayrağı taşıyanlar dahil başarılı sunucu
  onayı alan kayıtlar silinir. Reddedilen/uzlaştırılamayan kayıtlar destek
  görünürlüğü için cihazda kalır ve aynı atamanın sonraki olayını durdurur.
- `connectivity_plus`: yalnız yeniden denemeyi tetikleyen bağlantı türü sinyalini
  üretir; bağlantı bilgisi Koala backend'ine veya tanılama loglarına gönderilmez.
- Iyzico ödeme sayfası platformun güvenli tarayıcı yüzeyinde açılır; ödeme sonucu
  backend'den doğrulanır.
- E-posta, SMS, dosya depolama, gözlemleme ve push sağlayıcılarının production
  adları/veri bölgeleri backend envanteriyle birleştirilmeden form yayımlanmaz.

Her SDK güncellemesinde Apple privacy manifest gereksinimi, Google Play SDK veri
beyanı ve gerçek ağ trafiği yeniden kontrol edilir. "SDK ekledik ama çağırmadık"
tek başına toplanmıyor kararı için yeterli değildir.

## Hesap silme ve saklama

Mobilde Ayarlar → **Hesabı Sil**, gerekçesi isteğe bağlı silme talebini
`POST /legal/account-deletion` üzerinden başlatır. Açık atama, uyuşmazlık veya
bekleyen ödeme talebi geciktirebilir. Hesap silme tamamlandığında ad, telefon,
e-posta, adres, kimlik belgesi, Özgeçmiş, profil görseli ve Mesaj içeriğinin
okunabilir kalmadığı backend kapsam testiyle doğrulanır.

Ödeme, fatura ve sözleşme/rıza kayıtları yasal saklama gerekçesi varsa silinmez;
kimlik bağı ayrıştırılır. Hangi kayıt için hangi süre ve hukuk dayanağı olduğu
retention policy'de yayımlanmadan mağaza formu kesinleştirilmez. Uygulama
kaldırılmış kullanıcı için web Hesap silme kaynağı doğrudan talep başlatmalı;
yeniden uygulama kurulmasını istememelidir.

## Konsol formu teslim kontrolü

- Apple: her veri türü için toplama, kullanıcıyla ilişkilendirme, tracking ve
  amaç ayrı işaretlendi; privacy policy URL production'da erişilebilir.
- Google: collected/shared, zorunlu/isteğe bağlı, kullanım amacı, aktarımda
  şifreleme ve silme talebi alanları gerçek akışla eşleşiyor.
- Her iki form da uygulama + backend + üçüncü taraf sağlayıcıları kapsıyor.
- Hukuk/ürün sahibi saklama sürelerini, yayın sahibi de konsol ekranlarını
  onayladı; tarih ve sürüm release kaydına işlendi.
