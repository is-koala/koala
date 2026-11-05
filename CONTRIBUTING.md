# Contributing Guide

Bu projeye katkıda bulunmadan önce lütfen aşağıdaki kuralları dikkatlice oku.

Projenin ne olduğu, mimarisi ve bilinen tuzakları için `AGENTS.md`'ye bak; bu dosya yalnızca **kod yazma kurallarını** anlatır ve bağlayıcıdır.

---

## Klasör Yapısı

Koala tek kod tabanında **iki uygulama** barındırır: `employee/` (iş arayan) ve `business/` (işveren). Her ikisinin ortak kullandığı her şey `product/` altında yaşar.

```
lib/
├── main.dart
├── product/                      # iki uygulamanın da ortak kullandığı katman
│   ├── app.dart
│   ├── constants/
│   │   ├── app_assets.dart
│   │   ├── app_colors.dart
│   │   ├── app_padding.dart
│   │   ├── app_radius.dart
│   │   └── app_sizes.dart
│   ├── extensions/               # context_extensions, num_extensions
│   ├── router/
│   ├── theme/
│   └── widgets/                  # MyButton, MyTextfield, MyAppbar, MyListTile,
│                                 # AppBottomSheet, ThemeModeSheet ...
├── employee/
│   ├── core/                     # yalnızca employee tarafının ortak kodu
│   └── features/
│       └── home/
│           ├── models/           # veri sınıfları
│           │   └── job.dart
│           ├── services/         # verinin geldiği yer
│           │   └── job_service.dart
│           └── presentation/
│               ├── pages/
│               │   ├── explore_page.dart
│               │   └── explore_pagemodel.dart
│               ├── widgets/
│               │   └── job_card.dart
│               └── providers/
└── business/
    ├── core/                     # yalnızca business tarafının ortak kodu
    └── features/
```

Her yeni özellik ilgili uygulamanın `features/` klasörü altına kendi adıyla klasör açılarak eklenir. Klasör yapısı yukarıdaki şemaya uygun olmalıdır.

Bir feature en fazla **üç** üst klasör taşır:

| Klasör | İçerik |
|---|---|
| `models/` | Düz veri sınıfları. `fromJson` / `toJson` burada. |
| `services/` | Gerçek API çağrılarını `ApiClient` üzerinden yapan servis sınıfları. |
| `presentation/` | `pages/`, `widgets/`, `providers/` |

`data/` ya da `domain/` diye bir ara katman **yok**; model doğrudan `models/` altında durur. Her feature yalnız ihtiyaç duyduğu klasörleri taşır; mevcut klasörleri kaynak ağacından doğrula.

Servis sınıfı dosyasının adını alır: `job_service.dart` → `JobService`. `*Repository` adlandırması kullanılmıyor.

**Ortak kod nereye gider?**

| Nerede kullanılıyor | Nereye konur |
|---|---|
| Hem employee hem business | `product/` |
| Tek tarafın birden fazla feature'ı | O tarafın `core/` klasörü |
| Tek bir feature | O feature'ın kendi klasörü |

Employee'ye özgü bir widget'ı `product/` altına koyma; `product/` iki uygulamanın da sözleşmesidir.

İki uygulamanın da açtığı, kendi modeli/servisi/sayfaları olan bir **özellik** `product/features/<özellik_adı>/` altına, taraf feature'larıyla aynı üç klasörlü şemayla konur (`models/`, `services/`, `presentation/`). İlk örnek `product/features/account/` (hesap bilgileri, adres, parola, oturumlar, bildirim tercihleri, engellenenler, hesap silme): iki ayarlar menüsü de aynı rotalara gider, `b_` önekli kopyası yoktur.

**Business tarafı `b_` önekini kullanır:** `b_home_page.dart` → `BHomePage`, `BJobsProvider`, `BNavItem`. Bu önek iki tarafın aynı isimli dosyalarını ayırt etmek için var; koru.

---

## Model İsimlendirme

`models/` klasörü altındaki veri modelleri için dosya ve sınıf isimlerinde `_model` / `Model` takısı **kullanılmaz**; doğrudan nesnenin kendi adı verilir:

- Dosya: `user.dart` → Sınıf: `User`
- Dosya: `job.dart` → Sınıf: `Job`
- Dosya: `my_job.dart` → Sınıf: `MyJob`
- Dosya: `b_job_post.dart` → Sınıf: `BJobPost`

Kod tabanının tamamı bu kurala uyuyor; `JobModel` gibi bir isim diff'te görünüyorsa gerileme demektir.

> Model adı Flutter'ın bir widget'ıyla çakışmamalı. Şirket görselinin modeli bu yüzden `Image` değil `CompanyImage`; `Image` olsaydı onu import eden ilk widget derlenmezdi.

---

## Page & PageModel Ayrımı (`part` / `part of`)

**Bu ayrım her sayfa için zorunlu değildir.** Sayfa büyüdükçe — özellikle `StatefulWidget` sayfalarda fonksiyon sayısı arttıkça — UI tarafı kalabalıklaşır ve okunması zorlaşır. Böyle durumlarda sayfa ikiye bölünür:

- `home_page.dart` → Sadece `build` ve UI extract method'ları.
- `home_pagemodel.dart` → `initState`, `dispose`, state alanları ve iş mantığı.

Sayfa küçükse ve neredeyse hiç mantık içermiyorsa (basit bir `StatelessWidget`, tek `build`'lik bir sayfa) tek dosyada bırakılır. Kural okunabilirlik içindir; dosya sayısını artırmak için değil.

**Ne zaman ayır:**

- Sayfada birden fazla event handler / iş mantığı fonksiyonu birikmişse
- `initState` / `dispose` ve controller yönetimi varsa
- `build` dışındaki mantık, UI kodunu okumayı zorlaştırıyorsa

Projedeki örnek: `employee/features/home/presentation/pages/explore_pages/list_explore_page.dart` ve onun `list_explore_pagemodel.dart` eşi.

**`home_page.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';

part 'home_pagemodel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends HomePagemodel {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppPadding.primaryAll,
      children: [
        _sectionHeader('Yakınındaki İşler'),
        const JobCard(),
      ],
    );
  }

  Widget _sectionHeader(String title) => Text(title);
}
```

**`home_pagemodel.dart`**
```dart
part of 'home_page.dart';

abstract class HomePagemodel extends State<HomePage> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}
```

> ⚠️ PageModel sınıfı mutlaka `abstract` olmalıdır.

**İsimlendirme:** Dosya `<sayfa_adı>_pagemodel.dart`, sınıf `<SayfaAdı>Pagemodel` şeklinde yazılır.

---

## Widget Extraction

Birden fazla yerde kullanılan ya da karmaşık hale gelen widget'lar `widgets/` klasörüne ayrı bir dosya olarak çıkarılır.

```dart
// employee/features/home/presentation/widgets/job_thumbnail.dart

import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class JobThumbnail extends StatelessWidget {
  const JobThumbnail({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tileColor, // temaya göre değişen renk
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Text(title),
    );
  }
}
```

Yalnızca tek bir feature'da kullanılan widget o feature'ın `presentation/widgets/` klasörüne; o tarafın birden fazla feature'ında kullanılanlar `<taraf>/core/widgets/` altına; iki uygulamanın da kullandıkları `product/widgets/` altına konur.

---

## Extract Method Kullanımı

Aynı sayfa içinde tekrar eden ya da uzun UI blokları `build` metodundan ayrılarak private method olarak tanımlanır.

```dart
// ✅ Doğru
Widget _sectionHeader(String title) => Text(title);
PreferredSizeWidget _appBar() => const MyAppbar(title: 'Profil');

// ❌ Yanlış — her şeyi build içine yazmak
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Profil')),
    body: Column(
      children: [
        // onlarca satır iç içe widget
      ],
    ),
  );
}
```

---

## Renk Kullanımı

Uygulama açık ve koyu temayı birlikte destekliyor. Bu yüzden renkler **iki kaynağa** ayrılır; hangisini kullanacağını seçmek zorundasın.

### 1. Temaya göre değişenler → `context`

Zemin, metin ve ayraç renkleri temaya göre farklılaşır. Bunlar `ColorScheme`'den gelir ve `product/extensions/context_extensions.dart` üzerinden okunur:

| Erişimci | Nerede kullanılır |
|---|---|
| `context.backgroundColor` | Sayfa zemini |
| `context.tileColor` | Kart, tile ve sheet zemini |
| `context.elevatedColor` | Buton, ikon dairesi, navbar gibi yükseltilmiş yüzeyler |
| `context.textPrimary` | Başlık ve gövde metni |
| `context.textSecondary` | Açıklama, etiket, ikincil metin |
| `context.textTertiary` | En soluk metin ve ikonlar |
| `context.dividerColor` | Ayraç ve ince kenarlıklar |
| `context.accentColor` | Vurgu rengi (marka yeşili) |
| `context.onAccentColor` | Vurgu zemini üzerindeki metin ve ikon |

> **Zemin ve kart kuralı bütün uygulamada aynı:** sayfa `context.backgroundColor`, üstündeki kart ve satır `context.tileColor`. Eskiden keşfet listesi için tersini yapan bir ikili vardı (`recessedColor` / `raisedColor`: açık temada gri sayfa + beyaz kart); ekranlar arasında renkler yer değiştirdiği için kaldırıldı, geri getirme. `context.isDarkTheme` yalnız iki temanın gerçekten ters yönde davrandığı yerlerde kullanılır — `ColorScheme`'in zaten çözdüğü bir renk için değil.

### 2. Temadan bağımsız olanlar → `AppColors`

Marka rengi (`primaryColor`), durum renkleri (`red`, `green`, `orange` ...) ve doygun renkli zemin üstündeki içerik (`onAccent`) `AppColors`'ta kalır.

> ⚠️ `AppColors` içindeki `dark*` / `light*` sabitleri yalnızca `theme.dart`'taki `ColorScheme`'leri besler — widget'larda **doğrudan kullanılmaz**.

```dart
// ❌ Yanlış — iki temadan birinde sessizce kırılır
color: Colors.black
color: Colors.white
color: Colors.grey[600]
color: AppColors.darkTextPrimary

// ✅ Doğru
color: context.backgroundColor
color: context.textPrimary
color: AppColors.primaryColor   // marka rengi: temadan bağımsız
```

`context`'ten gelen renk derleme zamanı sabiti olmadığı için o widget `const` olamaz; `const` anahtarını kaldır.

> ⚠️ **Renkli zemin üstündeki metin.** `textTheme` slotlarının hepsi bir renk taşıyor. Yeşil buton, renkli rozet gibi doygun bir zeminin üstünde rengi açıkça geçmezsen metin koyu kalır:
>
> ```dart
> // ❌ titleSmall'ın kendi rengi (koyu) yeşil zeminde kalır
> style: context.textTheme.titleSmall
>
> // ✅
> style: context.textTheme.titleSmall?.copyWith(color: context.onAccentColor)
>
> // ✅ butonlarda: rengi butonun kendisi uygulasın, pasif hâl de doğru olsun
> style: ElevatedButton.styleFrom(
>   foregroundColor: context.onAccentColor,
>   textStyle: context.textTheme.titleSmall,
> ),
> ```
>
> `copyWith(color: null)` rengi **temizlemez**; `null` "değiştirme" demektir.

---

## Tipografi

`fontFamily: 'Poppins'` **tek bir yerde**, `theme.dart` içinde tanımlıdır ve bütün metin ölçeklerine uygulanır. `TextStyle` içinde tekrar yazma.

```dart
// ❌ Yanlış
style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)

// ✅ Doğru
style: context.textTheme.titleMedium
style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
```

Ölçek karşılıkları `theme.dart` içindeki `_textTheme` tablosunda; boyutlar Material 3'ün
varsayılanları değil, uygulamada fiilen kullanılan değerler:

| Slot | Boyut | | Slot | Boyut |
|---|---|---|---|---|
| `displayLarge` | 64 | | `titleSmall` / `bodyLarge` | 16 |
| `displayMedium` | 40 | | `bodyMedium` / `labelLarge` | 14 |
| `displaySmall` | 30 | | `bodySmall` | 13 |
| `headlineLarge` | 28 | | `labelMedium` | 12 |
| `headlineMedium` | 24 | | `labelSmall` | 11 |
| `headlineSmall` | 22 | | | |
| `titleLarge` | 20 | | | |
| `titleMedium` | 18 | | | |

Slotların varsayılan rengi ve kalınlığı da tanımlı; yalnızca farklı olanı `copyWith` ile geç.

---

## Padding, Radius, Boyut ve Asset

Bu değerler de **kesinlikle** hard-code yazılmaz; `product/constants/` altındaki ilgili dosya kullanılır.

```dart
// ❌ Yanlış
padding: EdgeInsets.all(16)
borderRadius: BorderRadius.circular(20)
size: 24
'assets/images/koala_logo.png'

// ✅ Doğru
padding: AppPadding.primaryAll
borderRadius: AppRadius.secondaryCircular
size: AppSizes.icon
AppAssets.koalaLogo
```

| Dosya | Sınıf | İçerik |
|---|---|---|
| `app_colors.dart` | `AppColors` | Temadan bağımsız marka ve durum renkleri |
| `app_padding.dart` | `AppPadding` | `EdgeInsets` padding değerleri |
| `app_radius.dart` | `AppRadius` | Border radius değerleri (`double` ve `BorderRadius`) |
| `app_sizes.dart` | `AppSizes` | İkon boyutları ve boşluk (space) değerleri |
| `app_assets.dart` | `AppAssets` | Asset dosya yolları (png, svg, json) |

İhtiyaç duyduğun değer sabit dosyasında yoksa, hard-code yazmak yerine ilgili dosyaya anlamlı bir isimle yeni sabit ekle ve **neden** o değer olduğunu `///` ile yaz.

Yalnızca o widget'a özgü, paylaşılmayan ölçüler (bir sayfanın kapak yüksekliği, bir animasyonun uç değerleri) sabit dosyasına değil, widget'ın içinde `static const` olarak tanımlanır — yine `///` yorumuyla.

> ⚠️ `context.size` **ekran boyutu değildir.** `BuildContext`'in kendi `size` alanı (nullable, `RenderBox`'tan gelir) uzantıyı gölgeliyor. Ekran boyutu için `MediaQuery.sizeOf(context)` kullan; `context.width` ve `context.height` uzantıları sorunsuz çalışıyor.

---

## İkonlar

UI ikonları `AppIcons` kataloğundan seçilir ve `AppIcon` ile çizilir:

```dart
AppIcon(AppIcons.arrowLeft, color: context.textPrimary)
```

Eski dosyalarda hâlâ Material `Icons.*` var; yenisini ekleme. Harita pinleri dosyadan değil koddan kurulur: kategori renginde damla + `JobCategoryStyle.icon`'un Filled Reicon karşılığı, `flutter_svg` ile çizilir (`job_marker_generator.dart`). Kategori ikonu seçerken Filled karşılığı olduğundan emin ol.

---

## Veri Katmanı

Çalışma zamanı verisinin tamamı feature'ların `services/` sınıfları üzerinden gerçek backend'den gelir. Servisler `lib/product/network/` altındaki `ApiClient`'ı kullanır ve hata olarak yalnızca `ApiException` yükseltir; sayfalar `dio`'yu doğrudan görmez. Fake istemciler yalnız `test/support/` altında, birim ve widget testlerinde kullanılabilir. Yeni veri eklerken:

- Sayfanın içine liste gömme; ilgili repository/service sınıfına koy.
- Sayfa her zaman `Future` döndüren bir servis metodu üzerinden okusun; liste veya örnek yanıt gömme.
- Model sınıflarına backend sözleşmesiyle uyumlu `fromJson` yaz.

---

## Özet Kontrol Listesi

PR açmadan önce aşağıdaki maddeleri kontrol et:

- [ ] Klasör yapısı kurala uygun (`<taraf>/features/özellik_adı/` altında `models` / `services` / `presentation`)
- [ ] Model sınıf ve dosya adlarında `Model` takısı yok
- [ ] Ortak kod doğru katmanda (`product/` yalnızca iki uygulamanın da kullandıkları için)
- [ ] Business dosyaları `b_` önekini taşıyor
- [ ] Sayfa kalabalıklaştıysa Page ve PageModel `part`/`part of` ile ayrılmış
- [ ] Tekrar eden widget'lar `widgets/` klasörüne extract edilmiş
- [ ] Uzun UI blokları extract method olarak ayrılmış
- [ ] Zemin/metin/ayraç renkleri `context` erişimcilerinden alınmış; `AppColors` yalnızca marka ve durum renkleri için kullanılmış
- [ ] `TextStyle` içinde `fontFamily` tekrarı yok; ölçek `context.textTheme`'den geliyor
- [ ] Hard-coded padding, radius, boyut ve asset yolu yok; `product/constants` kullanılıyor
- [ ] Renkli zemin üstündeki metinlerin rengi açıkça verilmiş
- [ ] Bottom sheet varsa `AppBottomSheet` üzerinden açılıyor
- [ ] `flutter analyze --no-pub` temiz (CI `--fatal-infos` ile çalışıyor)
- [ ] Değişiklik hem açık hem koyu temada kontrol edilmiş
