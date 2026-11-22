import 'package:material_ui/material_ui.dart';

/// `EdgeInsets` sabitleri. Gereken değer yoksa anlamlı bir adla ekle ve
/// **neden** o değer olduğunu yaz.
final class AppPadding {
  /// Sayfa kenar boşluğu; bütün ana içerik bununla hizalı.
  static const double primary = 16.0;

  static const zero = EdgeInsets.zero;

  static const primaryAll = EdgeInsets.all(primary);
  static const primaryVertical = EdgeInsets.symmetric(vertical: primary);
  static const primaryHorizontal = EdgeInsets.symmetric(horizontal: primary);

  static const primaryTop = EdgeInsets.only(top: primary);
  static const primaryBottom = EdgeInsets.only(bottom: primary);
  static const primaryLeft = EdgeInsets.only(left: primary);
  static const primaryRight = EdgeInsets.only(right: primary);

  // -------------------------------------------------------------- Kart / tile

  static const card = EdgeInsets.all(12);

  /// Satır yüksekliğini görsel belirlediği için dikeyde dar.
  static const tile = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  /// Görselsiz, yüksekliği metne bağlı satır; [tile] kadar dar sıkışık durur.
  static const infoTile = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  /// Kendi çerçevesi olan menü satırı; çerçeve metne yapışmasın.
  static const tileTall = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// Yatayda sayfa boşluğuyla, dikeyde [AppSizes.fieldHeight]'ı dolduracak
  /// şekilde.
  static const field = EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0);

  static const chip = EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  static const badge = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  // ----------------------------------------------------------------- Toast

  /// Kapsülün kavisi içeriği ittiği için yatayda geniş.
  static const toast = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

  static const toastMargin = EdgeInsets.all(primary);

  // ----------------------------------------------------------------- Buton

  /// Buton çubuğundaki butona çubuğun boşluğu ikinci kez eklenmesin.
  static const horizontalSmall = EdgeInsets.symmetric(horizontal: 12);

  static const button = EdgeInsets.all(12);

  /// Dokunma alanını 48px'e tamamlıyor.
  static const iconButton = EdgeInsets.all(8);

  // ---------------------------------------------------------------- Navbar

  /// Navbar genişliği sabit olduğu için yalnız alt boşluk; yatayda ortalanıyor.
  static const EdgeInsets bottomNavBarPadding = EdgeInsets.only(bottom: 30);

  /// Uçlardaki dairesel butonlar kapsülün kavisiyle eşmerkezli otursun diye her
  /// yön eşit.
  static const navBarContent = EdgeInsets.all(8);

  /// Alt güvenli alan payı çalışma zamanında ekleniyor.
  static const bottomBar = EdgeInsets.fromLTRB(16, 12, 16, 12);

  /// Alt güvenli alan payını `BShellPage` ekliyor.
  static const bNavBarPadding = EdgeInsets.symmetric(horizontal: 8);

  // --------------------------------------------------------------- Sayfalar

  /// Başlık appbar'ın hemen altından başladığı için üstte boşluk yok.
  static const authContent = EdgeInsets.only(left: 16, right: 16, bottom: 16);

  /// İki büyük kart taşıdığı için [authContent]'ten geniş.
  static const authContentWide = EdgeInsets.only(
    left: 28,
    right: 28,
    bottom: 16,
  );

  static const authFooter = EdgeInsets.only(bottom: 40, left: 12, right: 12);

  /// İçindeki görsel kenara yapışmasın diye [card]'dan geniş.
  static const selectionCard = EdgeInsets.all(14);

  /// Alt güvenli alan payı ayrıca ekleniyor.
  static const sheet = EdgeInsets.all(20);

  static const sectionHeader = EdgeInsets.only(top: 24, bottom: 8);

  static const messageBubble = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );
}
