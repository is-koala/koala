import 'dart:math';
import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';

extension ScaffoldExtension on BuildContext {
  void openDrawer() => Scaffold.of(this).openDrawer();
  void closeDrawer() => Scaffold.of(this).closeDrawer();
}

extension ContextExtension on BuildContext {
  Container get randomContainer => Container(
    height: 100,
    width: double.infinity,
    margin: EdgeInsets.symmetric(vertical: 8.0),
    color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
  );

  Color get randomColor =>
      Colors.primaries[Random().nextInt(Colors.primaries.length)];
}

extension SizeExtension on BuildContext {
  Size get size => MediaQuery.sizeOf(this);

  EdgeInsets get padding => MediaQuery.paddingOf(this);

  double get height =>
      size.height - padding.bottom - padding.top - 56 /* appbar height*/;

  double get width => size.width;

  double dynamicHeight(double value) => height * value;

  double dynamicWidth(double value) => width * value;
}

extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;

  TextTheme get primaryTextTheme => Theme.of(this).primaryTextTheme;
}

/// Temaya göre değişen renkler.
///
/// Marka, durum ve yüzey renkleri (`primaryColor`, `success`, `scrim` ...)
/// [AppColors] içinde sabit kalır; zemin, metin ve ayraç gibi açık/koyu
/// temada farklılaşan her şey buradan okunur.
///
/// ```dart
/// // ❌ iki temadan birinde sessizce kırılır
/// color: Colors.white
/// color: Colors.grey[600]
///
/// // ✅
/// color: context.backgroundColor
/// color: context.textSecondary
/// ```
///
/// Buradan gelen renk derleme zamanı sabiti olmadığı için o widget `const`
/// olamaz; `const` anahtarını kaldır.
extension AppColorExtension on BuildContext {
  /// Sayfa zemini.
  Color get backgroundColor => theme.scaffoldBackgroundColor;

  /// Kart, tile ve bottom sheet zemini.
  Color get tileColor => colorScheme.surfaceContainer;

  /// Zeminden bir tık yükseltilmiş yüzey: buton, ikon dairesi, navbar.
  Color get elevatedColor => colorScheme.surfaceContainerHigh;

  /// Başlık ve gövde metni.
  Color get textPrimary => colorScheme.onSurface;

  /// Açıklama, etiket, ikincil metin.
  Color get textSecondary => colorScheme.onSurfaceVariant;

  /// En soluk metin ve ikonlar (satır sonundaki chevron gibi).
  Color get textTertiary => colorScheme.outline;

  /// Ayraç ve ince kenarlıklar.
  Color get dividerColor => theme.dividerColor;

  /// Vurgu rengi: marka yeşili.
  Color get accentColor => colorScheme.primary;

  /// Tema koyu mu.
  ///
  /// Renk seçmek için genelde gerekmez — [ColorScheme] zaten temaya göre
  /// dönüyor. Yalnızca açık ve koyu temada **yön değiştiren** durumlar için:
  /// bkz. [recessedColor] / [raisedColor].
  bool get isDarkTheme => theme.brightness == Brightness.dark;

  /// Üstünde kart taşıyan sayfaların zemini.
  ///
  /// Açık temada sayfa gri, kart beyaz; koyu temada sayfa en koyu, kart bir
  /// tık açık. Yani ton yönü iki tema arasında ters dönüyor ve tek bir
  /// [ColorScheme] rolüyle ifade edilemiyor. [raisedColor] ile birlikte
  /// kullanılır.
  Color get recessedColor =>
      isDarkTheme ? colorScheme.surface : colorScheme.surfaceContainer;

  /// [recessedColor] zemininin üstünde duran kartın rengi.
  Color get raisedColor =>
      isDarkTheme ? colorScheme.surfaceContainer : colorScheme.surface;

  /// "Başvurularım" bölümünün renkli zemini.
  Color get pendingSurface =>
      isDarkTheme ? AppColors.surfacePendingDark : AppColors.surfacePending;

  /// "Ödeme Bekleniyor" bölümünün renkli zemini.
  Color get payoutSurface =>
      isDarkTheme ? AppColors.surfacePayoutDark : AppColors.surfacePayout;

  /// "Onayını Bekleyen İşler" bölümünün renkli zemini.
  Color get awaitingSurface =>
      isDarkTheme ? AppColors.surfaceAwaitingDark : AppColors.surfaceAwaiting;

  /// "Devam Eden İş" bölümünün renkli zemini.
  Color get progressSurface =>
      isDarkTheme ? AppColors.surfaceProgressDark : AppColors.surfaceProgress;

  /// [accentColor] zemini üzerindeki metin ve ikon: iki temada da beyaz.
  ///
  /// Değer [AppColors.onAccent] ile aynı; ikisi arasındaki fark nereden
  /// okunduğu. Yeşil bir zeminin üstüne çizen widget bunu kullanır, böylece
  /// tema bir gün yön değiştirirse tek yerden döner. [AppColors.onAccent]
  /// ise temadan bağımsız olduğu baştan belli olan yüzeyler için (business
  /// navbar'ı, kapak görselinin üstü).
  ///
  /// Yeşilin **üstü** demek: yeşilin *yerine* duran ters butonun zemini
  /// buradan değil [backgroundColor]'dan gelir.
  Color get onAccentColor => colorScheme.onPrimary;
}

extension PaddingExtension on BuildContext {
  static const double _mainPadding = 0.054;
  static const double _mainPaddingLow = 0.048;
  static const double _mainPaddingLowest = 0.025;

  EdgeInsets get mainHorizontalPadding =>
      EdgeInsets.symmetric(horizontal: width * _mainPadding);

  EdgeInsets get mainHorizontalPaddingRight =>
      EdgeInsets.only(right: width * _mainPadding);
  EdgeInsets get mainHorizontalPaddingRightLow =>
      EdgeInsets.only(right: width * _mainPaddingLow);
  EdgeInsets get mainHorizontalPaddingRightLowest =>
      EdgeInsets.only(right: width * _mainPaddingLowest);

  EdgeInsets get mainHorizontalPaddingLeft =>
      EdgeInsets.only(left: width * _mainPadding);

  EdgeInsets get mainHorizontalPaddingLeftLowest =>
      EdgeInsets.only(left: width * _mainPaddingLowest);

  EdgeInsets get mainHorizontalPaddingLow =>
      EdgeInsets.symmetric(horizontal: width * _mainPaddingLow);

  EdgeInsets get mainHorizontalPaddingLowest =>
      EdgeInsets.symmetric(horizontal: width * _mainPaddingLowest);
}
