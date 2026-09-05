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

- Şema ve host tam eşleşir; benzer adlar ve HTTPS web adresleri native link
  sayılmaz.
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
