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

## Doğrulanmış HTTPS bağlantıları

Production uygulaması `https://iskoala.com/<host>` ve
`https://www.iskoala.com/<host>` adreslerini; staging uygulaması yalnız
`https://staging.iskoala.com/<host>` adreslerini kabul eder. `<host>` yukarıdaki
beş kanonik addan biri olmalıdır. Development flavor'ı public HTTPS alan adı
sahiplenmez. Örneğin:

```text
https://iskoala.com/hesap-dogrula?token=<registration-token>
https://staging.iskoala.com/sifre-sifirla?token=<reset-token>
https://iskoala.com/payment/result?status=success&assignmentId=<id>
```

iOS Associated Domains ve Android `autoVerify` yalnız bu ortam hostlarını
sahiplenir. Web tarafındaki AASA/`assetlinks.json` da aynı yolları yayımlar.
Uygulama kurulu değilse HTTPS adresi web formunda kalır; mağazaya zorlanmaz.
Ödeme dönüşünün HTTPS yolu `/payment/result`, özel şema hedefi ise geriye dönük
uyumluluk için `payment-result` olarak kalır. Eski özel şema alias'ları yalnız
daha önce gönderilmiş e-postalar içindir ve HTTPS path olarak kabul edilmez.

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

- Özel şema ve host tam eşleşir. HTTPS'te ortam alan adı ile tek kanonik path
  birlikte tam eşleşir; `http`, API hostu, port ve iç içe path kabul edilmez.
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
