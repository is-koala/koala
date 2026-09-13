# Derin bağlantı sözleşmesi

Bu dosya Koala web, backend ve mobil uygulama arasındaki native dönüş
adreslerinin kanonik sözleşmesidir. Mobil uygulamada bu kuralları
`AppLinkDestination` uygular.

## Ortam şemaları

| Ortam | Şema |
|---|---|
| Geliştirme | `koala-dev` |
| Staging | `koala-staging` |
| Production | `koala` |

Uygulama yalnız çalışan flavor'ın tam şemasını kabul eder. Örneğin staging
build'i `koala://...` veya `koala-dev://...` bağlantısını açmaz.

## Kanonik host'lar

Bağlantılar `şema://host?parametreler` biçimindedir. Host'tan sonra path
gelmez.

| Host | Gerekli alanlar | Mobil hedef |
|---|---|---|
| `hesap-dogrula` | `token` | `/auth/register-type/register/creating-password` |
| `sifre-belirle` | `token` | `/auth/register-type/register/creating-password` |
| `sifre-sifirla` | `token` | `/reset-password` |
| `eposta-onayla` | `token` | `/email-verification` |
| `payment-result` | `status`, `assignmentId` | `/payment-result` |
| `company-invitation` | `id` | `/company-invitation` |

## Doğrulanmış HTTPS bağlantıları

Kabul edilen HTTPS hostları flavor'ın **şemasından değil yapılandırmasından**
gelir: `config/<flavor>.json` içindeki `WEB_HOSTS` (virgülle ayrılmış).
Bugün production `iskoala.com,www.iskoala.com`, staging `iskoala.com` —
staging ayrı bir web'e sahip olmadığı ve e-postalar `iskoala.com` ürettiği
için (#155). Development flavor'ı public HTTPS alan adı sahiplenmez
(`WEB_HOSTS` boş). Aynı anahtar Android flavor manifestinin `appLinkHost`
placeholder'ını (`android/app/build.gradle.kts`) ve iOS entitlements
listesini besler; `test/product/router/platform_link_configuration_test.dart`
üçünü birbirine bağlar. Ayrı staging web'i geldiğinde yalnız
`config/staging.json` ve `Runner-staging.entitlements` değişir.

HTTPS yolları:

| Yol | Kanonik hedef |
|---|---|
| `/hesap-dogrula`, `/sifre-belirle`, `/sifre-sifirla`, `/eposta-onayla` | Aynı adlı host |
| `/payment/result` | `payment-result` |
| `/davet/<id>` | `company-invitation` (`id` yoldan okunur, sorgu alanı yok sayılır) |

Örneğin:

```text
https://iskoala.com/hesap-dogrula?token=<registration-token>
https://www.iskoala.com/sifre-sifirla?token=<reset-token>
https://iskoala.com/payment/result?status=success&assignmentId=<id>
https://iskoala.com/davet/<invitation-id>
```

iOS Associated Domains ve Android `autoVerify` yalnız bu ortam hostlarını
sahiplenir; Android tarafının insan adımları `docs/android-app-links.md`
dosyasındadır. Web tarafındaki AASA/`assetlinks.json` da aynı yolları
yayımlar (`/davet` web `appLinkPaths` listesinde henüz yok; iOS için oraya
eklenmesi koala-web işidir). Uygulama kurulu değilse HTTPS adresi web formunda
kalır; mağazaya zorlanmaz. Ödeme dönüşünün HTTPS yolu `/payment/result`, özel
şema hedefi ise geriye dönük uyumluluk için `payment-result` olarak kalır.
Eski özel şema alias'ları yalnız daha önce gönderilmiş e-postalar içindir ve
HTTPS path olarak kabul edilmez.

`eposta-onayla` hedefi şimdilik tokenı kullanıcıya göstermeden taşıyan geçici
karşılama ekranıdır. Kalıcı e-posta doğrulama akışı hazır olduğunda aynı host
korunup bu hedefin davranışı tamamlanacaktır.

## Geriye dönük alias'lar

Daha önce gönderilmiş e-postalar çalışmaya devam etsin diye iki eski host
korunur:

| Alias | Kanonik karşılığı |
|---|---|
| `complete-registration` | `hesap-dogrula` |
| `reset-password` | `sifre-sifirla` |

Yeni bağlantılar alias yerine kanonik host'ları üretmelidir.

## Doğrulama kuralları

- Özel şema ve host tam eşleşir. HTTPS'te yapılandırılmış alan adı ile tek
  kanonik path birlikte tam eşleşir; `http`, API hostu, port ve iç içe path
  kabul edilmez (`/davet/<id>` tek istisnadır: ikinci segment kimliğin
  kendisidir).
- User-info, açık port, fragment veya boş olmayan path taşıyan bağlantı
  reddedilir.
- Her gerekli alan tam bir kez bulunmalı ve boş olmamalıdır. Gerekli alanın
  yinelenmesi bağlantıyı geçersiz yapar.
- `utm_*` gibi bilinmeyen ek query alanları yok sayılır. Mobil rotaya yalnız
  tanımlı gerekli alanlar aktarılır.
- URL'den gelen token veya ödeme durumu başarı kanıtı değildir. Son karar her
  zaman ilgili backend doğrulamasından gelir.

Örnek staging kayıt bağlantısı:

```text
koala-staging://hesap-dogrula?token=<registration-token>&utm_source=email
```

Örnek production ödeme dönüşü:

```text
koala://payment-result?status=success&assignmentId=<assignment-id>
```

`koala:///payment/result?...` biçimi bu sözleşmeye uymaz: host boş, path
doludur. Backend ödeme dönüş adresini yukarıdaki `payment-result` host'una göre
üretmelidir.

## Paket 1 — in-repo bitti, mailbox insan

Flavor kimliği, fail-closed API hedefi, landing yönlendirmesi ve sıkı
`AppLinkDestination` depodadır (#131). Gerçek SMTP gelen kutusu, iki QA hesabı
ve mağaza imzalı Universal Links `ready-for-human` (#7, #27). Apple $99 / NFC
(#129) bu paketi bloklamaz.
