## Ne yapıldı?

<!-- Değişikliği bir iki cümleyle özetle. İlgili issue varsa: Closes #123 -->

## Hangi taraf?

<!-- employee / business / product (ortak) — birden fazlaysa hepsini yaz. -->

## Nasıl test edildi?

<!-- Hangi cihaz/platformda, hangi ekranlarda denendi? -->

## Ekran görüntüsü / video

<!-- UI değişikliği varsa açık ve koyu tema için ayrı ayrı ekle. Yoksa bu bölümü sil. -->

## Kontrol listesi

CONTRIBUTING.md'deki kurallara göre:

- [ ] Klasör yapısı kurala uygun (`<taraf>/features/özellik_adı/data` ve `presentation`)
- [ ] Ortak kod doğru katmanda (`product/` yalnızca iki uygulamanın da kullandıkları için)
- [ ] Business dosyaları `b_` önekini taşıyor
- [ ] Sayfa kalabalıklaştıysa Page ve PageModel `part`/`part of` ile ayrılmış
- [ ] Tekrar eden widget'lar `widgets/` klasörüne extract edilmiş
- [ ] Uzun UI blokları extract method olarak ayrılmış
- [ ] Zemin/metin/ayraç renkleri `context` erişimcilerinden alınmış; `AppColors` yalnızca marka ve durum renkleri için kullanılmış
- [ ] `TextStyle` içinde `fontFamily` tekrarı yok; ölçek `context.textTheme`'den geliyor
- [ ] Hard-coded padding, radius, boyut ve asset yolu yok; `product/constants` kullanılıyor
- [ ] Yeni ikonlar `hugeicons`'tan
- [ ] Değişiklik hem açık hem koyu temada kontrol edilmiş
- [ ] CI yeşil (format + analiz)
