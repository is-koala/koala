# Raspberry Pi 5 üzerinde Flutter 3.47.1 CI

Tarih: 8 Eylül 2026. Kapsam: `is-koala/koala` deposundaki format, analiz, test ve Android derleme işlerini ARM64 Raspberry Pi 5 self-hosted runner'ında çalıştırma seçenekleri ve gerçek Pi denemelerinin sonucu.

## Sonuç

Tek bir yöntem bütün mobil CI'ı hem native hem resmî destek sınırları içinde Pi'de çalıştırmıyor. En az emülasyon kullanan aday, Flutter/Dart/testleri native ARM64 çalıştırıp yalnız Android'in x64 host araçlarını QEMU/binfmt ile transparan emüle etmek. Tam amd64 konteyner güvenli geri dönüş yolu:

| İş | Pi üzerinde önerilen yol | Durum |
|---|---|---|
| `dart format`, `flutter pub get`, `flutter analyze` | Flutter 3.47.1 kaynak checkout'u + native Linux ARM64 Dart/engine artifact'ları | Uygulanabilir |
| `flutter test` | Aynı native SDK + hatalı frontend-server artifact'ını aynı revizyondaki ARM64 Dart SDK kopyasıyla düzeltme | Gerçek Pi'de 1.251 testle doğrulandı |
| Debug APK | x64 runner veya doğrulanmış, organizasyonun yönettiği amd64 konteyner | Normal Pi CI'da kapalı; yalnız elle tetiklenir |
| Release AAB | x64 runner veya doğrulanmış, organizasyonun yönettiği amd64 konteyner | Pi hostunda doğrulanmadı; yayın akışı fail-fast davranır |
| iOS | `macos-latest` | Pi/Linux üzerinde yapılamaz |

Bu araştırmanın ardından depoda seçilen uygulama şudur: format, analiz ve test
işleri Pi üzerinde native ARM64 çalışır; Flutter 3.47.1 kaynak checkout'u ve
frontend-server düzeltmesi yerel composite action içinde runner'a özel araç
önbelleğine kurulur. Gerçek Pi'de format, analiz ve 1.251 testlik tam suite
geçti. Üç ağır runner'ın eşzamanlı kullanımı daha sonra runner iletişimini ve
microSD yolunu kararsızlaştırdığı için tek runner ve `--concurrency=1` seçildi.

Android APK/AAB işleri normal PR ve `main` koşularında otomatik çalışmaz.
Google'ın x64 Android host araçları için job elle tetiklenebilir, fakat bunun
yeşil olması ancak x64 runner ya da ayrıca doğrulanmış amd64 konteynerle
beklenmelidir.

Apple Silicon üzerindeki `linux/arm64` Docker doğrulamasında Flutter 3.47.1
kaynaktan başarıyla hazırlandı; `flutter analyze --no-pub` ve Koala'nın 1.251
testinin tamamı geçti. Docker Desktop x64 binfmt emülasyonu sağlayabildiği için
bu koşu, hatalı frontend-server dosyasının çıplak Pi'de de açılacağını kanıtlamaz;
bu nedenle composite action yine aynı revizyondaki doğrulanmış ARM64 dosyayı
yerine koyar. Gerçek cihaz kanıtı PR'ın self-hosted CI koşusudur.

Google Maven'daki AGP 9.1 AAPT2 x64 binary'si ayrıca izole bir `linux/arm64`
Debian Bookworm konteynerinde amd64 runtime kütüphaneleriyle çalıştırıldı ve
`Android Asset Packaging Tool (aapt) 2.20-14792394` çıktısı alındı. Bu yalnızca
binary'nin QEMU altında açılabildiğini gösterir; Raspberry Pi OS hostunda paket
kurulumunun güvenli veya destekli olduğunu göstermez.

Gerçek Pi denemesinde Raspberry Pi OS'nin vendor sürümlü arm64 libc paketi ile
Debian'ın amd64 libc adayı aynı sürüme eşlenemedi. `apt`, `libc6:amd64`
kurulumunu bağımlılık çakışmasıyla reddetti; deneme sırasında kart yolu da
`I/O error` ve `Card stuck being busy` kaydetti. Bu makinede hosta `amd64`
mimarisi ve libc eklemek çözüm değildir; tekrar denenmemelidir.

GitHub runner uygulamasının ARM64 Linux desteği olması, job içindeki Flutter ve Android araçlarının da ARM64 olduğu anlamına gelmiyor. GitHub ARM64 Linux self-hosted runner'ı destekliyor; Docker tabanlı action/service kullanımı için Linux ve Docker istiyor. [GitHub self-hosted runner gereksinimleri](https://docs.github.com/en/actions/reference/runners/self-hosted-runners#requirements-for-self-hosted-runner-machines).

## Mevcut hatanın kesin nedeni

`subosito/flutter-action` varsayılan mimariyi `runner.arch` değerinden alıyor. Stable/beta kanalında Flutter release manifestini önce kanala, sonra `dart_sdk_arch`, sonra sürüme göre süzüyor; eşleşme yoksa görülen `Unable to determine Flutter version ... architecture: arm64` hatasını veriyor. [Action girdisi](https://github.com/subosito/flutter-action/blob/v2/action.yaml#L21-L24), [manifest süzme kodu](https://github.com/subosito/flutter-action/blob/v2/setup.sh#L151-L168).

Flutter'ın resmî Linux manifestinde 3.47.1 kaydı yalnız `dart_sdk_arch: x64` ve `flutter_linux_3.47.1-stable.tar.xz` arşivini taşıyor; manifestin tamamında yayınlanmış ARM64 Flutter SDK arşivi yok. [Resmî Flutter Linux release manifesti](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json). Flutter contributor'ı da Linux ARM64 geliştirme için paketlenmiş arşiv yerine ARM64 makinede repo clone edilmesini mevcut yol olarak açıklamış. [flutter/flutter#153378 yanıtı](https://github.com/flutter/flutter/issues/153378#issuecomment-2286865689).

Bu nedenle `architecture: x64` değerini mevcut action'a tek başına eklemek çözüm değildir: action arşivi bulur ama x64 Dart/Flutter çalıştırılabilirleri ARM64 hostta emülasyon olmadan açılamaz.

## Native ARM64 Flutter: nerede çalışır, nerede kırılır?

### Kaynak checkout'u arşiv eksikliğini aşar

Flutter 3.47.1 tag'i `6655482ec06e547f90abf8ae7590466f4415978d`; engine revizyonu `5d531788691ec3404cac0cee66ead4007b177363`. Kaynaktan açılan Flutter launcher, `uname -m` sonucunu ARM64 olarak tanıyıp `dart-sdk-linux-arm64.zip` indirir. Flutter 3.47.1 kaynak kodu Linux/Windows host artifact'larında host mimarisini kullanır ve `linux-arm64/artifacts.zip` yolunu seçer. [Dart SDK mimari seçimi](https://github.com/flutter/flutter/blob/3.47.1/bin/internal/update_dart_sdk.sh#L86-L121), [Flutter SDK artifact seçimi](https://github.com/flutter/flutter/blob/3.47.1/packages/flutter_tools/lib/src/flutter_cache.dart#L252-L284).

Araştırmada aşağıdaki resmî 3.47.1 artifact URL'leri HTTP `200` döndürdü:

- [`dart-sdk-linux-arm64.zip`](https://storage.googleapis.com/flutter_infra_release/flutter/5d531788691ec3404cac0cee66ead4007b177363/dart-sdk-linux-arm64.zip)
- [`linux-arm64/artifacts.zip`](https://storage.googleapis.com/flutter_infra_release/flutter/5d531788691ec3404cac0cee66ead4007b177363/linux-arm64/artifacts.zip)
- [`flutter_patched_sdk.zip`](https://storage.googleapis.com/flutter_infra_release/flutter/5d531788691ec3404cac0cee66ead4007b177363/flutter_patched_sdk.zip)

İndirilen `linux-arm64/artifacts.zip` içindeki `flutter_tester` ve genel `gen_snapshot` dosyaları `ELF ... ARM aarch64` çıktı. Bu, native Flutter tool bootstrap ve ARM64 test embedder'ının mevcut olduğunu gösteriyor.

`subosito/flutter-action` kaynak yolunu da teknik olarak kullanabiliyor: `channel: main` için release manifestini atlıyor, `main` dalını clone ediyor ve verilmiş sürümü checkout ediyor. 3.47.1 ile bu, `channel: main`, `flutter-version: 3.47.1`, `architecture: arm64` bileşimine karşılık gelir. [Action kaynak-checkout dalı](https://github.com/subosito/flutter-action/blob/v2/setup.sh#L225-L235). Ancak bu kullanım tam clone yapar ve action belgelerinde stable ARM64 kurulum yolu olarak taahhüt edilmez. Daha öngörülebilir CI kurulumu, runner'a bir kez `git clone --depth 1 --branch 3.47.1 https://github.com/flutter/flutter.git` ile sabit SDK hazırlamaktır.

### `flutter test` için ek upstream hata var

3.47.1'in `linux-arm64/artifacts.zip` dosyasında `flutter_tester` ARM64 olmasına rağmen `frontend_server_aot.dart.snapshot` hâlâ `ELF ... x86-64`. Aynı kusur Flutter'ın açık ARM64 host bug'ında takip ediliyor ve build'i engellediği belirtiliyor. [flutter/flutter#156309](https://github.com/flutter/flutter/issues/156309).

Fakat aynı engine revizyonunun `dart-sdk-linux-arm64.zip` dosyasındaki `bin/snapshots/frontend_server_aot.dart.snapshot` doğru `ELF ... ARM aarch64` binary'sidir. Bu da araştırmada resmî artifact indirilip `file` ile doğrulandı. Dolayısıyla tam engine derlemek yerine, Flutter cache'indeki yanlış artifact aynı revizyondan gelen doğru ARM64 kopyayla değiştirilebilir:

```bash
flutter precache --linux

file "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot"
file "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/frontend_server_aot.dart.snapshot"

cp \
  "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot" \
  "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/frontend_server_aot.dart.snapshot"
```

İki dosya aynı Flutter 3.47.1 engine revizyonundan geliyor; yapılan şey sürüm karıştırmak değil, upstream paketleme hatasının bıraktığı x64 kopyayı o revizyonun native ARM64 kopyasıyla düzeltmek. Yine de bu resmî bir installer akışı değildir; kopyalama sonrasında hedef dosyanın `file` çıktısı tekrar `ARM aarch64` doğrulanmalı. Ardından standart Koala test komutu önce tek `api_config_test.dart`, sonra tam suite üzerinde gerçek Pi'de çalıştırılmalı.

Flutter 3.47.1 ayrıca test komutunda gizli `--frontend-server-starter-path` seçeneği taşıyor; fakat bu seçenek yalnız Dart kaynağı veya AppJIT snapshot kabul ediyor. 3.47.1 ARM64 Dart SDK arşivinde uygun `frontend_server.dart.snapshot` bulunmadığından bu araştırmada ana çözüm olarak kullanılmadı. [Seçenek davranışı](https://github.com/flutter/flutter/blob/3.47.1/packages/flutter_tools/lib/src/runner/flutter_command.dart#L994-L1004), [test komutunun seçeneği kaydetmesi](https://github.com/flutter/flutter/blob/3.47.1/packages/flutter_tools/lib/src/commands/test.dart#L64-L75).

## Android neden native ARM64 yolun zayıf halkası?

Android'in kendi Linux geliştirme ortamı ARM hostu desteklemiyor. Güncel Android Studio gereksinimi Linux için açıkça ARM tabanlı CPU'ların desteklenmediğini ve x86_64 host istediğini söylüyor. [Android Studio Linux gereksinimleri](https://developer.android.com/studio/install#linux).

Koala AGP 9.1.0 kullanıyor. AGP 9.1.0'ın AAPT2 sürümü `9.1.0-14792394`; Google Maven'daki Linux classifier'ı [`aapt2-9.1.0-14792394-linux.jar`](https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/9.1.0-14792394/aapt2-9.1.0-14792394-linux.jar). Araştırmada jar içindeki `aapt2` `ELF ... x86-64` çıktı; aynı repository'de `linux-arm64` classifier URL'i `404` döndü. Bu araç debug APK paketlemesinde de gerekir.

Release/profile tarafında ayrıca Android AOT `gen_snapshot` host binary'leri sorunlu. Flutter 3.47.1 kaynak kodu Linux için `android-{arm,arm64,x64}-{profile,release}/linux-x64.zip` yollarını sabit kullanıyor; ARM64 host varyantı seçmiyor. [3.47.1 Android host artifact listesi](https://github.com/flutter/flutter/blob/3.47.1/packages/flutter_tools/lib/src/flutter_cache.dart#L905-L912). Native Linux ARM64 Android AOT binary eksikliği upstream'de ayrıca raporlanmış. [flutter/flutter#189724](https://github.com/flutter/flutter/issues/189724).

Sonuç: kaynak checkout'u format/analiz/testi native yapabilir; Android build'i resmî olarak desteklenen native ARM64 toolchain'e dönüştürmez.

### Daha küçük emülasyon sınırı: native Flutter + x64 araçlar

Tam x64 Flutter SDK'yı emüle etmek zorunlu değil. Frontend-server artifact'ı yukarıdaki gibi ARM64 düzeltildikten sonra Dart, Flutter tool ve test embedder'ı native kalır. Kernel yalnız Gradle'ın çalıştırdığı x64 Android host binary'lerini QEMU'ya verebilir.

Araştırmada Flutter 3.47.1'in `android-arm64-release/linux-x64.zip` içindeki `gen_snapshot` dosyası ile AGP 9.1.0 AAPT2 binary'sinin ELF bağımlılıkları ayrıca incelendi. İkisi de x86-64; `gen_snapshot` glibc bileşenlerine, AAPT2 bunlara ek olarak `libgcc_s.so.1` dosyasına bağlı. Debian'ın resmî QEMU user emulation akışı, yabancı mimari executable'ları transparan çalıştırmak için `qemu-user`, `qemu-user-binfmt`, `dpkg --add-architecture <architecture>` ve `libc6:<architecture>` kurulumunu tarif ediyor. [Debian QEMU user emulation](https://wiki.debian.org/QemuUserEmulation), [Debian Multiarch HOWTO](https://wiki.debian.org/Multiarch/HOWTO).

Bu cümle Debian'ın genel akışının tarifidir, Koala'nın Pi'sinde uygulanacak bir
adım listesi **değildir**. O paketleri bu hosta kurmak denendi ve reddedildi;
gerekçe hemen aşağıda.

Bu hibrit yol izole Debian ortamında teknik olarak mümkün olsa da gerçek Koala
Pi hostunda reddedildi. Raspberry Pi OS'nin arm64 libc paketi ile Debian amd64
paketi exact-version multiarch şartını karşılamadı; hosta foreign libc kurmak
uygulama CI'ı için kabul edilebilir bir bakım ve güvenilirlik sınırı değil.

Bu nedenle Pi üzerinde yalnız native Flutter analiz/test yolu desteklenir.
Android paketleme ya x64 bir makinede yapılmalı ya da bütün x64 kullanıcı alanını
hosttan ayıran, sabitlenmiş bir amd64 konteyner önce küçük bir kabul koşusuyla
doğrulanmalıdır. Normal PR akışı bu deneysel işi otomatik başlatmaz.

### Nöbetçi kırmızı olduğunda

`.github/actions/setup-android-x64-tools` içindeki "x64 Android araç
emülasyonunu doğrula" adımı düşerse `::error::` mesajı buraya yönlendirir. Bu
bölüm bu sorunun **tek kanonik cevabıdır**; belgenin başka yerinde alternatif
bir kurulum listesi yoktur ve olmamalıdır.

**Yapılmayacak olan:** Pi hostuna `dpkg --add-architecture amd64` ile amd64
mimarisi ve `libc6:amd64` benzeri foreign libc paketleri kurmak. Bu ölçüldü:
Raspberry Pi OS'nin vendor sürümlü arm64 libc'si ile Debian'ın amd64 adayı
exact-version multiarch şartını karşılamadı, `apt` kurulumu reddetti ve deneme
microSD yolunda `I/O error` üretti. Tekrar denenmemelidir.

**Yapılacak olan**, sırasıyla:

1. Normal PR akışındaki debug APK işi kapalıdır; yalnız `workflow_dispatch` +
   `build_android` girdisiyle çalışır. Buradaki kırmızı nöbetçi normal PR
   analiz/test zincirini engellemez; elle tetiklenen işi yeniden çalıştırma.
2. `mobile-v*` etiketi ise Play internal yayın kolunu otomatik başlatır ve aynı
   nöbetçi kırmızıysa Android yayınını bilerek durdurur. Etiketi taşımaya veya
   kapıyı atlamaya çalışma; release'i durdur ve Android paketlemeyi x64 bir
   runner'a taşı.
3. x64 runner yoksa, organizasyonun sabitlediği amd64 konteyner yolunu
   "Uygulamadan önce Pi üzerinde kanıtlanacaklar" bölümündeki kabul sırasıyla
   önce elle doğrula; yeşil kabul koşusu görülmeden Android paketleme
   desteklenmiş sayılmaz.

## Seçeneklerin karşılaştırması

| Seçenek | Sağladığı | Bedeli / riski | Karar |
|---|---|---|---|
| Native ARM64 kaynak checkout'u | Format, pub, analiz; aynı revizyondaki native frontend-server ile test | Paketlenmiş stable SDK değil; cache artifact düzeltmesi gerekiyor | **Analiz/test için seç** |
| Native Flutter + QEMU ile yalnız x64 Android araçları | Dart/test native kalırken AAPT2 ve Android `gen_snapshot` teorik olarak çalışabilir | Raspberry Pi OS multiarch libc sürümleri çakıştı; host kart yolu deneme sırasında hata verdi | **Bu Pi için reddet** |
| Hostta tüm x64 Flutter'ı QEMU/binfmt ile çalıştırmak | Mevcut x64 Flutter ve Android araçlarını büyük ölçüde değiştirmeden kullanır | Hostta x64 loader/kütüphaneleri gerekir; bütün Dart/test yükü emüle edildiği için çok yavaş; hostu kirletir | Kullanma |
| `docker run --platform linux/amd64` | x64 Flutter + Android SDK'yı izole ve tekrarlanabilir çalıştırır | QEMU derleme ve sıkıştırmada belirgin yavaştır; imajı organizasyon yönetmeli; gerçek Pi kabulü yapılmadı | **Gelecekteki Android fallback'i** |
| Job seviyesinde `container:` | Bütün `run` adımlarını konteynere alır | GitHub yalnız seçenekleri `docker create`'e aktarmayı belgeler; ARM runner + amd64 job-container + JavaScript action runtime bileşimi destek garantisi taşımıyor | İlk tercih değil |
| Flutter engine'i Pi'de yeniden derlemek | Eksik host artifact'larını teorik olarak üretme olanağı | `gclient sync`, GN ve Ninja ile ayrı engine checkout/build yaşam döngüsü; sürüm başına özel engine bakımına dönüşür | Reddet |

Docker'a göre ARM hostta amd64 konteyner emülasyonsuz çalışmaz. Linux'ta QEMU statik binary'lerini `binfmt_misc` içine kaydetmek gerekir; Docker'ın verdiği kurulum yolu `tonistiigi/binfmt` imajını privileged çalıştırmaktır. Docker ayrıca emülasyonun derleme ve sıkıştırma gibi CPU-ağır işlerde native'den çok daha yavaş olacağını açıkça belirtiyor. [Docker multi-platform build ve QEMU](https://docs.docker.com/build/building/multi-platform/#qemu).

Tam engine derleme seçeneği resmî olarak `depot_tools`, `gclient sync`, GN yapılandırması ve Ninja derlemesi isteyen ayrı bir engine-geliştirme ortamıdır. Android'in hedef engine'ı ile ARM64 host araçlarını 3.47.1'e bağlı biçimde üretmek ve Flutter'a `--local-engine` ile taşımak, uygulama CI'ını özel engine dağıtımına dönüştürür. Aynı revizyonun gerekli native Dart/test artifact'ları zaten bulunduğu ve Android için x64/QEMU sınırı daha küçük olduğu için bu yol önerilmez. [Flutter 3.47.1 engine derleme kılavuzu](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/contributing/Compiling-the-engine.md).

GitHub job container'ında `jobs.<job_id>.container.options` ek Docker create seçeneklerini kabul eder, fakat `--network` ve `--entrypoint` desteklemez. [GitHub job-container options](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/run-jobs-in-a-container#setting-container-resource-options). Burada daha sade sınır, checkout'u hostta yapmak ve yalnız Android build komutunu açık bir `docker run --platform linux/amd64` içinde çalıştırmaktır.

## Önerilen CI yerleşimi

1. **Native ARM64 hazırlık:** Flutter 3.47.1 tag'inden ayrı, kalıcı bir SDK dizini kullan. Flutter'ın Linux önkoşulları `curl`, `git`, `unzip`, `xz-utils`, `zip`, `libglu1-mesa`; test embedder'ı için gerekirse resmî Linux geliştirme paketlerini de kur. [Flutter Linux kurulum önkoşulları](https://docs.flutter.dev/install/manual#install-prerequisite-packages), [Linux toolchain paketleri](https://docs.flutter.dev/platform-integration/linux/setup#set-up-tooling).
2. **Analyze job:** native SDK ile `dart format`, `flutter pub get`, `flutter analyze --fatal-infos`.
3. **Test job:** SDK hazırlanırken yukarıdaki aynı-revizyon frontend-server düzeltmesini bir kez yap; ardından standart test komutunu çalıştır. Önce dar test, sonra tam suite.
4. **Android job:** normal PR ve `main` koşularında kapalı tut. x64 bir runner sağlandığında orada çalıştır; Pi seçeneği gerekiyorsa organizasyonun sabitlediği amd64 CI imajını explicit `docker run --platform linux/amd64` ile önce elle doğrula. İmaj Flutter 3.47.1 x64, JDK 17 ve Koala'nın Android SDK/AGP gereksinimlerini içermeli. Çalışma alanı bind mount edilmeli; çıktıların root sahibi kalmaması için host UID/GID ile çalıştırılmalı.
5. **Kapasite:** aynı anda yalnız bir Pi runner'ı çalıştır. Üç ağır mobil jobu dört çekirdekte paralel çalıştırmak süreyi ve flake olasılığını artırdı.
6. **Cache:** Self-hosted runner diski kalıcı olduğu için Flutter SDK ve pub/Gradle cache'lerini runner-local tut. Her koşuda büyük SDK cache'ini GitHub'a yüklemek gereksiz ağ ve microSD I/O'su yaratır. Üç runner aynı mutable SDK dizinine eşzamanlı yazmamalı; runner başına SDK/cache veya immutable CI imajı kullanılmalı.

Android imajı için üçüncü taraf, sahibi belirsiz bir Flutter Docker imajı seçilmemeli. Flutter resmî bir CI Docker imajı yayımlamadığından, taban imaj + resmî Flutter x64 arşivi + resmî Android araçlarıyla Koala'nın kendi sabitlenmiş imajı oluşturulmalı.

## Docker Buildx, backend image'ları için ayrı konu

ARM64 Pi üzerinde amd64 Docker image üretmek için Docker'ın resmî GitHub Actions akışı `docker/setup-qemu-action`, `docker/setup-buildx-action` ve `docker/build-push-action` içinde `platforms: linux/amd64` kullanımını destekliyor. [Docker'ın GitHub Actions multi-platform örneği](https://docs.docker.com/build/ci/github-actions/multi-platform/). Bu, backend image'ının deploy hedefi amd64 ise doğru çözümdür; `flutter test` shell komutunu amd64'e çevirmek için tek başına yeterli değildir.

Buildx'in `docker-container` driver'ı çıktıyı yerel classic image store'a otomatik yüklemez; registry'ye doğrudan `push` etmek en sade yoldur. Multi-platform image'ı yerelde `load` etmek için containerd image store gerekir. [Docker builder/output sınırı](https://docs.docker.com/build/building/multi-platform/#custom-builder), [GitHub Actions load sınırı](https://docs.docker.com/build/ci/github-actions/multi-platform/#build-and-load-multi-platform-images).

## Uygulamadan önce Pi üzerinde kanıtlanacaklar

Workflow değişikliğinden önce tek runner'da şu küçük kabul sırası kullanılmalı:

```bash
uname -m
flutter --version
file "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart"
file "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/flutter_tester"

dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos

file "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot"
file "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/frontend_server_aot.dart.snapshot"

cp \
  "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot" \
  "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/frontend_server_aot.dart.snapshot"

file "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/frontend_server_aot.dart.snapshot"
flutter test test/product/network/api_config_test.dart --reporter expanded
```

Beklenti: Dart, `flutter_tester`, kaynak frontend-server ve kopyalama sonrasındaki hedef frontend-server `file` çıktılarının tümü ARM aarch64; dar test yeşil. Kopyalama öncesindeki hedef frontend-server'ın x86-64 çıkması doğrulanan upstream hatadır. Ardından flavor/define parametreleriyle tam suite çalıştırılır.

Android/QEMU kabulü hosta amd64 libc kurarak yapılmamalı. İleride izole amd64
konteyner hazırlanırsa Flutter'ın indirdiği x64 `gen_snapshot` ve Gradle
cache'indeki AAPT2 üzerinde `file` çalıştırılmalı; ardından executable'ların
`--help`/`version` komutları exit `0` vermeli. Son olarak gerçek build'ler:

```bash
flutter build apk --debug \
  --flavor staging \
  --dart-define-from-file=config/staging.json

flutter build appbundle --release \
  --flavor staging \
  --dart-define-from-file=config/staging.json
```

Staging release AAB, x64 Android AOT araç yolunu production signing secret'ları olmadan kanıtlar. Gerçek production AAB ayrıca yalnız gerekli signing ve Maps secret'ları güvenli biçimde sağlanarak denenmeli; secret değerleri loga yazdırılmamalı. amd64 konteyner emülasyonu önce şu küçük kontrolle doğrulanır:

```bash
docker run --rm --platform linux/amd64 debian:bookworm-slim uname -m
```

Beklenti `x86_64`. Sonra sabit Koala Android CI imajında `flutter --version`, debug APK ve release AAB sırayla denenir. Native analiz ve native tam test gerçek Pi'de doğrulandı; Android paketleme ise ayrıca yeşil bir kabul koşusu görülmeden destekleniyor sayılmamalı.

## Güven sınırı

- **Yüksek güven:** mevcut action hatasının manifest/mimari nedeni; Flutter 3.47.1 ARM64 Dart, `flutter_tester` ve genel engine artifact'larının varlığı; Android Linux ARM hostunun desteklenmemesi; amd64 AAPT2 ve Android AOT host araçlarının mimarisi.
- **Yüksek güven, gerçek Pi ile doğrulandı:** 3.47.1 native test suite'inin aynı-revizyon ARM64 frontend-server artifact düzeltmesiyle bütün Koala testlerinde geçmesi.
- **Deney gerekli:** Pi 5'te izole amd64 konteyner altındaki debug APK/AAB başarısı, süreleri, bellek kullanımı ve mevcut Android plugin setinin ek x64 native araç isteyip istememesi.
