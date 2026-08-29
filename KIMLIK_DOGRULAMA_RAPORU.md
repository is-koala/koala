# Kimlik Doğrulama — Flutter Tarafı Araştırma Raporu

**Tarih:** 29 Ağustos 2026
**Kapsam:** Koala'da çalışan ve bireysel işveren kimlik doğrulamasının mobil tarafta nasıl kurulacağı.
**Durum:** Araştırma + karar. Kod yazılmadı, bağımlılık eklenmedi. Backend'e iki istek metni iletildi.

---

## 1. Özet

**NVİ KPS servisi kapandı.** Sunucudaki kimlik doğrulama buna dayanıyordu, dolayısıyla bugün çalışmıyor — ve o doğrulama başvuru kapısının ilk şartı olduğu için **şu an hiç kimse hiçbir işe başvuramıyor.** Bu, raporun ilk sürümündeki en büyük değişiklik.

Sonuç olarak NFC artık "elle girişi hızlandıran güzel bir ek" değil, **doğrulamanın kendisi**. Doğrulama tamamen cihaza taşınıyor ve üç katmandan oluşuyor:

1. **NFC + OCR** → kart gerçek mi
2. **Yüz eşleştirme** → kart bu kişinin mi
3. **Liveness** → karşıdaki canlı bir insan mı

Bu üçü birlikte, KPS'nin yaptığından **fazlasını** yapıyor: KPS yalnızca "bu beş alan tutarlı mı" diyordu, kartın kimin elinde olduğunu hiç bilmiyordu.

Backend'den istediklerimiz iki metne bölündü:
- `backend-istek-kimlik-dogrulama.md` — KPS çağrısı kalksın, kanıt (`sod` + `dg1`) sunucuda doğrulansın
- `backend-istek-bireysel-isveren-kimlik.md` — bireysel işverene de ilan açma ve ödeme öncesi kimlik kontrolü

---

## 2. Bugün ne var

### Sunucu

`POST /users/me/identity-verification` → `VerifyIdentityDto`: `firstName`, `lastName`, `birthDate`, `tcIdentityNumber`, `tcDocumentNumber` (kart seri no).

`KimlikPaylasimSistemiService.kimlikDogrula` bu beş alanı NVİ'nin `kpspublicv2.asmx` ucuna `KisiVeCuzdanDogrula` çağrısıyla gönderiyordu ve tek bir `true`/`false` okuyordu. **Servis kapandı, bu çağrı artık sonuç üretmiyor.**

Doğrulama başarılı olduğunda yapılanlar (bunlar korunmalı): `identityVerified = true`, ad/soyad/doğum tarihi kilitleniyor, `badgeService.evaluate`, `activityNotificationService.identityVerified`, `userProducerService.publishUserProfileUpdated` → bu son event Iyzico alt üye işyeri senkronizasyonunu tetikliyor.

Sunucuda `IdentityVerification` ve `VerificationDocument` entity'leri duruyor ama hiçbir yer onlara dokunmuyor — `IdentityVerification`'ın Lombok anotasyonu bile yok. Kanıt saklamak için doğal yer burası.

### Uygulama

`employee/features/settings/presentation/pages/identity_verification_page.dart` beş alanı elle doldurtan bir form. Artık arkasında doğrulayacak bir merci olmadığı için **tek başına anlamsız** — NFC akışıyla değiştirilecek, ama elle giriş yolu tamamen silinmeyecek (bkz. §7).

---

## 3. Üç katman

| Katman | Neyi kanıtlar | Nerede çalışır | Sunucu değişikliği |
|---|---|---|---|
| **1. NFC + OCR** | Kart gerçek, veri değiştirilmemiş | Cihaz + (kanıt doğrulaması) sunucu | Gerekiyor — `sod`/`dg1` doğrulaması |
| **2. Yüz eşleştirme** | Kart bu kişinin | Cihaz | Gerekmiyor |
| **3. Liveness** | Karşıdaki canlı insan | Cihaz | Gerekmiyor |

Bu katmanlar bağımsız; sırayla eklenebilir. Ama 2 ve 3, 1 olmadan anlamsız — neyin neyle eşleştiğini bilmen gerekiyor.

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

### Aşama 1 — NFC ile kimlik okuma *(zorunlu, en öncelikli)*

KPS kapalı olduğu için bu artık iyileştirme değil, kırık zinciri onaran iş.

1. Kullanıcı "NFC ile doğrula"yı seçer.
2. Kamerayla kartın **arka yüzü** okunur, MRZ'den anahtar türetilir. *(Alternatif: ön yüzdeki CAN'ı elle yazdırmak.)*
3. Kart telefonun arkasına tutulur, çip okunur, DG1 alınır.
4. Form **dolu ve salt okunur** açılır, kullanıcı yalnızca onaylar.
5. `POST /users/me/identity-verification` çağrılır — mümkünse `sod` + `dg1` ile birlikte.

Bağımlılık: NFC paketi + MRZ OCR paketi. İkisi de yeni, proje kuralı gereği sorulmadan eklenmez.

### Aşama 2 — Passive Authentication *(sunucu tarafı)*

SOD imzasının DSC üzerinden CSCA'ya zincirlenerek doğrulanması, DG hash karşılaştırması. Uygulama kanıtı gönderir, sunucu doğrular. **Master list güncellendiği için telefona gömülemez**, ayrıca istemcide yapılan doğrulama zaten istemciye güvenmek demektir.

Backend'e iletildi.

### Aşama 3 — Yüz eşleştirme + liveness

Önkoşul: DG2 sorusunun cevabı (§4). Sonra vendor seçimi ve fiyat, KVKK açık rıza akışı, saklama/imha politikası.

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

1. **DG2 rol sertifikası olmadan okunuyor mu?** Aşama 3'ün önkoşulu. Sağlayıcıya sorulmalı ya da bir kartla test edilmeli. Doğrulanmadı.
2. **Apple NFC entitlement başvurusu** — Aşama 1'in önündeki tek idari iş, erken başlatılmalı.
3. **Yeni bağımlılık onayı** — NFC + MRZ OCR (Aşama 1), yüz/liveness SDK'sı (Aşama 3).
4. **Liveness sağlayıcısı ve bütçe** — ücretsiz yolla "liveness" denemez.
5. **Backend'e iletilenlerin durumu** — `sod`/`dg1` doğrulaması, bireysel işveren kimlik kontrolü, `tc_identity_number` unique kısıtı, TCKN'nin cevapta maskelenmesi.
6. **NFC okuyamayan kullanıcı ne yapacak?** Doğrulama herkes için zorunlu olduğundan bu kullanıcı uygulamayı hiç kullanamıyor. Ürün kararı gerekiyor.

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
