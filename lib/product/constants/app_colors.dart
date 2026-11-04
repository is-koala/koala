import 'package:flutter/material.dart';

/// Temadan bağımsız marka, vurgu ve durum renkleri.
///
/// Zemin, metin, ayraç gibi **temaya göre değişen** renkler burada değil,
/// [ThemeData.colorScheme] içinde tanımlı; onlara `context` üzerinden
/// erişilir (`context.tileColor`, `context.textPrimary` ...).
/// Bkz. `product/extensions/context_extensions.dart`.
class AppColors {
  /// Renkli ikon kutularının ve rozetlerin zemin opaklığı. Renk değil ton
  /// farkı yaratacak kadar düşük: ikon önde kalmalı, kutu geride.
  static const double surfaceTintAlpha = 0.12;

  /// Okunmamış / seçili satırın zemin vurgusu. Kutu tonundan daha da
  /// düşük, çünkü bütün satırı kaplıyor.
  static const double rowTintAlpha = 0.04;

  // ---------------------------------------------------------------- Marka

  /// Koala yeşili. Butonlar, seçili durumlar ve business navbar'ı.
  static const Color primaryColor = Color(0xFF72AD70);

  /// [primaryColor]'ın koyu tonu: basılı hâl, gradient ucu, ikincil vurgu.
  static const Color primaryDeep = Color(0xFF5A9A58);

  /// [primaryColor]'ın açık tonu: seçili satır zemini, rozet arka planı.
  static const Color primarySoft = Color(0xFFDCEDDB);

  /// Dokunma dalgası (splash) ve seçili satır vurgusu. [primarySoft]'tan
  /// koyu: dalga zeminin üstünde görünsün diye.
  static final Color primaryTint = primaryColor.withValues(alpha: 0.18);

  /// Doygun renkli zeminlerin (yeşil buton, ikon dairesi) üstündeki içerik.
  /// Temadan bağımsız: her iki temada da beyaz kalır.
  static const Color onAccent = Color(0xFFFFFFFF);

  // -------------------------------------------------------- Durum renkleri

  /// Olumlu durum: onaylanan başvuru, aktif ilan, tamamlanan iş.
  static const Color success = Color(0xFF4CAF50);

  /// Bekleyen / dikkat isteyen durum: değerlendirmedeki başvuru.
  static const Color warning = Color(0xFFF5A623);

  /// Olumsuz durum: reddedilen başvuru, silme eylemi, hata.
  static const Color danger = Color(0xFFE74C3C);

  /// Bilgilendirme ve nötr vurgu. Sohbet balonu ve rozetlerde kullanılıyor.
  static const Color info = Color(0xFF5B8DEF);

  /// Değerlendirilmiş / tamamlanmış etiketlerinin metin rengi; soluk yeşil
  /// zemin üstünde [success] yeterince okunmuyor.
  static const Color successStrong = Color(0xFF388E3C);

  /// Başvurusu değerlendirmede bekleyen iş.
  static const Color pending = Color(0xFF9C27B0);

  /// Puanlama yıldızları. Sarı, temadan bağımsız: yıldız her iki temada da
  /// aynı renkte okunuyor.
  static const Color rating = Color(0xFFFFC107);

  /// Puan etiketinin metin rengi; soluk sarı zeminde [rating] okunmuyor.
  static const Color ratingStrong = Color(0xFFFF8F00);

  // ------------------------------------------------- Durum bölümü zeminleri

  /// Durum bölümlerinin renkli zeminleri.
  ///
  /// Bölümü sayfadan ayıran şey rengin tonu; bu yüzden ikisinin de koyu tema
  /// karşılığı var. Koyu tonlar [darkTile]'a yakın ama hafif renkli: aynı
  /// ayrımı koyu zeminde de veriyorlar. Widget'lar bunları doğrudan değil
  /// `context.pendingSurface` / `context.payoutSurface` üzerinden okur.
  static const Color surfacePending = Color(0xFFF3E5F5);
  static const Color surfacePendingDark = Color(0xFF2A2130);

  static const Color surfacePayout = Color(0xFFFFF3E0);
  static const Color surfacePayoutDark = Color(0xFF302719);

  /// "Onayını Bekleyen İşler" bölümünün zemini.
  ///
  /// [info] mavisinin soluk tonu: bölüm bir eylem bekliyor ama ne olumlu ne
  /// olumsuz, o yüzden ne yeşil ne turuncu. `context.awaitingSurface`
  /// üzerinden okunur.
  static const Color surfaceAwaiting = Color(0xFFE8F0FE);
  static const Color surfaceAwaitingDark = Color(0xFF1C2433);

  /// "Devam Eden İş" bölümünün zemini ve rozeti.
  ///
  /// Turkuaz, çünkü diğer dört bölümün hepsi tutulmuş: yeşil onaylanan,
  /// mor başvuru, turuncu ödeme, mavi onay bekleyen. Süren iş bunların
  /// hiçbiriyle karışmamalı — kullanıcının o an ne yapması gerektiğini
  /// söyleyen bölüm bu.
  static const Color progress = Color(0xFF00897B);
  static const Color surfaceProgress = Color(0xFFE0F2F1);
  static const Color surfaceProgressDark = Color(0xFF16292A);

  /// Temadan bağımsız **açık** zeminlerin üstündeki içerik.
  ///
  /// Giriş ekranının tam ekran harita görseli iki temada da aynı açık
  /// görsel; üstündeki kelime markası `context.textPrimary` ile okunsaydı
  /// koyu temada beyaza döner ve kaybolurdu.
  static const Color onLightSurface = Color(0xFF212121);

  // ---------------------------------------------------- Kategori renkleri

  /// İş kategorilerinin ayırt edici renkleri. Harita pini, liste avatarı ve
  /// kategori rozeti aynı rengi kullanıyor; kullanıcı ilanı listede gördüğü
  /// renkten haritada da tanısın diye.
  ///
  /// Tonlar bilerek sönük: Material'ın doygun 500 tonları sade haritanın
  /// üstünde göz yoruyordu. Ton (mor, turuncu, yeşil, mavi, kahve) korunuyor,
  /// doygunluk düşük; kategoriler bir bakışta ayrılmaya devam ediyor. Beyaz
  /// ikon ve yazı iki temada da okunur kalacak koyulukta.
  static const Color categoryPhotography = Color(0xFF9479AD);
  static const Color categoryWaiter = Color(0xFFD4845F);
  static const Color categoryPetCare = Color(0xFF6E9E73);
  static const Color categoryDesign = Color(0xFF6690C4);
  static const Color categoryBarista = Color(0xFF9C7B63);

  // ------------------------------------------------------- Avatar paleti

  /// Görseli olmayan firma/kişi avatarlarının renk çiftleri.
  ///
  /// Zemin soluk, üstündeki baş harfler aynı rengin koyu tonu; ikisi birlikte
  /// seçildiği için okunurluk her seferinde garanti. Hangi çiftin
  /// kullanılacağı ismin `hashCode`'undan türetilir, yani aynı isim her
  /// açılışta aynı rengi alır.
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

  /// İsim henüz girilmemişken kullanılan nötr avatar.
  static final AvatarColor avatarPlaceholder = AvatarColor(
    const Color(0xFF9E9E9E),
    const Color(0xFF757575),
  );

  /// [avatarPalette] içinden [seed] için kararlı bir renk çifti seçer.
  /// [seed] boşsa [avatarPlaceholder] döner.
  static AvatarColor avatarColorFor(String seed) {
    if (seed.isEmpty) return avatarPlaceholder;
    return avatarPalette[seed.hashCode.abs() % avatarPalette.length];
  }

  // ------------------------------------------------ Tema besleyici değerler
  // Buradan aşağısı yalnızca theme.dart'taki ColorScheme'leri besler.
  // Widget'larda **doğrudan kullanılmaz**; karşılıkları context üzerinden
  // okunur (context.backgroundColor, context.textPrimary ...).

  static const Color lightBackground = Color(0xFFFFFFFF);

  // Açık temanın yüzey grileri **nötr**: üç kanal eşit. Eskiden iOS sistem
  // grileriydi (#F2F2F7 ...) ve mavi kanalı birkaç adım yüksekti; metinler
  // nötr, koyu tema nötr, harita ve marka yeşili sıcak taraftayken kartlar
  // soğuk ve maviye çalıyordu. Parlaklık korunarak mavi payı kanallara
  // dağıtıldı.

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

  /// Yüzen navbar'ın gölgesi. Navbar zemini temadan bağımsız yeşil olduğu
  /// için gölgesi de sabit.
  static final Color navShadow = Colors.black.withValues(alpha: 0.30);

  /// Sayfanın altına sabitlenen buton çubuğunun gölgesi. Navbar'ınkinden çok
  /// hafif: çubuk yüzmüyor, zemine yapışık duruyor.
  static final Color barShadow = Colors.black.withValues(alpha: 0.05);

  /// Tam ekran overlay ve bottom sheet'lerin arkasındaki karartma. Modal
  /// karartma temadan bağımsız koyu kalır: açık temada beyaza gitseydi hem
  /// öndeki içerik zeminden ayrışmaz hem de "arkadaki sayfa devre dışı"
  /// hissi kaybolurdu. Opaklığı karartmayı çizen widget veriyor.
  static const Color scrim = Color(0xFF000000);

  /// Harita üzerindeki kart ve butonların gölgesi. Harita zemini temadan
  /// bağımsız olduğu için bu da sabit.
  static final Color mapShadow = Colors.black.withValues(alpha: 0.15);
}

/// Bir avatarın zemin ve üstündeki metin rengi.
///
/// İkisi birlikte tanımlı: zemin tek başına seçilip metin rengi ayrıca
/// tahmin edilmeye çalışıldığında okunurluk garanti edilemiyor.
class AvatarColor {
  const AvatarColor(this._base, this.foreground);

  final Color _base;

  /// Avatarın zemini: taban rengin soluk hâli.
  Color get background => _base.withValues(alpha: 0.2);

  /// Zeminin üstündeki baş harfler.
  final Color foreground;
}
