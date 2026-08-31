# Kimlik Doğrulama — Flutter Tarafı Araştırma Raporu

**Tarih:** 29 Ağustos 2026
**Kapsam:** Koala'da çalışan ve bireysel işveren kimlik doğrulamasının mobil tarafta nasıl kurulacağı.
**Durum:** Araştırma + karar. Kod yazılmadı, bağımlılık eklenmedi. Backend'e iki istek metni iletildi.

---

## 1. Özet

**NVİ KPS servisi kapandı.** Backend bunun üzerine KPS'yi tamamen kaldırdı ve yerine çip doğrulamasını koydu (`a10856c`). Doğrulama yeniden çalışıyor, başvuru zinciri kopuk değil.

**Yerine gelen şey hazır ama henüz açılmadı — bilerek.** Çip doğrulaması `IDENTITY_PASSIVE_AUTH_ENABLED` bayrağının arkasında, varsayılanı `false`. Backend bunu kasten kapalı bıraktı: kanıt gönderen bir istemci yokken bayrağı açmak herkesi dışarıda bırakırdı. Bayrak kapalıyken sunucu gövdedeki bilgiyi olduğu gibi yazıyor, yani elle yazılmış bir TCKN doğrulanmış sayılıyor; bu arada elde kalan koruma TCKN'nin benzersizliği. İki taraf da bunu biliyor, bayrak uygulama `sod`/`dg1` göndermeye başlayınca açılacak.

**Bu iş şimdilik ertelendi.** Kimlik doğrulama özelliği daha sonra ele alınacak; bu rapor o zamana kadar hazırlık notu olarak duruyor.

Sonuç olarak NFC artık "elle girişi hızlandıran güzel bir ek" değil, **doğrulamanın kendisi**. Doğrulama tamamen cihaza taşınıyor ve üç katmandan oluşuyor:

1. **NFC + OCR** → kart gerçek mi
2. **Yüz eşleştirme** → kart bu kişinin mi
3. **Liveness** → karşıdaki canlı bir insan mı

Bu üçü birlikte, KPS'nin yaptığından **fazlasını** yapıyor: KPS yalnızca "bu beş alan tutarlı mı" diyordu, kartın kimin elinde olduğunu hiç bilmiyordu.

Backend'den istediklerimiz iki metne bölündü:
- `backend-istek-kimlik-dogrulama.md` — KPS çağrısı kalksın, kanıt (`sod` + `dg1`) sunucuda doğrulansın → **karşılandı, üstüne çıkıldı** (bkz. §3.1)
- `backend-istek-bireysel-isveren-kimlik.md` — bireysel işverene de ilan açma ve ödeme öncesi kimlik kontrolü → **henüz cevap yok**

---

## 2. Bugün ne var

### Sunucu

`POST /users/me/identity-verification` → `VerifyIdentityDto`: `firstName`, `lastName`, `birthDate`, `tcIdentityNumber`, `tcDocumentNumber` (kart seri no).

Eskiden `KimlikPaylasimSistemiService` bu beş alanı NVİ'nin `kpspublicv2.asmx` ucuna gönderiyordu. **Servis kapandı, sınıf da kaldırıldı** — `core/utilities/kps/` klasörü artık yok, hiçbir yerden referans verilmiyor.

Bugünkü davranış: `verifyChipEvidence` önce `identityVerificationProperties.isEnabled()` bakıyor; kapalıysa `null` dönüp çıkıyor. Ardından TCKN benzersizliği kontrol ediliyor (`existsByTcIdentityNumber` → `409`), sonra `identityVerified = true` yazılıyor. Yani bayrak kapalıyken **doğrulama diye bir şey yok**, yalnızca benzersizlik var.

Yeni uç: `POST /users/me/identity-verification/challenge`. Yeni alan: `User.tcDocumentNumber`, ayrıca kanıt saklanıyor (`identityEvidenceDigest`, `identityDocumentSigner`).

Doğrulama başarılı olduğunda yapılanlar (bunlar korunmalı): `identityVerified = true`, ad/soyad/doğum tarihi kilitleniyor, `badgeService.evaluate`, `activityNotificationService.identityVerified`, `userProducerService.publishUserProfileUpdated` → bu son event Iyzico alt üye işyeri senkronizasyonunu tetikliyor.

Sunucuda `IdentityVerification` ve `VerificationDocument` entity'leri duruyor ama hiçbir yer onlara dokunmuyor — `IdentityVerification`'ın Lombok anotasyonu bile yok. Kanıt saklamak için doğal yer burası.

### Uygulama

`employee/features/settings/presentation/pages/identity_verification_page.dart` beş alanı elle doldurtan bir form. Artık arkasında doğrulayacak bir merci olmadığı için **tek başına anlamsız** — NFC akışıyla değiştirilecek, ama elle giriş yolu tamamen silinmeyecek (bkz. §7).

---

## 3. Üç katman

| Katman | Neyi kanıtlar | Nerede çalışır | Durum |
|---|---|---|---|
| **1a. Passive Authentication** | Kart gerçek, veri değiştirilmemiş | Cihaz okur, **sunucu doğrular** | Sunucu hazır, bayrak kapalı |
| **1b. Active Authentication** | Kart **kopya değil**, o an fiziksel olarak orada | Cihaz imzalatır, sunucu doğrular | Sunucu hazır, bayrak kapalı |
| **2. Yüz eşleştirme** | Kart bu kişinin | Cihaz | Planlandı |
| **3. Liveness** | Karşıdaki canlı insan | Cihaz | Planlandı |

Bu katmanlar bağımsız; sırayla eklenebilir. Ama 2 ve 3, 1 olmadan anlamsız — neyin neyle eşleştiğini bilmen gerekiyor.

### 3.1 Sunucu ne yapıyor (backend'çinin çip entegrasyonu dokümanı)

Backend istediğimizin ötesine geçti ve **tekrar oynatma (replay) açığını** da kapattı. Sebep doğru: `sod` ve `dg1` bir kart için **sabit** — bir kez okuyan onları sonsuza kadar tekrar gönderebilir. Passive Authentication tek başına bunu engellemiyor.

Çözüm Active Authentication: sunucu tek kullanımlık bir sayı (challenge) üretiyor, çip onu **kendi özel anahtarıyla** imzalıyor. Anahtar çipten hiç çıkmadığı için kopyalanan veri bu imzayı üretemiyor.

**Bunun bize maliyeti:** artık çipten sadece veri okumuyoruz, ona `INTERNAL AUTHENTICATE` komutu da göndermemiz gerekiyor. Kullanacağımız kütüphanenin bunu desteklediği doğrulanmalı — sadece DG okuyan bir kütüphane yetmez.

**Akış sırası kritik:** challenge **önce** alınmalı, çünkü çipe imzalatılacak şey o. Yani ekran açılır açılmaz `POST /users/me/identity-verification/challenge` çağrılıyor, sonra kart okunuyor. Sayı 10 dakika geçerli ve tek kullanımlık.

Gönderilecek gövde, bugünkü beş alanın üstüne: `sod`, `dg1`, `dg11`, `dg15`, `challenge`, `activeAuthenticationSignature`. Hepsi opsiyonel, bayraklar açılana kadar eksik gönderim eski gibi çalışıyor — yani sözleşme bozulmadı, kademeli geçebiliriz.

Veri grupları:

| Grup | Ne için |
|---|---|
| `SOD` | Doğrulamanın tamamı buna dayanıyor. **Zorunlu.** |
| `DG1` | MRZ — TCKN, doğum tarihi, ad soyad. **Zorunlu.** |
| `DG11` | Adın **Türkçe harfli** hâli. Varsa gönderilmeli. |
| `DG15` | Çipin açık anahtarı — kopya kartı eleyen tek şey. Varsa gönderilmeli. |
| `DG2` | Yüz fotoğrafı. **Sunucuya gönderilmiyor**, cihazda kalıyor. |

`DG11` ayrıntısı önemli ve gözden kaçardı: MRZ ASCII'ye katlanmış, yani kartta **ÇAĞRI** yazsa bile `DG1`'de **CAGRI** duruyor, üstelik üçüncü satır 30 karakterde kırpılıyor. Adı `DG1`'den yazsaydık kullanıcının adını bozardık. `DG11`'in hash'i de SOD'da olduğu için güvenlik açısından farkı yok, sadece verisi doğru.

Sunucu ayrıca gönderilen ad soyadı MRZ'yle karşılaştırıyor (Türkçe harfleri katlayarak, kırpılmış adlarda önek uyumuna izin vererek).

### Güven sınırı hakkında dürüst not

Üç katman da cihazda çalışıyor. Bu, iki farklı saldırgana karşı çok farklı sonuç veriyor:

- **Hile yapmaya çalışan normal kullanıcı** (başkasının kimliği, kameraya tutulan fotoğraf/video): vakaların ezici çoğunluğu bu, ve üç katman bunu iyi savunuyor.
- **Uygulamayı değiştiren kişi:** kartı taklit etmeye çalışmıyor, kontrolleri hiç çalıştırmıyor. Doğrudan uca istek atıyor. Katmanların cihazda ne kadar iyi olduğu burada hiçbir şey değiştirmiyor.

İkincisini kapatmanın yolu üç katmanı sunucuya taşımak **değil** — yalnızca birinci katmanın kanıtını (`sod` + `dg1`) göndermek yeterli, çünkü o imzayı üretmenin tek yolu gerçek bir çipe fiziksel olarak dokunmak. Yüz eşleştirme ve liveness cihazda kalabilir. Bu, backend'e iletilen isteğin B planı.

---

## 4. NFC ile TCKK okuma — teknik gerçekler

### Kartta iki ayrı uygulama var

Bunları karıştırmamak kritik:

1. **EKDS uygulaması** (millî). Erişim için NVİ'den alınmış **rol sertifikası** ve güvenlik testlerinden geçmiş bir **KEC (Kart Erişim Cihazı)** gerekiyor. Telefondan yapılamaz, bizim işimiz değil.
2. **ICAO 9303 MRTD uygulaması** (pasaportlarla aynı standart). ISO-DEP üzerinden, **BAC** veya **PACE** ile güvenli kanal. Bankaların ve KYC ürünlerinin telefondan okuduğu taraf burası.

### Güvenli kanal ve okunan veri

Anahtar iki yoldan türetiliyor:

- **MRZ'den** — kartın arkasındaki makine okunabilir bölge. Gereken üç alan: belge numarası, doğum tarihi, son geçerlilik tarihi. Kamerayla OCR ile okunuyor.
- **CAN'dan** — ön yüzdeki 6 haneli Card Access Number, elle yazdırılıyor. Daha az kod, daha çok kullanıcı emeği.

Kanal açıldıktan sonra **DG1** okunuyor: ad, soyad, doğum tarihi, belge numarası, TCKN. Bunlar sunucunun beklediği beş alanın tamamı — yani sözleşmeyi değiştirmeye gerek yok.

**DG2** yüz fotoğrafını taşıyor ve ikinci katmanın referans görüntüsü olarak en doğru kaynak.

### Çözülmesi gereken belirsizlik: DG2

Kaynaklar burada **çelişiyor**, ve bunu netleştirmeden ikinci katman planlanamaz:

- Açık kaynak eMRTD kütüphaneleri DG2'yi okuyabildiğini gösteren örnekler taşıyor.
- EKDS tarafındaki resmî açıklamalar fotoğraf ve biyometrik veri için KEC + rol sertifikası şart diyor.

Bu ikisi büyük ihtimalle farklı uygulamalardan bahsediyor (ICAO tarafı vs. EKDS tarafı), ama **doğrulanmadı.** Üç seçenek var:

| Seçenek | Referans yüz | Not |
|---|---|---|
| **a. DG2 (çipten)** | Yüksek kalite, imzalı | En doğrusu. Yasal durum netleşmeli. |
| **b. Kartın basılı fotoğrafı (OCR/kamera)** | Düşük kalite | Sertifika sorunu yok. Eşleştirme doğruluğu düşer, ışık/açı hassas. |
| **c. Referans yüz yok** | — | Sadece liveness kalır; "kart bu kişinin mi" sorusu cevapsız. |

**Test etmenin en ucuz yolu:** bir TCKK ile açık kaynak bir okuyucuyu deneyip DG2'nin gelip gelmediğine bakmak. Tahminle ilerlenmemeli.

**Formatı hakkında yeni bilgi (backend'çiden):** çipteki fotoğraf büyük olasılıkla **JPEG değil JPEG2000**, ve **CBEFF sarmalı** içinde. Bu, ikinci katman için ciddi bir engel — Dart'ın `image` paketi JPEG2000 açamıyor, standart görüntü kütüphaneleri de açamıyor. Yani DG2'yi okusak bile **çözemeyiz**. Seçenekler: OpenJPEG'i FFI ile bağlamak (yeni native bağımlılık, iki platformda derleme derdi) ya da bunu zaten çözen ticari bir SDK kullanmak. Bu, §5'teki "ticari SDK gerekiyor" değerlendirmesini güçlendiriyor.

### Platform kısıtları

**iOS** — Core NFC. `com.apple.developer.nfc.readersession.iso7816.select-identifiers` entitlement'ına eMRTD AID'i (`A0000002471001`), `Info.plist`'e `NFCReaderUsageDescription`. Ücretli geliştirici hesabı şart, App Store incelemesinde gerekçe sorulabiliyor. İkinci kısıt: iOS okuma sırasında **kendi sistem NFC sayfasını** gösteriyor, bizim tasarımımız altında kalıyor — iOS ve Android aynı ekranla çözülemez.

**Android** — NFC-A + ISO-DEP, izin dışında engel yok. Asıl sorun donanım: anten konumu cihazdan cihaza değişiyor. "Kartı telefonun arkasının üst kısmına koy" görseli ve haptic geri bildirim UX'in yarısı.

### Paket seçenekleri

| Paket | Durum | Not |
|---|---|---|
| `flutter_nfc_kit` | v3.6.2, MIT, Android/iOS, ~278 like | Ham katman: ISO 7816 APDU gönderip alıyor. BAC/PACE'i üstüne koyuyorsun. |
| `dmrtd` (ZeroPass) | GitHub'da, **pub.dev'de yok** | ICAO 9303'ün Dart implementasyonu. BAC/PACE, DG okuma, passive authentication. pub.dev'de olmaması = git referansı = sürüm ve bakım riski. |
| Regula (Document Reader + `flutter_face_api`) | Ticari | Üç katmanı birden veriyor, Flutter modülü resmî. |
| Innovatrics DOT, Microblink, NFCREAD | Ticari | NFCREAD Türkiye'ye özel çalışıyor — TCKK/DG2 sorusunu sormak için en uygun taraf. |

---

## 5. Yüz eşleştirme ve liveness

### Önceki tavsiyem değişti

Raporun ilk sürümünde "bunu şimdi yapmayalım" demiştim. Gerekçelerimden biri geçerliliğini yitirdi: **KPS kapandığı için artık sunucu tarafında hiçbir doğrulama kalmadı.** O zaman bu katmanlar "ekstra güvenlik" oluyordu; şimdi doğrulamanın kendisi. Erteleme tavsiyesi düşüyor.

KVKK tarafı değişmedi ve hâlâ ciddi (aşağıda).

### Seçenekler

**Cihaz üstü, ücretsiz.** ML Kit yüz algılama ile göz kırptırma, kafa çevirtme. Hızlı, bedava, uygulamayı şişirmiyor. Ama bu **gerçek canlılık testi değil** — telefona tutulan bir video bunu geçer. Yüz *eşleştirme* için makul, *liveness* iddiası için değil. Buna "liveness testi yapıyoruz" demek yanlış beyan olur.

**Ticari PAD (Presentation Attack Detection).** 2026 karşılaştırmalarında öne çıkanlar: iProov (kontrollü aydınlatmayla dinamik canlılık), FaceTec (kısa selfie videodan şifreli 3D FaceScan), Regula, Sumsub, Veriff, Incode, Jumio. Gerçek koruma; karşılığında lisans ücreti, 10–30 MB SDK ve çoğunda sunucu bileşeni.

**Değerlendirme:** üçüncü katmanı gerçekten istiyorsak ticari bir PAD gerekiyor. Ara yol yok — ML Kit ile kurulan akış "liveness" adını hak etmiyor. Regula tek sağlayıcıda hem belge hem yüz tarafını verdiği için entegrasyon maliyeti en düşük seçenek gibi duruyor, ama fiyat teklifi alınmadan karar verilmemeli.

### KVKK

Biyometrik veri KVKK'da **özel nitelikli kişisel veri.** Gerekenler: açık rıza (ayrı ve açıkça alınmış, kullanım koşullarına gömülmüş değil), aydınlatma metni, saklama süresi ve imha politikası, yurt dışı aktarım varsa ayrıca değerlendirme (SDK'lar bulut tarafında çalışıyorsa bu gündeme gelir).

**Tercih:** mümkün olduğunca cihazda kalan, sonucu (eşleşti/eşleşmedi) dışında görüntü saklamayan bir çözüm. Hem KVKK yükünü hem saklama riskini düşürüyor.

Koala'nın MASAK/BDDK uzaktan kimlik tespiti yükümlüsü **olmadığını** not edelim — o yükümlülük finansal kuruluşlara ait, ödeme tarafında PSP olarak Iyzico var ve kendi KYC'sini kendisi yapıyor. Yani düzenleyici bir zorunluluk değil, ürün kararı olarak yapıyoruz.

---

## 6. Yol haritası

Backend kendi tarafını hazır edip bayrakların ikisini de kapalı bıraktı, yani kademeli geçebiliyoruz. Sıra backend'çinin önerdiği gibi:

> **Not:** Bu yol haritası ertelendi, sıradaki iş değil. Aşağısı, işe başlandığında hangi sırayla gidileceğinin notu.

### Aşama 0 — Gerçek kartla döküm *(başlandığında ilk iş)*

Backend'in üç sorusu var ve üçünün de cevabı ancak gerçek bir karttan çıkıyor: kart hangi CSCA'ya zincirleniyor, `DG11` var mı, `DG15` var mı. Ellerindeki 12 Türkiye sertifikasının çoğunun adında "Passport" geçiyor — kimlik kartı bunlardan birine bağlanmıyorsa NVİ'den ayrı sertifika istenmesi gerekiyor, ki bu uzun sürebilir.

**Bunun için tam özellikli akışı beklemeye gerek yok.** Tek seferlik, atılacak bir okuma yeterli: `sod.b64` ve `dg1.b64` dosyalarını çıkarıp göndermek. Backend'de tek komutla çalışan bir teşhis aracı hazır bekliyor. Aşama 1'in tasarımını beklerken bu paralel yürütülmeli.

### Aşama 1 — NFC ile kimlik okuma

1. Ekran açılır açılmaz `POST /users/me/identity-verification/challenge` ile tek kullanımlık sayı alınır. **Önce bu** — çipe imzalatılacak şey o.
2. Kamerayla kartın **arka yüzü** okunur, MRZ'den BAC anahtarı türetilir. *(Alternatif: ön yüzdeki CAN'ı elle yazdırmak.)*
3. Kart telefonun arkasına tutulur, güvenli kanal açılır.
4. `DG1`, `DG11`, `DG15`, `SOD` okunur.
5. `INTERNAL AUTHENTICATE` ile challenge'ın **ham baytları** (base64 çözülmüş hâli) çipe imzalatılır. `DG15` yoksa bu adım atlanır, akış yine çalışır.
6. Form **dolu ve salt okunur** açılır, kullanıcı yalnızca onaylar.
7. Hepsi tek istekte `POST /users/me/identity-verification`'a gider.

Bağımlılık: NFC paketi + MRZ OCR paketi. İkisi de yeni, proje kuralı gereği sorulmadan eklenmez. Seçilen NFC kütüphanesinin `INTERNAL AUTHENTICATE` desteklediği önceden doğrulanmalı.

### Aşama 2 — Bayraklar açılıyor *(sunucu tarafı)*

Passive Authentication zorunlu hâle geliyor (uydurma TCKN girilemez), ardından Active Authentication (kopya kart ve tekrar oynatma kapanıyor). Uygulama tarafında yeni iş yok — Aşama 1 doğru yapıldıysa bayrak açılınca çalışıyor. Staging'de uçtan uca denenmeli.

### Aşama 3 — Yüz eşleştirme + liveness

Önkoşullar: `DG2` gerçekten okunabiliyor mu (§4), JPEG2000/CBEFF çözümü ne olacak (§4), vendor ve fiyat, KVKK açık rıza akışı, saklama/imha politikası.

### Aşama 4 — Cihaz bütünlüğü *(backend'çinin önerisi, isabetli)*

Yüz eşleştirme ve liveness cihazda kaldığı için sunucu onların çalıştığına dair kanıt görmüyor — uygulamayı değiştiren biri o iki katmanı atlayabilir. Bunu biyometrik veri taşımadan kapatmanın yolu **Play Integrity (Android) / App Attest (iOS)**: "bu istek değiştirilmemiş uygulamadan geldi" diyen imzalı bir token. §3'teki güven sınırı sorusunun kalan yarısı bu. Konuşulmalı.

### Paralel — bireysel işveren kapısı

Kimlik doğrulaması **herkes için zorunlu**: çalışan işin sigortalı olup olmadığına bakmaksızın her başvuruda, bireysel işveren de ilan açabilmek ve ödeme yapabilmek için. Çalışan tarafındaki kapı sunucuda zaten böyle çalışıyor, dokunulmayacak; eksik olan bireysel işveren tarafı. Backend'e iletildi (`backend-istek-bireysel-isveren-kimlik.md`).

Bu karar, §3'te yazılan güven sınırı endişelerinin bir kısmını da kapatıyor: TCKN artık her zaman çipten geliyor, elle yazılmış bir TCKN sisteme hiç girmiyor. Yani engellenen bir kullanıcının rastgele TCKN uydurup geri dönmesi ya da alt üye işyerinin doğrulanmamış bir TCKN ile açılması gibi durumlar kalmıyor.

---

## 7. UX notları

- **Tek ekran, üç durum:** hazırlık → okuma → sonuç. Sayfa geçişi değil, aynı ekranda dönüşüm.
- **Okuma sırasında kullanıcı telefonu bırakmamalı.** Yazı yetmiyor; animasyonlu kart-telefon görseli ve titreşim gerekiyor.
- **Hata mesajları ayrışmalı.** "Kart hareket etti" ile "bilgiler eşleşmedi" bambaşka iki durum; ikisine aynı metni göstermek kullanıcıyı döngüye sokar.
- **Zaman aşımı ~15 saniye**, sonrasında çıkış yolu sunulmalı.
- **Sonuç ekranında ad ve soyadın kilitleneceği söylenmeli.** Sunucu zaten kilitliyor; kullanıcı önceden bilmeli.
- **NFC başarısız olduğunda ne olacağı ayrıca çözülmeli.** NFC'si olmayan telefon, okunmayan kart, eski model kimlik — hepsi gerçek, ve kimlik doğrulaması herkes için zorunlu olduğundan bu kullanıcı **hiçbir işe başvuramaz**. Yani NFC'nin başarısızlığı doğrudan kullanıcı kaybı demek. Akışın sonunda kullanıcıyı boşlukta bırakmayan bir yol gerekiyor: en azından "neden olmadı" açıklaması, tekrar deneme ve destek kanalı. Bu, ürün tarafında ayrıca karar verilmesi gereken bir konu.
- **iOS akışı ayrı tasarlanmalı** — sistem NFC sayfası devrede.
- **Yüz/liveness adımında rıza ekranı**, akışın içine gömülmüş bir onay kutusu değil, ayrı ve okunabilir bir adım olmalı.

---

## 8. Karar bekleyen maddeler

1. ~~KPS çağrısı kaldırıldı mı?~~ **Cevaplandı:** kaldırılmış, doğrulama çalışıyor. Yerine geçen çip doğrulaması ise bayrak kapalı olduğu için devrede değil — bu, kapatılması gereken açık bir pencere (§1).
2. **Gerçek kartla `sod.b64` + `dg1.b64` dökümü** — backend'in üç sorusunu ve CSCA sertifikası işini bekletiyor. Kritik yol.
3. **DG2 okunabiliyor mu, okunuyorsa JPEG2000/CBEFF nasıl çözülecek?** Aşama 3'ün önkoşulu.
4. **Apple NFC entitlement başvurusu** — Aşama 1'in önündeki tek idari iş, erken başlatılmalı.
5. **Yeni bağımlılık onayı** — NFC + MRZ OCR (Aşama 1), yüz/liveness SDK'sı (Aşama 3). NFC kütüphanesi `INTERNAL AUTHENTICATE` desteklemeli.
6. **Liveness sağlayıcısı ve bütçe** — ücretsiz yolla "liveness" denemez.
7. **Bireysel işveren kimlik kontrolü** — ikinci istek metnine henüz cevap gelmedi.
8. **Cihaz bütünlüğü (Play Integrity / App Attest)** — yüz ve liveness katmanlarının atlanmasını engellemenin yolu. Karar gerekiyor.
9. **NFC okuyamayan kullanıcı ne yapacak?** Doğrulama herkes için zorunlu olduğundan bu kullanıcı uygulamayı hiç kullanamıyor. Ürün kararı gerekiyor.

---

## Kaynaklar

- [flutter_nfc_kit | Flutter package](https://pub.dev/packages/flutter_nfc_kit)
- [ZeroPass/dmrtd — Dart library for reading Biometric Passport](https://github.com/ZeroPass/dmrtd)
- [Elektronik Kimlik Doğrulama Sistemi — SSS](https://www.ekds.gov.tr/sss)
- [Türkiye Cumhuriyeti Kimlik Kartı EKDS Yönetmeliği — Erdemir & Özmen](https://www.erdemirozmen.com/turkiye-cumhuriyeti-kimlik-karti-elektronik-kimlik-dogrulama-sistemi-yonetmeligi)
- [NFC ve Çipli Kimlik Kartları ile KYC Doğrulaması Nasıl Çalışır? — İHS Teknoloji](https://www.ihsteknoloji.com/blog/nfc-ve-cipli-kimlik-kartlari-ile-kyc-dogrulamasi-nasil-calisir/)
- [Android'de NFC Kart Okuma: Kimlik, Ehliyet ve Banka Kartları — Medium](https://medium.com/@ayseyalcinkaya/androidde-nfc-kart-okuma-kimlik-ehliyet-ve-banka-kartlar%C4%B1-a6e6c13a1639)
- [NFCREAD | Mobil Kimlik Kart Okuyucu](https://www.nfcread.com/mobil-kimlik-kart-okuyucu)
- [Regula Face SDK — Liveness Detection](https://docs.regulaforensics.com/develop/face-sdk/web-service/development/usage/liveness/)
- [regulaforensics/flutter_face_api](https://github.com/regulaforensics/flutter_face_api)
- [Innovatrics — NFC Passport reader for iOS, Android and web](https://developers.innovatrics.com/digital-onboarding/technical/remote/dot-ios-nfc/2.2.0/documentation/)
- [10 Best Liveness Detection Software in 2026 — Facia](https://facia.ai/blog/best-liveness-detection-software-providers/)
- [Finans Sektöründe Uzaktan Kimlik Tespitinin Dönüşümü — Lebib Yalkın](https://lebibyalkin.com.tr/makale/finans-sektorunde-uzaktan-kimlik-tespitinin-donusumu-yuz-yuze-kimlik-tespitinden-pasaportla-dijital-musteri-edinimine)
