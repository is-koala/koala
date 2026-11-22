import 'package:material_ui/material_ui.dart';

/// Temadan bağımsız marka, vurgu ve durum renkleri. Temaya göre değişenler
/// `ColorScheme`'de; `context` üzerinden okunur (`context.textPrimary` ...).
class AppColors {
  /// Renkli ikon kutusu zemininin opaklığı: ikon önde, kutu geride kalsın.
  static const double surfaceTintAlpha = 0.12;

  /// Okunmamış / seçili satır vurgusu; bütün satırı kapladığı için kutudan da
  /// düşük.
  static const double rowTintAlpha = 0.04;

  // ---------------------------------------------------------------- Marka

  /// Koala yeşili. Butonlar, seçili durumlar ve business navbar'ı.
  static const Color primaryColor = Color(0xFF72AD70);

  /// [primaryColor]'ın koyu tonu: basılı hâl, gradient ucu, ikincil vurgu.
  static const Color primaryDeep = Color(0xFF5A9A58);

  /// [primaryColor]'ın açık tonu: seçili satır zemini, rozet arka planı.
  static const Color primarySoft = Color(0xFFDCEDDB);

  /// Dokunma dalgası; zeminde görünsün diye [primarySoft]'tan koyu.
  static final Color primaryTint = primaryColor.withValues(alpha: 0.18);

  /// Doygun zeminlerin (yeşil buton) üstündeki içerik; iki temada beyaz.
  static const Color onAccent = Color(0xFFFFFFFF);

  // -------------------------------------------------------- Durum renkleri

  /// Olumlu durum: onaylanan başvuru, aktif ilan, tamamlanan iş.
  static const Color success = Color(0xFF4CAF50);

  /// Bekleyen / dikkat isteyen durum: değerlendirmedeki başvuru.
  static const Color warning = Color(0xFFF5A623);

  /// Olumsuz durum: reddedilen başvuru, silme eylemi, hata.
  static const Color danger = Color(0xFFE74C3C);

  static const Color info = Color(0xFF5B8DEF);

  /// Soluk yeşil zeminde [success] yeterince okunmuyor.
  static const Color successStrong = Color(0xFF388E3C);

  static const Color pending = Color(0xFF9C27B0);

  static const Color rating = Color(0xFFFFC107);

  /// Soluk sarı zeminde [rating] okunmuyor.
  static const Color ratingStrong = Color(0xFFFF8F00);

  // ------------------------------------------------- Durum bölümü zeminleri

  /// Durum bölümlerinin zeminleri. Koyu karşılıkları [darkTile]'a yakın ama
  /// renkli; widget'lar `context.pendingSurface` gibi okur.
  static const Color surfacePending = Color(0xFFF3E5F5);
  static const Color surfacePendingDark = Color(0xFF2A2130);

  static const Color surfacePayout = Color(0xFFFFF3E0);
  static const Color surfacePayoutDark = Color(0xFF302719);

  /// "Onayını Bekleyen İşler" zemini: eylem bekliyor ama ne olumlu ne olumsuz,
  /// o yüzden mavi.
  static const Color surfaceAwaiting = Color(0xFFE8F0FE);
  static const Color surfaceAwaitingDark = Color(0xFF1C2433);

  /// "Devam Eden İş": diğer bölümlerin renkleri tutulu olduğu için turkuaz;
  /// hiçbiriyle karışmamalı.
  static const Color progress = Color(0xFF00897B);
  static const Color surfaceProgress = Color(0xFFE0F2F1);
  static const Color surfaceProgressDark = Color(0xFF16292A);

  /// Temadan bağımsız açık zeminlerin üstündeki içerik (girişteki harita
  /// görseli); `textPrimary` koyu temada beyaza dönüp kaybolurdu.
  static const Color onLightSurface = Color(0xFF212121);

  // ---------------------------------------------------- Kategori renkleri

  /// Kategori renkleri; pin, avatar ve rozet aynı rengi kullanıyor ki ilan
  /// listede ve haritada tanınsın. Doygun tonlar sade haritada göz yorduğu için
  /// bilerek sönük.
  static const Color categoryPhotography = Color(0xFF9479AD);
  static const Color categoryWaiter = Color(0xFFD4845F);
  static const Color categoryPetCare = Color(0xFF6E9E73);
  static const Color categoryDesign = Color(0xFF6690C4);
  static const Color categoryBarista = Color(0xFF9C7B63);

  // ------------------------------------------------------- Avatar paleti

  /// Görseli olmayan avatarların renk çiftleri; çift ismin `hashCode`'undan
  /// seçiliyor, aynı isim hep aynı rengi alır.
  static final List<AvatarColor> avatarPalette = [
    AvatarColor(const Color(0xFF2196F3), const Color(0xFF1976D2)),
    AvatarColor(const Color(0xFF4CAF50), const Color(0xFF388E3C)),
    AvatarColor(const Color(0xFF9C27B0), const Color(0xFF7B1FA2)),
    AvatarColor(const Color(0xFFFF9800), const Color(0xFFF57C00)),
    AvatarColor(const Color(0xFF009688), const Color(0xFF00796B)),
    AvatarColor(const Color(0xFFE91E63), const Color(0xFFC2185B)),
    AvatarColor(const Color(0xFF3F51B5), const Color(0xFF303F9F)),
    AvatarColor(const Color(0xFF00BCD4), const Color(0xFF0097A7)),
    AvatarColor(const Color(0xFFF44336), const Color(0xFFD32F2F)),
    AvatarColor(const Color(0xFFFFC107), const Color(0xFFFFA000)),
    AvatarColor(const Color(0xFF673AB7), const Color(0xFF512DA8)),
    AvatarColor(const Color(0xFF8BC34A), const Color(0xFF689F38)),
  ];

  static final AvatarColor avatarPlaceholder = AvatarColor(
    const Color(0xFF9E9E9E),
    const Color(0xFF757575),
  );

  /// [seed] için kararlı bir çift; boşsa [avatarPlaceholder].
  static AvatarColor avatarColorFor(String seed) {
    if (seed.isEmpty) return avatarPlaceholder;
    return avatarPalette[seed.hashCode.abs() % avatarPalette.length];
  }

  // ------------------------------------------------ Tema besleyici değerler
  // Yalnız theme.dart'taki ColorScheme'ler için; widget'larda kullanılmaz.

  static const Color lightBackground = Color(0xFFFFFFFF);

  // Açık temanın grileri nötr (üç kanal eşit): iOS grileri maviye çalıyor ve
  // kartlar uygulamanın sıcak tonları arasında soğuk duruyor.

  /// Kartın zemini. Sayfa zemininden ayrılsın diye beyazdan bir tık koyu.
  static const Color lightSurfaceLow = Color(0xFFF9F9F9);
  static const Color lightTile = Color(0xFFF3F3F3);
  static const Color lightTileHigh = Color(0xFFE9E9E9);
  static const Color lightSurfaceHighest = Color(0xFFDFDFDF);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF6B6B6B);
  static const Color lightTextTertiary = Color(0xFF9A9A9A);
  static const Color lightDivider = Color(0xFFE4E4E4);

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurfaceLow = Color(0xFF181818);
  static const Color darkTile = Color(0xFF1E1E1E);
  static const Color darkTileHigh = Color(0xFF2A2A2A);
  static const Color darkSurfaceHighest = Color(0xFF353535);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(0xFF777777);
  static const Color darkDivider = Color(0xFF333333);

  // ------------------------------------------------------------- Yüzeyler

  /// Navbar zemini temadan bağımsız yeşil, gölgesi de sabit.
  static final Color navShadow = Colors.black.withValues(alpha: 0.30);

  /// Alt buton çubuğunun gölgesi; çubuk yüzmüyor, o yüzden çok hafif.
  static final Color barShadow = Colors.black.withValues(alpha: 0.05);

  /// Modal karartma iki temada da koyu: beyaz karartma arkadaki sayfanın devre
  /// dışı olduğunu anlatmaz.
  static const Color scrim = Color(0xFF000000);

  /// Biniş QR'ı iki temada da beyaz üstüne siyah: ters renkli QR'ı birçok
  /// okuyucu tanımıyor.
  static const Color qrBackground = Color(0xFFFFFFFF);
  static const Color qrForeground = Color(0xFF000000);

  /// Kamera vizöründe tarama penceresi dışındaki karartmanın opaklığı.
  static const double scannerScrimAlpha = 0.55;

  /// Harita zemini temadan bağımsız, gölgesi de sabit.
  static final Color mapShadow = Colors.black.withValues(alpha: 0.15);
}

/// Avatar zemini ve metin rengi; okunurluk için birlikte tanımlı.
class AvatarColor {
  const AvatarColor(this._base, this.foreground);

  final Color _base;

  Color get background => _base.withValues(alpha: 0.2);

  final Color foreground;
}
