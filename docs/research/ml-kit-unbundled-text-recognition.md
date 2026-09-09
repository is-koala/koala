# ML Kit Latin OCR: paketli ve Play Services modeli

Tarih: 2026-09-09
Kapsam: Android production all-ABI release APK, `koala/main`

## Sonuç

Latin OCR modelini APK'ya gömen `com.google.mlkit:text-recognition:16.0.1`
yerine Google Play Services üzerinden indiren
`com.google.android.gms:play-services-mlkit-text-recognition:19.0.1`
kullanılmalı. Aynı checkout ve toolchain ile yapılan iki release build arasında
APK **30.885.086 bayt (%23,72)** küçüldü. Koala ilk Android dağıtımını Google
Play üzerinden hedeflediği için bu kazanç, Play Services bulunmayan cihazların
MRZ taramasında elle girişe düşmesi karşılığında kabul edilebilir.

## Kaynak sözleşmesi

Google'ın Android Text Recognition v2 dokümanı iki kurulum biçimini aynı native
API için tanımlıyor:

- Paketli Latin modeli: `com.google.mlkit:text-recognition:16.0.1`; model build
  sırasında uygulamaya statik bağlanıyor.
- Paketsiz Latin modeli:
  `com.google.android.gms:play-services-mlkit-text-recognition:19.0.1`; model
  Google Play Services tarafından dinamik indiriliyor.
- Paketsiz model kurulumdan sonra manifestteki
  `com.google.mlkit.vision.DEPENDENCIES=ocr` metadata'sıyla önceden indirilebilir.
  Bu yapılmazsa ilk tarama indirmeyi başlatır ve indirme bitmeden yapılan
  istekler sonuç üretmez.

Kaynak: [Google ML Kit — Android Text Recognition v2](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)

Projede kilitli `google_mlkit_text_recognition 0.17.1` bir platform-channel
köprüsüdür; OCR Dart içinde çalışmaz. Paket dokümanı Android tarafında varsayılan
Latin desteğini anlatıyor ancak paketli/paketsiz seçim anahtarı sunmuyor. Yerel
pub cache'teki yayımlanmış `android/build.gradle` dosyası Latin bağımlılığını
doğrudan `com.google.mlkit:text-recognition:16.0.1` olarak ilan ediyor. Bu yüzden
uygulama seviyesinde dependency substitution gerekir.

Kaynak: [pub.dev — google_mlkit_text_recognition 0.17.1](https://pub.dev/packages/google_mlkit_text_recognition/versions/0.17.1)

## Ölçüm

İki APK da aynı `koala/main` checkout'unda production flavor ve release modunda,
aynı Flutter/Gradle/Android araç zinciriyle üretildi. İkinci ölçümde yalnız Latin
ML Kit modülü geçici Gradle dependency substitution ile Google'ın paketsiz
modülüne çevrildi; Dart ve native plugin kaynakları değişmedi.

| Varyant | APK bayt | MiB |
| --- | ---: | ---: |
| Paketli ML Kit | 130.210.232 | 124,18 |
| Play Services modeli | 99.325.146 | 94,72 |
| Fark | **30.885.086** | **29,45** |

Paketli APK'da OCR pipeline/model girdilerinin sıkıştırılmamış toplamı
30.959.415 bayttı; paketsiz varyantta bu girdiler APK içinde yoktu. Böylece
boyut farkının başka bir build oynaklığından değil, hedeflenen OCR bağımlılığından
geldiği ayrıca kontrol edildi.

Google'ın dokümandaki yaklaşık 4 MB/script/architecture tahmini tek mimari
etkisidir. Koala'nın all-ABI APK'sında birden fazla native mimari aynı dosyada
taşındığı için ölçülen toplam farkın daha büyük olması beklenir; karar tahmine
değil yukarıdaki artefact ölçümüne dayanır.

## Uygulama ve kullanıcı davranışı

1. Gradle çözümlemesi yalnız
   `com.google.mlkit:text-recognition` modülünü Google Play Services Latin
   modülüne yönlendirmeli ve hedef sürümü açıkça sabitlemelidir.
2. Android manifesti `ocr` install-time model metadata'sını taşımalıdır. Play
   Store kurulumu sonrasında Play Services modeli mümkün olduğunca kimlik
   ekranına gelmeden indirir.
3. Kimlik ekranı modelin ilk kez hazırlanabileceğini kullanıcıya tarama öncesinde
   söylemelidir. Ağ yoksa veya Play Services modeli kullanılamıyorsa tarama
   sonsuza kadar yüklenmemeli; mevcut belge numarası, doğum tarihi ve son
   geçerlilik tarihiyle elle giriş yolu açık kalmalıdır.
4. Android build sözleşme testi paketli modülün çözülmediğini, paketsiz modülün
   ve manifest metadata'sının bulunduğunu korumalıdır. Release APK boyutu her CI
   koşusunda sabitlenmemeli; toolchain ve native bağımlılıklar doğal olarak
   değişir. Bu ölçüm karar tabanıdır.

## Riskler ve geri dönüş koşulu

- Play Services bulunmayan Android cihazlarda otomatik MRZ taraması çalışmayabilir;
  elle giriş ürünün desteklenen fallback'idir.
- Install-time indirme tamamlanmadan ilk tarama boş sonuç verebilir. UI bu durumu
  sıradan “MRZ okunamadı” ile birleştirmemeli; model hazırlığı/ağ mesajı ve tekrar
  deneme sunmalıdır.
- Flutter eklentisi gelecekte doğrudan paket seçimi sunarsa Gradle substitution
  kaldırılıp eklentinin resmi seçeneğine geçilmelidir.
- Native API veya dependency graph değişirse release build, gerçek Google Play
  Services bulunan Android cihaz/emülatör smoke testi ve APK içerik ölçümü yeniden
  yapılmadan sürüm yükseltilmemelidir.
