import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';

/// Zemin, metin ve ayraç renkleri buradaki [ColorScheme]'lerden gelir;
/// widget'lar bunlara `context` üzerinden erişir (bkz. context_extensions).
/// [AppColors] yalnızca temadan bağımsız marka, durum ve yüzey renklerini
/// tutar.
///
/// `fontFamily` **tek yerde** — burada — tanımlı ve bütün metin ölçeklerine
/// uygulanır. `TextStyle` içinde tekrar yazma; ölçek gerekiyorsa
/// `context.textTheme.titleMedium` gibi hazır ölçekleri kullan.
const String _fontFamily = 'Poppins';

/// Uygulamanın metin ölçeği.
///
/// Boyutlar Material 3'ün varsayılan ölçeğinden değil, kodda fiilen kullanılan
/// değerlerden türetildi; amaç mevcut tasarımı bozmadan hard-code `fontSize`
/// kullanımını ortadan kaldırmak. Yeni bir boyuta ihtiyacın olduğunda buraya
/// bakıp en yakın slotu kullan, `TextStyle` içine sayı yazma.
///
/// | Slot            | Boyut | Nerede |
/// |-----------------|-------|--------|
/// | displayLarge    |  64   | KOALA kelime markası |
/// | displayMedium   |  40   | Boş durum başlığı, büyük sayı |
/// | displaySmall    |  30   | Öne çıkan istatistik |
/// | headlineLarge   |  28   | Karşılama başlığı |
/// | headlineMedium  |  24   | Sekme kökü sayfa başlığı |
/// | headlineSmall   |  22   | Varsayılan appbar başlığı |
/// | titleLarge      |  20   | Bölüm başlığı |
/// | titleMedium     |  18   | Kart başlığı |
/// | titleSmall      |  16   | Liste satırı başlığı |
/// | bodyLarge       |  16   | Form ve uzun metin |
/// | bodyMedium      |  14   | Varsayılan gövde |
/// | bodySmall       |  13   | İkincil açıklama |
/// | labelLarge      |  14   | Buton etiketi |
/// | labelMedium     |  12   | Rozet, etiket |
/// | labelSmall      |  11   | En küçük etiket |
TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
  displayLarge: TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    color: primary,
  ),
  displayMedium: TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: primary,
  ),
  displaySmall: TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: primary,
  ),
  headlineLarge: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: primary,
  ),
  headlineMedium: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: primary,
  ),
  headlineSmall: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: primary,
  ),
  titleLarge: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: primary,
  ),
  titleMedium: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: primary,
  ),
  titleSmall: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: primary,
  ),
  bodyLarge: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: primary,
  ),
  bodyMedium: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: primary,
  ),
  bodySmall: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: secondary,
  ),
  labelLarge: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: primary,
  ),
  labelMedium: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondary,
  ),
  labelSmall: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: secondary,
  ),
);

//light theme
ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: _fontFamily,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBackground,
  dividerColor: AppColors.lightDivider,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primaryColor,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.primaryDeep,
    onSecondary: AppColors.onAccent,
    surface: AppColors.lightBackground,
    onSurface: AppColors.lightTextPrimary,
    onSurfaceVariant: AppColors.lightTextSecondary,
    surfaceContainerLowest: AppColors.lightBackground,
    surfaceContainerLow: AppColors.lightSurfaceLow,
    surfaceContainer: AppColors.lightTile,
    surfaceContainerHigh: AppColors.lightTileHigh,
    surfaceContainerHighest: AppColors.lightSurfaceHighest,
    outline: AppColors.lightTextTertiary,
    outlineVariant: AppColors.lightDivider,
    error: AppColors.danger,
    onError: AppColors.onAccent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    titleTextStyle: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextPrimary,
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    shape: CircleBorder(),
    backgroundColor: AppColors.lightTileHigh,
    foregroundColor: AppColors.lightTextPrimary,
  ),
  textTheme: _textTheme(
    AppColors.lightTextPrimary,
    AppColors.lightTextSecondary,
  ),
  // Biçim `AppToast` ile aynı: doğrudan `SnackBar` kullanan bir yer kalırsa
  // da köşeler butonlarla ([AppRadius.primary]) hizalı kalsın.
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.lightTileHigh,
    contentTextStyle: TextStyle(color: AppColors.lightTextPrimary),
    actionTextColor: AppColors.primaryDeep,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.primaryCircular),
  ),
);

//dark theme
ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: _fontFamily,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  dividerColor: AppColors.darkDivider,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primaryColor,
    // Vurgu zemini koyu temada da yeşil, üstündeki içerik de açık temadaki
    // gibi beyaz. Bir dönem sayfa zeminine (koyu) bağlıydı: yeşil butonun
    // parlamasını azaltıyordu ama yeşilin üstündeki her şeyi -- buton yazısı,
    // sohbet balonu, seçili filtre, onay kutusunun tiki -- siyaha çeviriyordu.
    onPrimary: AppColors.onAccent,
    secondary: AppColors.primaryDeep,
    onSecondary: AppColors.onAccent,
    surface: AppColors.darkBackground,
    onSurface: AppColors.darkTextPrimary,
    onSurfaceVariant: AppColors.darkTextSecondary,
    surfaceContainerLowest: AppColors.darkBackground,
    surfaceContainerLow: AppColors.darkSurfaceLow,
    surfaceContainer: AppColors.darkTile,
    surfaceContainerHigh: AppColors.darkTileHigh,
    surfaceContainerHighest: AppColors.darkSurfaceHighest,
    outline: AppColors.darkTextTertiary,
    outlineVariant: AppColors.darkDivider,
    error: AppColors.danger,
    onError: AppColors.onAccent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
    titleTextStyle: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: AppColors.darkTextPrimary,
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    shape: CircleBorder(),
    backgroundColor: AppColors.darkTileHigh,
    foregroundColor: AppColors.darkTextPrimary,
  ),
  textTheme: _textTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.darkTileHigh,
    contentTextStyle: TextStyle(color: AppColors.darkTextPrimary),
    actionTextColor: AppColors.primaryColor,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.primaryCircular),
  ),
);
