# Mobil ortam ve oturum alt teslimi

5 Eylül 2026 — [#7](https://github.com/is-koala/koala/issues/7) içindeki ortam/oturum alt dilimi. Tam kayıt, SMTP, QA hesapları ve harita kabulü ayrı adımlardır; bu belge bunları tamamlandı saymaz.

## Derleme

| Flavor | Uygulama kimliği | Görünen ad | JSON |
| --- | --- | --- | --- |
| dev | com.iskoala.koala.dev | Koala Dev | config/dev-ios.json veya config/dev-android.json |
| staging | com.iskoala.koala.staging | Koala Staging | config/staging.json |
| production | com.iskoala.koala | Koala | config/production.json |

Staging bugün mevcut `https://api.iskoala.com` test amaçlı sunucusunu kullanır; ayrı staging altyapısı kurulmadı. Production JSON'ı da açıkça aynı hedefi içerir; production flavor'ının derlenmesi lansman veya yayın anlamına gelmez. Yerel iOS hedefi `localhost:8080`, Android emülatörü `10.0.2.2:8080` kullanır.

```bash
flutter run --flavor staging --dart-define-from-file=config/staging.json
flutter test --flavor staging --dart-define-from-file=config/staging.json
flutter build apk --debug --flavor staging --dart-define-from-file=config/staging.json
flutter build ios --simulator --debug --no-codesign --flavor staging --dart-define-from-file=config/staging.json
```

Flavor veya API hedefi eksikse uygulama ilk ağ isteğinden önce yapılandırma hatası verir. Dev dışında HTTP kabul edilmez. JSON dosyaları sır içermez; kişisel hedef değişikliği gerekiyorsa Git dışındaki `config/*.local.json` kullanılabilir. `FLUTTER_APP_FLAVOR` elle verilmez.

## Oturum ve bağlantılar

Token'lar, giriş bayrağı ve kullanıcı tipi API köküne göre ayrılır. A API'sinde çalışan, B API'sinde işveren oturumu açıp A'ya dönmek kendi çalışan rolünü geri getirir; A'dan çıkış B'yi silmez. Onboarding ve kurulum kimliği API değişiminde sıfırlanmaz. Eski kapsamsız token ve oturum bayrakları kullanılmaz; yeni uygulama kimliği gerçek giriş gerektirir.

E-posta doğrulama ekranındaki demo geçişi kaldırıldı. Ortama özgü custom scheme'ler `koala-dev`, `koala-staging`, `koala` olarak ayrıldı. Sunucu doğrulama/reset bağlantılarının bu kimliklere dönüşü ve uygulama kapalı/açıkken token tüketimi sonraki auth commit'inde doğrulanacak; yalnız scheme tanımı uçtan uca bağlantı kanıtı değildir.

## Maps sırları

iOS yalnız `ios/Flutter/Secrets.<flavor>.xcconfig` içindeki `MAPS_API_KEY` değerini, Android yalnız `android/local.properties` içindeki `MAPS_API_KEY_DEV`, `MAPS_API_KEY_STAGING` veya `MAPS_API_KEY_PRODUCTION` değerini kullanır. Başka ortamın veya genel dosyanın anahtarına sessiz geçiş yoktur. Bu dosyalar Git dışındadır; JSON'a anahtar konmaz.

Bu alt teslim anahtarsız derlenebilir. Gerçek Maps karoları henüz doğrulanmadı; beyaz harita issue #5 açık kalır. Anahtarların yetkileri [sağlayıcı kurulumunda](provider-setup.md) tamamlanmalıdır.

## Doğrulama sınırı

- Yalnız bu commit'in dosyalarıyla, önceki yayınlanmış HEAD üzerine hazırlanmış temiz kopyada 564 test geçti.
- API hedefi sızıntısı, A→B→A rol karışması ve demo geçişi önce başarısız testlerle gösterildi, sonra düzeltildi.
- Statik analiz ve biçim kontrolü commit öncesi çalıştırılır; feature branch CI bunları tekrarlar.
- Dev, staging ve production iOS simülatör derlemeleri geçti; üretilen bundle ID ve URL scheme değerleri doğrulandı. Son staging derlemesi oturum/demo düzeltmelerini de içerir.
- Yerel makinede Android SDK bulunmadığından Android derleme kanıtı GitHub CI'dan alınır. CI çalışmasının sonucu ayrıca kontrol edilmeden Android başarılı sayılmaz.
- Gerçek SMTP teslimi, iki QA hesabı, gerçek login/refresh ve harita görüntüsü bu alt teslimin kabul kanıtları arasında değildir.

Standards ve Spec incelemeleri ayrı yapıldı; ortak origin/rol bulgusu düzeltildi, yeniden incelemede kapsam içi açık bulgu kalmadı. İlgisiz profil, veri ve ödeme değişiklikleri sonraki commit'lere bırakıldı.
