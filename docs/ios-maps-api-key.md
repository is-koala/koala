# iOS Google Maps anahtarı

Harita karoları iOS'ta Google **Maps SDK for iOS** ile çiziliyor ve SDK bir
API anahtarı istiyor. Anahtar repoda **yok**; derlemeye gitignore'lu bir
xcconfig dosyasından giriyor. Bu belge anahtarın nereden alınacağını, hangi
dosyaya yazılacağını ve eksikken uygulamanın nasıl davrandığını anlatıyor
(is-koala/koala#172). Anahtarın **değerini** hiçbir yere — commit, yorum,
log, sohbet — yazmayın.

## Anahtar nereden alınır

Google Cloud Console'da Koala projesi (staging ve production için ayrı proje
ya da ayrı anahtar):

1. **APIs & Services → Library → Maps SDK for iOS → Enable.**
2. **APIs & Services → Credentials → Create credentials → API key.**
3. Anahtarı açın ve kısıtlayın:
   - **Application restrictions → iOS apps** — bundle identifier olarak
     yalnız o ortamın kimliğini girin:
     `com.iskoala.koala.staging` (staging), `com.iskoala.koala` (production),
     `com.iskoala.koala.dev` (dev).
   - **API restrictions → Restrict key → yalnız "Maps SDK for iOS".**
     Adres arama ve ters geokod Koala backend'inden geçiyor; bu anahtara
     Places ya da Geocoding açılmaz.
4. Faturalandırma projede açık olmalı; SDK, faturasız projenin anahtarını
   kabul etmez.

`scripts/google-cloud-setup.sh` aynı adımları sırayla sorar ve değeri sizin
yerinize doğru dosyaya yazar; elle yapmak isterseniz aşağıya bakın.

## Dosya adı ve derlemeye girişi

Her flavor yalnız kendi dosyasını okur:

| Flavor | Dosya | Bundle id |
| --- | --- | --- |
| dev | `ios/Flutter/Secrets.dev.xcconfig` | `com.iskoala.koala.dev` |
| staging | `ios/Flutter/Secrets.staging.xcconfig` | `com.iskoala.koala.staging` |
| production | `ios/Flutter/Secrets.production.xcconfig` | `com.iskoala.koala` |

Dosyanın içeriği tek satırdır (değer tırnaksız):

```
MAPS_API_KEY = <anahtar>
```

Zincir şöyle: `ios/Flutter/<Debug|Profile|Release>-<flavor>.xcconfig` önce
`MAPS_API_KEY =` (boş) yazar, sonra `#include? "Secrets.<flavor>.xcconfig"`
ile varsa sizin dosyanızı içerir → `Info.plist`'teki `MAPS_API_KEY` anahtarı
`$(MAPS_API_KEY)` olarak dolar → `AppDelegate.swift` açılışta bu değeri okur
ve boş değilse `GMSServices.provideAPIKey` çağırır. Release CI'da
`mobile-release.yml` aynı dosyayı `KOALA_IOS_MAPS_API_KEY_PRODUCTION`
sırrından üretir (bkz. `docs/release.md`).

Dosyayı ekledikten sonra `flutter build ios` / `flutter run` yeterlidir; pod
kurulumu gerekmez.

## Anahtar eksikse ne olur

- **Derleme kırılmaz.** Runner hedefindeki **Check Maps API Key** build
  phase'i (`ios/scripts/check_maps_api_key.sh`) `MAPS_API_KEY` boşsa bir kez
  `warning:` yazar; `flutter build ios` çıktısında ve Xcode'da görünür:
  `warning: MAPS_API_KEY boş (Debug-staging). ios/Flutter/Secrets.staging.xcconfig dosyası yok ya da anahtar yazılmamış; …`
- **Uygulama çökmez.** `AppDelegate` anahtarı vermediğini
  `com.iskoala.koala/maps_availability` kanalından Dart'a bildirir
  (`lib/product/services/maps_availability.dart`); uygulama açılışta bir kez
  okur ve `Provider` ile dağıtır. Bayrak kapalıyken:
  - keşif haritası (`MapExplorePage`) `GoogleMap` yerine "Harita bu derlemede
    kullanılamıyor" yer tutucusunu çizer ve keşif **liste** görünümüyle açılır;
  - adres ekranı (`MapFirstAddressPage`; çalışan adresi, şirket adresi, ilan
    adresi) haritasız çalışır: arama ve il/ilçe seçimi aynı, pin kayıtlı
    adresin konumu, izin zaten verilmişse cihaz, yoksa İstanbul merkezi olur;
    ters geokod istenmez ve kartta konumun nereden geldiği yazar.

  Eskiden (#172) anahtar yokken ilk harita `GMSServicesException` ile
  uygulamayı çökertiyor, oturum kayıtlı olduğu için sonraki her açılış da
  çöküyordu.
- Android'de aynı kanal manifestteki `com.google.android.geo.API_KEY`
  meta-verisine bakar; anahtar `android/local.properties` içindeki
  `MAPS_API_KEY_<FLAVOR>` değerinden gelir.

Yer tutucuyu anahtar yerindeyken görüyorsanız derlenmiş `Info.plist`'te
`MAPS_API_KEY`'in dolu olduğunu değerini yazdırmadan kontrol edin
(`/usr/libexec/PlistBuddy -c 'Print :MAPS_API_KEY' <Runner.app>/Info.plist | wc -c`).
