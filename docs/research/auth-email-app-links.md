# Kayıt ve parola sıfırlama bağlantılarının uygulamaya dönüşü

11 Eylül 2026. Kapsam: backend #4 / mobil #7 in-repo dilimi [#131](https://github.com/is-koala/koala/issues/131).
5 Eylül notu **kodun o günkü hâline** aitti; aşağıdaki maddeler o metni geçersiz kılar.
Gelen kutu ve Apple $99 bu belgenin kapsamında değildir.

## Bugün doğru olan (kod)

- Kayıt ve reset e-postaları `AuthLinkService` web landing üretir:
  `https://<AUTH_LINK_PUBLIC_BASE_URL>/hesap-dogrula?token=…` ve
  `/sifre-sifirla?token=…`. GET `/auth-links/**` tokenı **tüketmeden** aynı
  web yollarına 301 verir (`no-store`, `no-referrer`).
- Reset JWT'si `passwordResetTokenService.consume` ile bir kez kullanılır;
  `PasswordResetIT` ikinci kullanımı reddeder. Şablon
  `password-reset-request-template`.
- `AppLinkDestination` yalnız çalışan flavor şemasını ve o flavor'ın HTTPS
  hostunu kabul eder: production `iskoala.com` / `www.iskoala.com`, staging
  `staging.iskoala.com`. User-info, port, fragment, yinelenen token reddedilir.
  Sözleşme: `docs/deep-links.md`, test: `test/product/router/app_link_destination_test.dart`.
- Flavor seçilmeden internet API'sine bağlanılmaz (`ApiConfig`). `config/*.json`
  yalnız `API_BASE_URL` taşır; QA e-posta/parola gömülmez. Canlı giriş
  `integration_test/live_qa_login_test.dart` kimlikleri
  `String.fromEnvironment` ile alır.

## Hâlâ insan (mailbox / mağaza)

- İki kontrollü QA gelen kutusuna gerçek SMTP ve o bağlantıyla login/refresh.
- Universal Links / Play App Links imza ve AASA production hostunda 200
  (`iskoala.com/.well-known/…`). Apple $99 ve NFC #129 beklenmez.
- Ayrı staging API hostu backend #19.

## Kurulu eklenti

`app_links` `uriLinkStream` ilk bağlantıyı ve sonrakileri birlikte verir;
ayrıca `getInitialLink()` aynı tokenı iki kere işlemesin. Yerleşik Flutter
deep-link handler plugin varken kapalı kalır.

## Kabul sınırı

Yanlış ortam / bozuk / eksik / tekrarlı linkler otomatik testlerde kırmızı olur.
Gerçek mail teslimi ve iki iPhone simülatörü #7'de `ready-for-human` kalır.
