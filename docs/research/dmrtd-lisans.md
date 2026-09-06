# dmrtd ve LGPL-3.0: kapalı kaynak bir Flutter uygulamasında kullanılabilir mi?

Tarih: 6 Eylül 2026. Kapsam: `ZeroPass/dmrtd` kütüphanesinin, App Store ve Google Play'de yayımlanacak kapalı kaynak bir Flutter uygulamasında (Koala) kullanılmasının lisans tarafı. Bağlam: [KIMLIK_DOGRULAMA_RAPORU.md](../../KIMLIK_DOGRULAMA_RAPORU.md) — KPS kapandıktan sonra çip okuma doğrulamanın kendisi hâline geldi, yani bu kütüphane seçimi artık isteğe bağlı bir iyileştirme değil.

**Bu bir hukuk görüşü değildir.** Bu belgeyi yazan hukuk danışmanı değil. Amaç karar vermek değil, kararı verecek kişinin önüne seçenekleri kaynaklarıyla koymak. Lisans metinleri, Apple ve Google'ın kendi yayımladığı sözleşmeler, Dart/Flutter'ın kendi belgeleri ve dmrtd deposunun kendi dosyaları birincil kaynak olarak okundu. İkincil olan her şey ayrıca işaretlendi. Tüm bağlantılara **6 Eylül 2026**'da erişildi; belge sürümleri §5'teki kaynak listesinde.

---

## 1. Kısa cevap

**Evet, kullanılabilir — ve Koala'nın kendi kaynak kodunu açması gerekmiyor.** LGPL-3.0 §4, kütüphaneyle birleştirilmiş yapıtın "seçeceğiniz koşullarla" dağıtılmasına açıkça izin veriyor; tek şartı, bu koşulların *kütüphane kısmının değiştirilmesini* ve *bu değişikliklerin hata ayıklanması için tersine mühendisliği* engellememesi. Mağaza tarafı da beklenenden temiz çıktı. 2010'da VLC'yi App Store'dan düşüren çatışma, GPL'in "alıcıya başka kısıtlama koyamazsın" kuralıyla Apple'ın dağıtım kurallarının çarpışmasıydı; **LGPL §4 yeniden dağıtım özgürlüğü istemediği için o çatışma burada doğmuyor.** Apple'ın bugünkü standart EULA'sı üstelik değiştirme ve tersine mühendislik yasağına açık kaynak bileşenler için lafzen muafiyet tanıyor, Google Play tarafında ise açık kaynakla ilgili hiçbir yükümlülük yok.

**Ama tek bir madde var ve asıl risk orada: §4(d).** Bu madde iki yoldan birini seçtiriyor ve **§4(d)(1) (paylaşımlı kütüphane) mobil uygulama için zaten baştan elenmiş durumda** — madde, kütüphanenin "kullanıcının sisteminde hâlihazırda bulunan" bir kopyasını istiyor; uygulamayla birlikte gönderilen bir paket bunu hiçbir dilde karşılamaz. Geriye §4(d)(0) kalıyor: Koala'nın kendi kodunu, kullanıcının dmrtd'yi değiştirip **yeniden bağlayabileceği** bir biçimde vermek. Kaynak değil, "nesne kodu" yeterli — FSF bunu kendi SSS'inde açıkça söylüyor. Sorun şu ki **Dart AOT'de yeniden bağlanabilir bir dikiş yeri yok**: derleyici uygulamayı ve tüm paketleri tek bir bütün-program anlık görüntüsüne kaynaştırıyor, ağaç sarsma ve paketler arası iyileştirme uyguluyor. Üretilen nesne dosyası var ama yanlış granülerlikte — içinde dmrtd zaten kaynaşmış durumda, dolayısıyla "değiştirilmiş dmrtd ile yeniden bağla" işlemine elvermiyor. **Bu belirsizlik teknik, hukuki değil, ve tek başına çözülemedi.** Karar verilecekse en düşük riskli yol ZeroPass'ten ticari lisans almak: çift lisans modelini tam bunun için kurmuşlar ve bu yol §4(d) sorusunu bütünüyle ortadan kaldırıyor. Fiyat hiçbir yerde yayımlanmamış, sormak gerekiyor (`zeropass@pm.me`).

---

## 2. Seçenekler ve bedelleri

| Seçenek | Ne gerektirir | Ne kadar risk kalır |
| --- | --- | --- |
| **A. LGPL'e uyarak devam** | Bildirim + iki lisans metni + §4(d)(0) yeniden bağlama malzemesi | §4(d)(0)'ın Dart'ta karşılığı yok; kalan risk burada yoğunlaşıyor |
| **B. Ticari lisans al** | ZeroPass ile yazışma, bilinmeyen ücret, sözleşmedeki boşlukların kapatılması | Lisans riski büyük ölçüde biter; sözleşme metninin kendisi ham |
| **C. Başka kütüphaneye geç** | Yeniden değerlendirme + entegrasyon işi + ticari SDK ücreti | Lisans riski biter, maliyet ve takvim riski başlar |

### A. LGPL yükümlülüğünü karşılayarak devam etmek

§4'ün alt bentleriyle birebir, yapılması gerekenler:

- **§4(a) — Bildirim.** Uygulama içinde, dmrtd'nin kullanıldığını ve LGPL kapsamında olduğunu açıkça söyleyen bir yer. Flutter'da hazır karşılığı var (§3.4), **ama olduğu gibi çalışmaz** — nedeni aşağıda, ve bu ucuz ama sessizce atlanabilecek bir adım.
- **§4(b) — Lisans metinleri.** GPL-3.0 *ve* LGPL-3.0 metinlerinin **ikisinin birden** uygulamayla verilmesi. LGPL tek başına yetmiyor, ve GPL metni dmrtd paketinin içinde yok — elle eklenmesi gerekiyor.
- **§4(c) — Çalışma anındaki telif bildirimleri.** Uygulama çalışırken telif bildirimi gösteriyorsa dmrtd'ninki de aralarında olmalı.
- **§4(d)(0) — Yeniden bağlama malzemesi.** dmrtd'nin kaynağı (zaten açık) + Koala'nın kendi kodu, kullanıcının dmrtd'yi değiştirip yeniden bağlayabileceği biçimde. **Teslim yöntemi kolay:** GPL §6(b)/(d) uyarınca üç yıl geçerli yazılı bir teklif ya da bir ağ sunucusundan erişim yeterli — yani bir URL'de barındırmak yeter, uygulamanın içine koymak gerekmiyor. **Zor olan malzemenin kendisini üretebilmek** (§3.2).
- **§4(e) — Kurulum Bilgisi.** *Muhtemelen gerekmiyor,* bkz. §3.1 sonu.

Ayrıca §4'ün giriş cümlesi gereği Koala'nın kullanım koşulları, dmrtd kısmının değiştirilmesini ve hata ayıklama amaçlı tersine mühendisliği yasaklamamalı. Koala kendi EULA'sını yazacaksa bu istisnanın metne konması gerekiyor — Apple zaten kendi standart EULA'sında aynı istisnayı koymuş durumda, ama biz kendi EULA'mızı verirsek o koruma otomatik gelmiyor.

**Bedeli:** ilk üç madde ucuz ve mekanik. Dördüncüsü belirsiz — ve belirsizliği taşıyan taraf biz oluruz.

### B. Ticari lisans almak

dmrtd çift lisanslı. Ticari yol §4(d) sorusunu tamamen ortadan kaldırır. Gerekenler: `zeropass@pm.me` adresine yazmak, fiyat teklifi almak, ve sözleşme metnindeki eksikleri kapattırmak — mevcut `LICENSE.COMMERCIAL` bir şablon ve doldurulmamış yer tutucu içeriyor (§3.5). Ek olarak sözleşmenin 3. maddesindeki "yazılımı hiçbir biçimde yeniden dağıtmama" yasağının uygulamaya gömülü dağıtımı kapsayıp kapsamadığı yazılı olarak netleştirilmeli; lafzen okunduğunda ticari lisans uygulamada kullanımı engelliyor gibi duruyor, ki niyetin bu olmadığı açık.

**Bedeli:** bilinmeyen bir ücret + yazışma süresi. Karşılığında tek gerçek belirsizlik kalkıyor. **Bu belgedeki bulgulara göre en makul yol bu.**

### C. Başka kütüphaneye geçmek

[KIMLIK_DOGRULAMA_RAPORU.md](../../KIMLIK_DOGRULAMA_RAPORU.md) §4'te alternatifler zaten listelenmişti (Regula, Innovatrics DOT, Microblink, NFCREAD) ve hepsi ticari. O rapordaki DG2/JPEG2000 tespiti — çipteki fotoğrafın standart Dart kütüphaneleriyle çözülemiyor olması — zaten ticari bir SDK'ya doğru itiyordu. Yani bu seçenek yalnızca lisans gerekçesiyle değil, işlevsel gerekçeyle de masada. Ayrıca dmrtd'nin son commit'i **12 Haziran 2025** (bugün itibarıyla ~15 ay durgun) ve paket pub.dev'de yok; bakım riski lisanstan bağımsız olarak zaten vardı.

**Bedeli:** entegrasyonun baştan yapılması + lisans ücreti.

---

## 3. Ayrıntı

### 3.1 LGPL-3.0 metni ne diyor?

Kaynak: [gnu.org/licenses/lgpl-3.0.txt](https://www.gnu.org/licenses/lgpl-3.0.txt).

**Tanımlar (§0).** "Application", kütüphanenin sunduğu bir arayüzü kullanan ama başka türlü kütüphaneye dayanmayan yapıt. "Combined Work", Application ile Library'nin birleştirilmesi ya da bağlanmasıyla üretilen yapıt. Koala + dmrtd = Combined Work. İki tanım §4 için belirleyici:

> The "Minimal Corresponding Source" for a Combined Work means the Corresponding Source for the Combined Work, excluding any source code for portions of the Combined Work that, considered in isolation, are based on the Application, and not on the Linked Version.

> The "Corresponding Application Code" for a Combined Work means the object code and/or source code for the Application, including any data and utility programs needed for reproducing the Combined Work from the Application, but excluding the System Libraries of the Combined Work.

Yani "Minimal Corresponding Source" pratikte dmrtd'nin kaynağı; "Corresponding Application Code" ise Koala'nın kendi kodu — ve tanım **"object code and/or source code"** diyor, kaynak zorunlu değil. Ayrıca "including any data and utility programs needed for reproducing the Combined Work" ifadesine dikkat: yalnız kod değil, **birleşik yapıtı yeniden üretmek için gereken araçlar da** kapsamda.

**§4'ün giriş cümlesi.** Kapalı kaynağa izin veren yer burası:

> You may convey a Combined Work under terms of your choice that, taken together, effectively do not restrict modification of the portions of the Library contained in the Combined Work and reverse engineering for debugging such modifications, if you also do each of the following:

Yasaklanan iki şey var: kütüphane kısmının değiştirilmesini kısıtlamak, ve bu değişikliklerin hata ayıklanması için tersine mühendisliği kısıtlamak. **Yeniden dağıtımı kısıtlamak yasak değil.** GPL'den ayrıldığı ve mağaza çatışmasını çözen nokta tam olarak bu (§3.3).

**§4(d) — iki yol.**

> 0) Convey the Minimal Corresponding Source under the terms of this License, and the Corresponding Application Code in a form suitable for, and under terms that permit, the user to recombine or relink the Application with a modified version of the Linked Version to produce a modified Combined Work, in the manner specified by section 6 of the GNU GPL for conveying Corresponding Source.

> 1) Use a suitable shared library mechanism for linking with the Library. A suitable mechanism is one that (a) uses at run time a copy of the Library already present on the user's computer system, and (b) will operate properly with a modified version of the Library that is interface-compatible with the Linked Version.

**§4(d)(1), Dart tartışmasına girmeden düşüyor.** (a) bendi kütüphanenin kullanıcının sisteminde **hâlihazırda bulunan** bir kopyasının çalışma anında kullanılmasını istiyor. Uygulamayla birlikte gönderilen bir paket bu tarifi karşılamaz — Dart'ın mükemmel dinamik bağlaması olsa bile karşılamazdı. Yani **tek yol §4(d)(0)**.

**"Yeniden bağlama hakkı" tam olarak ne istiyor?** FSF'nin kendi SSS'i net — [gnu.org/licenses/gpl-faq.html#LGPLStaticVsDynamic](https://www.gnu.org/licenses/gpl-faq.html#LGPLStaticVsDynamic):

> (1) If you statically link against an LGPLed library, you must also provide your application in an object (not necessarily source) format, so that a user has the opportunity to modify the library and relink the application.

Yani: **nesne dosyası, kaynak değil.** Statik bağlama LGPL'i ihlal etmiyor; yalnızca yeniden bağlanabilir bir biçim sağlama borcu doğuruyor. Sorunun cevabı budur.

FSF'nin, geleneksel bağlama modeli olmayan diller için de aynı görüşte olduğunu gösteren ikinci birincil kaynak: [gnu.org/licenses/lgpl-java.html](https://www.gnu.org/licenses/lgpl-java.html) (David Turner, FSF; 2004'te LGPLv2.1 için yazılmış, sayfanın kendi notu "ana noktalar LGPLv3 için de geçerli, ama madde numaraları gibi ayrıntılar değişti" diyor):

> FSF's position has remained constant throughout: the LGPL works as intended with all known programming languages, including Java. Applications which link to LGPL libraries need not be released under the LGPL.

> This doesn't mean you need to provide source code or any details about the internals of your application.

**İki uyarı.** Birincisi: FSF LGPL'in yazarı ama **dmrtd'nin telif hakkı sahibi değil.** Bu metinleri yorumlama ve ihlal iddiasında bulunma yetkisi ZeroPass'te; FSF'nin SSS'i güçlü bir yorum kaynağı, bağlayıcı bir taahhüt değil. İkincisi: Java analojisi kusurlu. Java'da her kütüphane ayrı bir JAR olarak durur, yani değiştirilip yerine konabilecek fiziksel bir birim vardır. Dart AOT'de böyle bir birim yok (§3.2). FSF'nin "bütün dillerde çalışır" iddiası, Dart'ın somut durumu için ayrıca sınanmış değil.

**§5 (Combined Libraries)** bizim durumumuzu ilgilendirmiyor: LGPL'li kütüphane kodunu başka kütüphane işlevleriyle *tek bir kütüphane içinde* yan yana koyup dağıtmayı düzenliyor; Koala kütüphane değil uygulama dağıtıyor. Not: §5(a) böyle bir durumda LGPL'li kısmın *birleştirilmemiş* hâlinin ayrıca sunulmasını istiyor. dmrtd'yi ileride başka şeylerle harmanlanmış tek bir bileşene gömersek §5 devreye girer.

**§4(e) ve GPL §6 — büyük ihtimalle tetiklenmiyor.** §4(e) Kurulum Bilgisi'ni "yalnızca GPL §6 uyarınca zaten sağlamak zorunda olsaydınız" koşuluna bağlıyor. GPL §6'nın ([gnu.org/licenses/gpl-3.0.txt](https://www.gnu.org/licenses/gpl-3.0.txt)) ilgili cümlesi:

> If you convey an object code work under this section in, or with, or specifically for use in, a User Product, and the conveying occurs as part of a transaction in which the right of possession and use of the User Product is transferred to the recipient in perpetuity or for a fixed term (regardless of how the transaction is characterized), the Corresponding Source conveyed under this section must be accompanied by the Installation Information.

Koşul, Kullanıcı Ürünü'nün (telefonun) **zilyetliğinin devredildiği bir işleme** bağlı. Koala uygulama dağıtıyor, telefon devretmiyor. Bu okumaya göre §4(e) tetiklenmiyor — ve iOS kod imzalama yüzünden endişe edilen "kullanıcı yeniden bağladığı ikiliyi cihazına kuramaz" sorunu LGPL açısından konu dışı kalıyor. *Bu bir yorum, hukukçu onayı gerekir;* ve Apple sözleşmesindeki §5.1 taahhüdü açısından da önemli (§3.3).

Son olarak §1, GPL §3'ün (anti-dolanım/DRM maddesi) bu yolla dağıtımda bağlayıcı olmadığını söylüyor: "You may convey a covered work under sections 3 and 4 of this License without being bound by section 3 of the GNU GPL." DRM tartışmasının LGPL'de GPL'deki kadar sert olmamasının bir başka nedeni.

### 3.2 Flutter/Dart'ta bu nasıl karşılanır?

**Kısa cevap: karşılanamıyor gibi görünüyor, ve nedeni Dart'ın derleme modeli.**

**Sürüm derlemesi bütün programı tek bir yerel ikiliye kaynaştırıyor.** Flutter'ın kendi SSS'i ([docs.flutter.dev/resources/faq](https://docs.flutter.dev/resources/faq)):

> The Dart code (both the SDK's and yours) are ahead-of-time (AOT) compiled into native, ARM, and x86-64 libraries. Those libraries are included in a 'runner' Android project, and the whole thing is built into an `.apk`.

iOS için aynı sayfa aynı şeyi tek bir ARM kütüphanesi için söylüyor; Flutter'ın araç zinciri kaynağında bunun `App.framework` olduğu görülüyor ([flutter_tools/lib/src/base/build.dart](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/base/build.dart)). Aynı SSS ağaç sarsmayı da anlatıyor:

> Using static analysis we can strip out anything that isn't used ('tree shaking').

Yapısal olarak belirleyici olan bu: **paketinizin kodu çıktıda ayrılabilir bir birim değil.** Satır içine alınmış, devirtualize edilmiş, budanmış ve tek anlık görüntüye karıştırılmış durumda. dmrtd'yi "sökülüp yerine konabilecek" bir parça olarak göstermek mümkün değil.

**Dinamik bağlamanın her yolu kapalı.** Doğrulananlar:

| Mekanizma | Sürüm AOT'sinde çalışır mı | Kaynak |
| --- | --- | --- |
| `dart:mirrors` | **Hayır** — "this library is unavailable for Flutter apps" | [Flutter SSS](https://docs.flutter.dev/resources/faq) |
| `Isolate.spawnUri` | **Hayır** — `SkipByDesign # Isolate.spawnUri is not supported in AOT.` | [dart-lang/sdk `vm.status`](https://github.com/dart-lang/sdk/blob/main/runtime/tests/vm/vm.status) |
| `deferred as` / deferred components | **Kısmen** — yalnız Android ve web, iOS yok; üstelik parçalar aynı bütün-program derlemesinden çıkıyor ve üçüncü tarafça değiştirilemiyor | [docs.flutter.dev/perf/deferred-components](https://docs.flutter.dev/perf/deferred-components) |
| `dart:ffi` | **Hayır** — yalnız C ABI'si olan yerel kütüphaneler; saf Dart paketi için işe yaramaz | [dart.dev/interop/c-interop](https://dart.dev/interop/c-interop) |
| Dynamic Modules | **Hayır** — deneysel, hiçbir SDK'da yok, ve *yalnızca eklemeli* | [dart-lang/sdk `pkg/dynamic_modules`](https://github.com/dart-lang/sdk/blob/main/pkg/dynamic_modules/README.md) |
| Code push | **Hayır** — Flutter doğrudan desteklemiyor | [Flutter SSS](https://docs.flutter.dev/resources/faq) |

Dynamic Modules özellikle dikkat çekici, çünkü tam olarak bu soruyu kapatıyor:

> The main semantic restriction: all extensions are additive. Dynamic modules cannot replace an existing declaration in the application, not even if that declaration was delivered through a dynamic module earlier.

Yani Dart ekibinin üzerinde çalıştığı deneysel mekanizma bile "var olan bir bildirimin yerine yenisini koyma" işini **tasarım gereği** yapmıyor.

**Mağaza kuralları da bağımsız olarak bu yolu kapatıyor.** Apple App Store Review Guidelines §2.5.2: *"may not … download, install, or execute code which introduces or changes features or functionality of the app"*. Google Play cihaz kötüye kullanım politikası: *"An app may not download executable code (such as dex, JAR, .so files) from a source other than Google Play."* Yani Dart yapabilse bile mağazalar izin vermezdi.

**Peki §4(d)(1) yerine §4(d)(0)'ın nesne dosyası yolu uygulanabilir mi?** Burada işler ilginçleşiyor ve cevap "hayır"a yakın ama tam kapalı değil.

Nesne dosyası **üretiliyor**. Flutter'ın Apple derlemesinde `gen_snapshot`'a `--macho-object=app.o` geçiliyor; `gen_snapshot --help` çıktısında (Flutter 3.47.1 ile gelen ikiliden doğrudan okundu) `app-aot-assembly`, `app-aot-elf`, `app-aot-macho-dylib`, `app-aot-pecoff-obj` biçimlerinin hepsi var. **Ama bu nesne dosyası yanlış granülerlikte:** içinde dmrtd zaten kaynaşmış ve budanmış durumda, dolayısıyla "değiştirilmiş dmrtd ile yeniden bağla" işlemine elvermiyor. LGPL §4(d)(0)'ın istediği şey nesne dosyası *üretmek* değil, kullanıcının **kütüphaneyi değiştirip yeniden birleştirebileceği** bir biçim vermek.

Tek gerçek dikiş yeri bir üst katmanda: **Dart kernel (`.dill`) dosyası.** `gen_snapshot`'ın kullanımı `gen_snapshot [<vm-flags>] [<options>] <dart-kernel-file>` — yani girdi tek bir kernel dosyası. Kernel biçimi kamuya açık belgelenmiş ([pkg/kernel/binary.md](https://github.com/dart-lang/sdk/blob/main/pkg/kernel/binary.md)) ve `dart compile kernel` bunu üretebiliyor. Bu, teoride şu zinciri mümkün kılıyor: *değiştirilmiş dmrtd + Koala'nın kerneli → yeni `.dill` → `gen_snapshot` → yeni `App.framework`.*

Bu yolun önündeki engeller, ve neden "belirsiz" dediğim:

1. **`.dill` nesne kodu değil, kaynağa çok yakın.** [dart.dev/tools/dart-compile](https://dart.dev/tools/dart-compile): *"A kernel module contains a binary form of the abstract syntax tree (Kernel AST) for a Dart program."* Yani serileştirilmiş soyut sözdizim ağacı. Üstelik `dart compile kernel` seçeneklerinden `--[no-]embed-sources` **varsayılan olarak açık** ("Embed source files in the generated kernel component") — yani sıradan bir `.dill` Dart kaynağını gerçekten içinde taşıyor. `--no-embed-sources` ile kaynak metni çıkarılabilir ve sonuç "nesne koduna" yaklaşır, ama AST hâlâ kolay okunur. Kapalı kaynak iddiasıyla bağdaşıp bağdaşmadığı ürün kararı.
2. **Paket değiştirip yeniden derlemenin desteklenen bir yolu yok.** Var olan bir `.dill` içindeki bir paketin kütüphanelerini değiştirmeye dair resmî belge bulunamadı; bu zinciri sürebilecek tek komut olan `flutter assemble` ise **gizli bir komut** (`bool get hidden => !_verboseHelp;`).
3. **Biçimin kararlılık taahhüdü yok.** [pkg/kernel/README.md](https://github.com/dart-lang/sdk/blob/main/pkg/kernel/README.md): *"Both the kernel language and its implementations are unstable and are under development"* ve *"there is no semver contract for release versions of this package."*

**Sonuç:** §4(d)(0) Dart'ta *teorik olarak* `.dill` üzerinden kurulabilir, ama belgelenmemiş, desteklenmeyen ve kararlılık taahhüdü olmayan araçlarla. "Yeterince iyi bir uyum çabası" sayılır mı — bunu söyleyebilecek olan hukukçu ve nihayetinde ZeroPass.

**Flutter/Dart'ın LGPL hakkında resmî bir tutumu yok.** `flutter/flutter` ve `flutter/website` depolarında LGPL araması yapıldı; `flutter/flutter`'ın `docs/` dizininde **sıfır** sonuç, `flutter/website`'te yalnızca 1.5.4 sürüm notlarında rastlantısal bir değinme var. Yani bu soruyu Flutter tarafında cevaplayan kimse yok.

### 3.3 App Store ve Google Play kuralları buna izin veriyor mu?

**Apple: evet, ama yükümlülük sözleşmede saklı — kılavuzda değil.**

Önce beklentiyi düzeltmek gerekiyor: **App Store Review Guidelines açık kaynak hakkında hiçbir şey söylemiyor.** Belge tarandı (8 Haziran 2026 sürümü): "open source" gövde metninde sıfır kez geçiyor (tek eşleşme sitenin gezinme çubuğunda), "GPL" sıfır, "EULA" sıfır. §5.2 (Intellectual Property) yalnızca genel içerik/telif ihlalinden söz ediyor:

> Don't use protected third-party material such as trademarks, copyrighted works, or patented ideas in your app without permission… Apps should be submitted by the person or legal entity that owns or has licensed the intellectual property and other relevant rights.

Asıl yükümlülük **Apple Developer Program License Agreement**'ta (kamuya açık PDF, LYL255, 18 Ağustos 2026). Orada "FOSS" tanımlı bir terim ve **LGPL adıyla anılıyor**:

> **"FOSS" (Free and Open Source Software)** means any software that is subject to terms that, as a condition of use, copying, modification or redistribution, require such software and/or derivative works thereof to be disclosed or distributed in source code form, to be licensed for the purpose of making derivative works, or to be redistributed free of charge, including without limitation software distributed under the GNU General Public License or GNU Lesser/Library GPL.

Ve §3.3.4(A)(v) doğrudan yükümlülük koyuyor:

> If Your Application or Your Corresponding Product includes any FOSS, You agree to comply with all applicable FOSS licensing terms. You also agree not to use any FOSS in the development of Your Application or Your Corresponding Product in such a way that would cause the non-FOSS portions of the Apple Software to be subject to any FOSS licensing terms or obligations.

Yani Apple LGPL'i yasaklamıyor — **uymanızı şart koşuyor.** Bu iyi haber: LGPL'e uygun kullanım Apple'ın kendi sözleşmesince açıkça öngörülmüş.

**Kritik madde §5.1** (dikkat edilmesi gereken yer burası):

> You further represent and warrant to Apple that the licensing terms governing Your Application… or governing any third-party code or FOSS included in Your Covered Products… will be consistent with and not conflict with the digital signing or content protection aspects of the Program… In particular, such licensing terms will not purport to require Apple (or its agents) to disclose or make available any of the keys, authorization codes, methods, procedures, data or other information related to the Security Solution, digital signing or digital rights management mechanisms…

GPLv3'ü App Store'da fiilen imkânsız kılan madde budur: GPLv3 §6'nın Kurulum Bilgisi şartı tam olarak imzalama anahtarlarına dokunur. **LGPL-3.0 için durum farklı**, çünkü §4(e) Kurulum Bilgisi'ni ancak GPL §6 zaten gerektiriyorsa istiyor ve §3.1'de gösterildiği gibi burada gerektirmiyor. Ama bu bir yorum zinciri; §5.1'in ihlali hâlinde yaptırım ağır: *"Apple may immediately cease distribution of any affected Licensed Applications."*

**VLC vakası LGPL'e taşınmıyor.** 2010'daki olayın birincil kaynağı, şikâyeti yapan geliştiricinin kendi duyurusu — [FSF'nin aktardığı hâliyle](https://www.fsf.org/blogs/licensing/vlc-enforcement):

> VLC media player is free software licensed solely under the terms of the… GNU General Public License (a.k.a. GPL). Those terms are contradicted by the products usage rules of the AppStore through which Apple delivers applications to users of its mobile devices.

Çatışma **Usage Rules**'la, yani paylaşma/cihaz sınırı kurallarıyla. Bu bir GPL "başka kısıtlama koyamazsın" sorunudur. LGPL §4 birleşik yapıtın "seçeceğiniz koşullarla" dağıtılmasına izin verdiği ve yeniden dağıtım özgürlüğü **istemediği** için aynı çatışma doğmaz. Nitekim Rémi Denis-Courmont'un aynı tartışmadaki [kendi mesajı](https://mailman.videolan.org/pipermail/vlc-devel/2010-October/076924.html) da meselenin sanıldığı kadar kapalı olmadığını söylüyor: *"It seems Apple changed the terms so that third parties could use a different license."*

**Apple'ın standart EULA'sındaki açık kaynak muafiyeti.** Bugünkü metin ([apple.com/legal/internet-services/itunes/dev/stdeula](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)), §a:

> You may not copy (except as permitted by this license and the Usage Rules), reverse-engineer, disassemble, attempt to derive the source code of, modify, or create derivative works of the Licensed Application, any updates, or any part thereof (**except as and only to the extent that any foregoing restriction is prohibited by applicable law or to the extent as may be permitted by the licensing terms governing use of any open-sourced components included with the Licensed Application**).

Bu muafiyet tam da LGPL §4'ün giriş cümlesinin istediği iki şeyi — değiştirme ve hata ayıklama amaçlı tersine mühendislik — açık kaynak bileşenler için serbest bırakıyor. **Ama dar:** "nontransferable" ve "you may not transfer, redistribute or sublicense" kısıtlarına dokunmuyor. LGPL §4 bunları zaten istemediği için sorun değil; GPL için ölümcül olan da tam bu fark.

**Kendi EULA'mızı verirsek.** Developer Program License Agreement, Schedule 1 §3.2 buna izin veriyor, ama Exhibit B'deki 10 asgari şart zorunlu. Madde 2:

> The license granted to the end-user for the Licensed Application must be limited to a non-transferable license to use the Licensed Application on any Apple-branded Products that the end-user owns or controls…

Yani kendi EULA'mızda **devredilemezlik zorunlu**. LGPL §4 açısından sorun değil. Ama dikkat: Apple'ın standart EULA'sındaki açık kaynak muafiyeti Exhibit B'nin asgari şartları arasında **yok** — kendi EULA'mızı yazarsak o muafiyeti kendimiz koymamız gerekir, yoksa §4'ün giriş cümlesini ihlal ederiz.

**Google Play: hiçbir engel yok.**

Google Play Developer Distribution Agreement'ta (15 Eylül 2025) "open source" **sıfır kez** geçiyor. Developer Program Policies'te de sıfır; "GPL" sıfır; "EULA" sıfır. Politikalardaki 27 "licen*" eşleşmesinin tamamı düzenleyici lisanslarla ilgili (kredi, kumar, ehliyet), hiçbiri yazılım lisansı değil. DDA §5.3 kullanıcıya verilen lisansı tanımlıyor:

> You grant to the user a nonexclusive, worldwide, and perpetual license to perform, modify color of, or add themes to, your Product icons, display… and use the Product… If You choose, You may include a separate end user license agreement ("EULA") in Your Product…

Kendi EULA'mız **isteğe bağlı** ve içeriği dayatılmıyor; devredilemezlik şartı yok. §11.2 yalnızca genel bir taahhüt istiyor: *"If You use third-party materials, You represent and warrant that You have the right to distribute the third-party material in the Product."* Google tarafında iş, LGPL'e uymakla biter.

| | Apple | Google |
| --- | --- | --- |
| Açık kaynak yükümlülüğü | DPLA §3.3.4(A)(v) — FOSS şartlarına uy | Yok |
| Kendi EULA'nız | İzinli, ama Exhibit B'deki 10 asgari şart zorunlu | İsteğe bağlı, içerik dayatılmıyor |
| Kullanıcıya lisans | **Devredilemez** (zorunlu) | Sürekli; devir kısıtı dayatılmıyor |
| Açık kaynak muafiyeti | Standart EULA §a'da var, dar kapsamlı | Konu edilmiyor |

### 3.4 Pratikte ne yapılıyor?

**Flutter'ın hazır mekanizması §4(a) ve §4(b)'yi karşılamak için var, ama dmrtd'de olduğu gibi çalışmaz.**

Flutter uygulamaya gömülü bir lisans ekranı sunuyor: `showLicensePage`, `showAboutDialog`, `AboutListTile` ve alttaki `LicenseRegistry`. Nasıl çalıştığı [`packages/flutter/lib/src/foundation/licenses.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/foundation/licenses.dart) belge yorumunda anlatılıyor:

> The flutter tool will automatically collect the contents of all the LICENSE files found at the root of each package into a single NOTICES file (or its compressed variant, `NOTICES.Z`) in the default asset bundle.

**Buradaki tuzak — ve doğrulandı.** Toplayıcının gerçek davranışı yerel Flutter 3.47.1 kurulumundaki `packages/flutter_tools/lib/src/license_collector.dart` dosyasından okundu:

```dart
// First check for NOTICES, then fallback to LICENSE
File file = _fileSystem.file(packageUri.resolve('../NOTICES'));
if (!file.existsSync()) {
  file = _fileSystem.file(packageUri.resolve('../LICENSE'));
}
if (!file.existsSync()) {
  continue;
}
```

Yalnızca **tam olarak `NOTICES` ya da `LICENSE`** adlı dosyalara bakıyor; ikisi de yoksa paketi **sessizce atlıyor** (`continue`). dmrtd'de ikisi de yok — dosyalar `LICENSE.LGPL` ve `LICENSE.COMMERCIAL` adında. Yani `showLicensePage`'i eklemek dmrtd'yi listeye **sokmaz**: ekran görünür, düzgün çalışır, başka paketlerin lisanslarını dosdoğru listeler, ve dmrtd eksik kalır. Uyarı da çıkmaz. §4(a) ve §4(b) böylece karşılanmış sanılıp karşılanmamış olur — ki bu, doğru kurulmuş bir mekanizmanın sonradan sessizce geçersiz kılınmasının ders kitabı örneği. Çözüm: `LicenseRegistry.addLicense` ile elle kayıt, ve **GPL-3.0 metnini de** eklemek (§4(b) ikisini birden istiyor, dmrtd paketinde GPL metni yok).

**Yaygın uygulama, gözlemlenebildiği kadarıyla.** Kapalı kaynak mobil uygulamaların standart davranışı bir "Açık kaynak lisansları" ekranı koymak ve orada bildirim + lisans metinlerini göstermek — yani §4(a)–(c). **§4(d)(0) yeniden bağlama malzemesini fiilen yayımlayan kapalı kaynak bir mobil uygulama örneği, birincil kaynakla doğrulanabilir biçimde bulunamadı.** Bulunamamış olması yok olduğu anlamına gelmez; ama "herkes şöyle yapıyor" diyerek dayanılabilecek belgelenmiş bir emsal de gösteremiyorum.

**Bir başka LGPL çift-lisansçısının kendi tutumu — Qt.** *(İkincil kaynak: Qt'nin LGPL yorumu bizi bağlamaz, ama ticari çift-lisans veren bir tarafın nasıl düşündüğünü gösterdiği için değerli.)* [qt.io/development/open-source-lgpl-obligations](https://www.qt.io/development/open-source-lgpl-obligations):

> In case of static linking of the library, the application itself may no longer be "work that uses the library" and thus become subject to LGPL. It is recommended to either link dynamically, or provide the application source code to the user under LGPL.

Bu, **FSF'nin görüşünden daha katı** — FSF nesne biçimini yeterli sayıyor, Qt kaynak vermeyi tavsiye ediyor. (Qt'nin "work that uses the library" ifadesi LGPLv2.1 terminolojisi, v3'ün değil; sayfa sürümleri karıştırıyor.) Buradaki ders şu: **ticari çift-lisans veren taraf, LGPL'i satın alma yönünde iten katı yorumu benimsemeye eğilimlidir.** ZeroPass da çift lisansçı. Aynı sayfa mağazalar için de uyarıyor: *"some means of distribution, such as online application stores, may have rules that are in conflict with LGPL."*

### 3.5 `ZeroPass/dmrtd`'nin kendi lisans dosyası ne diyor?

Depodaki dosyalar doğrudan okundu ([github.com/ZeroPass/dmrtd](https://github.com/ZeroPass/dmrtd), `master`).

**Çift lisans ifadesinin tam metni.** [README.md](https://github.com/ZeroPass/dmrtd/blob/master/README.md) sonundaki "License" başlığı:

> This project is licensed under the terms of the GNU Lesser General Public License (LGPL) for open-source use and a Commercial License for proprietary use. See the [LICENSE.LGPL](/LICENSE.LGPL) and [LICENSE.COMMERCIAL](/LICENSE.COMMERCIAL) files for details.

README'nin tepesinde ayrıca `LGPL v3` rozeti var ve `LICENSE.LGPL`'e bağlanıyor. Not: README "LGPL" derken sürüm numarası vermiyor; sürümü söyleyen rozet ve dosyanın kendisi.

**`LICENSE.LGPL` gerçekten LGPL-3.0 mu?** **Evet, değiştirilmemiş hâliyle.** Dosya Markdown biçimli, gnu.org'un düz metninden görsel olarak farklı görünüyor; ama alfanümerik karakterlere indirgenip karşılaştırıldığında gnu.org'un `lgpl-3.0.txt` dosyasıyla **birebir aynı** çıktı. Başlık "Version 3, 29 June 2007". Ek madde, istisna ya da özel izin yok — yani §4'ün yukarıda incelenen hâli aynen geçerli.

**`LICENSE.COMMERCIAL` ne diyor?** [Dosya](https://github.com/ZeroPass/dmrtd/blob/master/LICENSE.COMMERCIAL) kısa (2 KB) ve büyük ölçüde doldurulmamış bir şablon:

- Lisans veren "ZeroPass team"; tüzel kişilik dosyanın altında **ZP, RAČUNALNIŠKO SVETOVANJE IN PROGRAMIRANJE, LUKA PERČIČ S.P.** — Slovenya'da bir şahıs şirketi.
- §1: ücret ödenmesi şartına bağlı "non-exclusive, non-transferable, royalty-bearing" kullanım hakkı.
- §2: ücret "faturada ya da ödeme sözleşmesinde belirtileceği" şekilde. **Dosyada fiyat yok.**
- §3 Kısıtlamalar: *"Redistributing or sublicensing the software in any form"* ve *"Attempting to derive the source code for the software"* yasak. **Birinci yasak sorunlu:** uygulamaya gömülü olarak mağazada dağıtmak lafzen "yeniden dağıtım" sayılabilir. Niyetin bu olmadığı açık, ama metin bunu söylemiyor — satın alınacaksa yazılı olarak düzeltilmeli.
- §4: destek ve bakım dahil değil, ayrı sözleşme konusu.
- §5: garanti ve sorumluluk yok.
- §6 Uygulanacak hukuk: **"the laws of [Your Jurisdiction]"** — yer tutucu doldurulmamış. Dosyanın şablondan kopyalanıp bitirilmediğinin doğrudan kanıtı.

**İletişim ve fiyat.** `zeropass@pm.me` (dosyada: *"For inquiries regarding commercial licensing and payment, please contact us via zeropass@pm.me"*) ve `t.me/zeropass`. **Fiyat ya da fiyat sayfası hiçbir yerde bulunamadı** — ne depoda, ne README'de. Teklif istemek gerekiyor.

**Küçük bir belirsizlik.** Kaynak dosyalarının başlıkları LGPL başlığı taşımıyor; `// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.` yazıyor (`lib/dmrtd.dart`, `lib/src/passport.dart`, `lib/internal.dart` kontrol edildi). "All rights reserved" ile depo düzeyindeki LGPL beyanı arasında lafzen bir gerilim var. Pratikte README + `LICENSE.LGPL` yeterince açık kabul edilir, ama ticari lisans yazışmasında bunu da sormak ucuz.

**Paket dağıtımı.** dmrtd **pub.dev'de yok** (`pub.dev/api/packages/dmrtd` → `NoSuchKey`). README kurulum için `path:` bağımlılığı öneriyor. Yani bağımlılık git referansı ya da vendoring yoluyla girecek; her iki durumda da dağıtılan APK/IPA kütüphaneyi içinde taşıyor ve LGPL yükümlülüğü doğuyor. `pubspec.yaml`: sürüm `2.0.0`, `sdk: ^3.6.0`. Son etiket `v2.0.0`, son commit **12 Haziran 2025**.

**Bağımlılık ağacı taranmadı.** dmrtd'nin kendi bağımlılıkları (`flutter_nfc_kit`, `pointycastle`, `tripledes_nullsafety`, `crypto_keys_plus`, `diffie_hellman`, `archive`, `expandable`, `collection`, `convert`, `crypto`, `fixnum`, `logging`, `meta`) ayrı lisanslar taşıyor. Bu belge yalnızca dmrtd'nin kendi lisansına baktı.

---

## 4. Belirsiz kalanlar

1. **§4(d)(0) Dart'ta nasıl karşılanır — ve karşılanabilir mi?** Bu belgenin en zayıf noktası ve asıl riski. `.dill` üzerinden teorik bir yol var ama belgelenmemiş, desteklenmeyen, kararlılık taahhüdü olmayan araçlarla. "Yeterli uyum çabası" sayılır mı bilinmiyor. **Kim cevaplayabilir:** öncelikle **ZeroPass** (telif hakkı sahibi olarak tek bağlayıcı yorum onda) — doğrudan sorulmalı: *"Dart AOT statik gömüyor, §4(d)(0)'ı nasıl karşılamamızı bekliyorsunuz?"* Cevap "karşılayamazsınız, ticari lisans alın" olabilir; bu da net bir cevaptır. İkincil olarak açık kaynak lisanslarına çalışmış bir avukat.

2. **`.dill` yayımlamak "kapalı kaynak" kalmakla bağdaşır mı?** Kernel dosyası serileştirilmiş AST; `--no-embed-sources` ile kaynak metni çıkarılsa bile okunabilirliği yüksek. Bu hukuki değil **ürün/ticari sır kararı**. **Kim cevaplayabilir:** ürün sahibi ve teknik lider birlikte.

3. **§4(e) gerçekten tetiklenmiyor mu?** GPL §6'nın "Kullanıcı Ürünü zilyetliğinin devri" koşulu bir uygulama dağıtımında oluşmuyor görünüyor, ve bu okuma Apple DPLA §5.1 taahhüdü açısından da kritik. Ama bu benim metin okumam. **Kim cevaplayabilir:** hukuk danışmanı.

4. **Ticari lisans §3'teki "yeniden dağıtım yasağı" uygulamaya gömmeyi kapsıyor mu?** Lafzen kapsıyor gibi duruyor, ki bu ticari lisansı kullanılamaz kılardı — açık bir metin hatası. **Kim cevaplayabilir:** ZeroPass, yazılı olarak.

5. **Ticari lisansın fiyatı ve şartları.** Hiçbir yerde yayımlanmamış. Uygulanacak hukuk boş bırakılmış. **Kim cevaplayabilir:** `zeropass@pm.me`.

6. **Kaynak dosyalarındaki "All rights reserved" ile depo düzeyindeki LGPL beyanı arasındaki gerilim.** **Kim cevaplayabilir:** ZeroPass.

7. **dmrtd'nin bağımlılık ağacının lisans durumu.** Taranmadı. **Kim cevaplayabilir:** bir sonraki teknik inceleme; `flutter pub deps` + lisans taraması.

8. **§4(d)(0) malzemesini fiilen yayımlayan bir emsal var mı?** Birincil kaynakla doğrulanabilir bir örnek bulunamadı. Yokluğu kanıtlanmış değil, yalnızca bulunamadı.

---

## 5. Kaynaklar

Tümüne 6 Eylül 2026'da erişildi. Birincil kaynaklar, aksi belirtilmedikçe.

**Lisans metinleri**
- [GNU LGPL-3.0 tam metni](https://www.gnu.org/licenses/lgpl-3.0.txt) — §0, §1, §4, §5 alıntıları
- [GNU GPL-3.0 tam metni](https://www.gnu.org/licenses/gpl-3.0.txt) — §6 (Kurulum Bilgisi, teslim yöntemleri)
- [FSF GNU lisansları SSS — LGPLStaticVsDynamic](https://www.gnu.org/licenses/gpl-faq.html#LGPLStaticVsDynamic) — statik bağlamada nesne biçimi yeterli
- [FSF — The LGPL and Java](https://www.gnu.org/licenses/lgpl-java.html) — geleneksel bağlaması olmayan diller için FSF tutumu

**dmrtd deposu** (`master` dalı)
- [README.md](https://github.com/ZeroPass/dmrtd/blob/master/README.md) · [LICENSE.LGPL](https://github.com/ZeroPass/dmrtd/blob/master/LICENSE.LGPL) · [LICENSE.COMMERCIAL](https://github.com/ZeroPass/dmrtd/blob/master/LICENSE.COMMERCIAL) · [pubspec.yaml](https://github.com/ZeroPass/dmrtd/blob/master/pubspec.yaml)

**Apple**
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — sayfada belirtilen son güncelleme 8 Haziran 2026; §2.5.2, §5.2
- [Apple Developer Program License Agreement (PDF)](https://developer.apple.com/support/downloads/terms/apple-developer-program/Apple-Developer-Program-License-Agreement-English.pdf) — belge kodu LYL255, 18 Ağustos 2026, 130 sayfa, kimlik doğrulaması gerekmeden erişilebiliyor; FOSS tanımı, §3.3.4(A)(v), §5.1, Schedule 1 §3.2, Exhibit B
- [Licensed Application End User License Agreement](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) — §a ve açık kaynak muafiyeti
- [Apple Media Services Terms and Conditions](https://www.apple.com/legal/internet-services/itunes/us/terms.html) — sayfada belirtilen son güncelleme 15 Eylül 2025; §F Usage Rules

**Google**
- [Google Play Developer Distribution Agreement (EN)](https://play.google.com/intl/en/about/developer-distribution-agreement.html) — yürürlük 15 Eylül 2025; §5.3, §11.2. *Not: kanonik URL coğrafi olarak yerelleşiyor ve Türkçe dönüyor; İngilizce metin için `/intl/en/` yolu gerekti.*
- [Google Play Developer Program Policies](https://support.google.com/googleplay/android-developer/answer/17190352?hl=en) · [Fikri mülkiyet politikası](https://support.google.com/googleplay/android-developer/answer/9888072?hl=en) · [Cihaz kötüye kullanımı](https://support.google.com/googleplay/android-developer/answer/9888379)

**Dart / Flutter**
- [Flutter SSS](https://docs.flutter.dev/resources/faq) — AOT derleme, ağaç sarsma, mirrors, code push, lisans gösterimi
- [Flutter mimari genel bakış](https://docs.flutter.dev/resources/architectural-overview) · [Deferred components](https://docs.flutter.dev/perf/deferred-components)
- [dart.dev — dart compile](https://dart.dev/tools/dart-compile) (kernel = AST) · [C interop](https://dart.dev/interop/c-interop)
- [dart-lang/sdk — `runtime/tests/vm/vm.status`](https://github.com/dart-lang/sdk/blob/main/runtime/tests/vm/vm.status) · [`pkg/kernel/README.md`](https://github.com/dart-lang/sdk/blob/main/pkg/kernel/README.md) · [`pkg/kernel/binary.md`](https://github.com/dart-lang/sdk/blob/main/pkg/kernel/binary.md) · [`pkg/dynamic_modules/README.md`](https://github.com/dart-lang/sdk/blob/main/pkg/dynamic_modules/README.md)
- [flutter/flutter — `flutter_tools/lib/src/base/build.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/base/build.dart) · [`foundation/licenses.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/foundation/licenses.dart)
- `gen_snapshot --help` çıktısı, yerel Flutter 3.47.1 kurulumundaki ikiliden doğrudan okundu

**VLC vakası**
- [Rémi Denis-Courmont, vlc-devel listesi, 27 Ekim 2010](https://mailman.videolan.org/pipermail/vlc-devel/2010-October/076924.html) — şikâyeti yapan geliştiricinin kendi sözleri
- [FSF — VLC developer takes a stand against DRM enforcement in Apple's App Store](https://www.fsf.org/blogs/licensing/vlc-enforcement), 29 Ekim 2010 — FSF'nin kendi yayını; olay anlatımı için ikincil, FSF'nin tutumu için birincil

**İkincil, doğrulanmadı**
- [Qt — Obligations of the GPL and LGPL](https://www.qt.io/development/open-source-lgpl-obligations) — başka bir çift-lisansçının kendi yorumu; LGPL'in anlamı için bağlayıcı değil, ticari lisansçı bakışını göstermek için alıntılandı
