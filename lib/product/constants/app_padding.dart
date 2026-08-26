import 'package:flutter/material.dart';

/// `EdgeInsets` sabitleri.
///
/// Padding değerleri widget'ın içine yazılmaz; buradan okunur. İhtiyacın olan
/// boşluk yoksa anlamlı bir isimle ekle ve **neden** o değer olduğunu yaz.
final class AppPadding {
  /// Sayfaların kenar boşluğu. Uygulamadaki bütün ana içerik bu değerde
  /// hizalanır; değiştirilirse her sayfa birlikte kayar.
  static const double primary = 16.0;

  static const zero = EdgeInsets.zero;

  static const primaryAll = EdgeInsets.all(primary);
  static const primaryVertical = EdgeInsets.symmetric(vertical: primary);
  static const primaryHorizontal = EdgeInsets.symmetric(horizontal: primary);

  /// Sayfanın yalnızca bir kenarına ana boşluk gerektiğinde.
  static const primaryTop = EdgeInsets.only(top: primary);
  static const primaryBottom = EdgeInsets.only(bottom: primary);
  static const primaryLeft = EdgeInsets.only(left: primary);
  static const primaryRight = EdgeInsets.only(right: primary);

  // -------------------------------------------------------------- Kart / tile

  /// Kart ve bilgi kutularının iç boşluğu.
  static const card = EdgeInsets.all(12);

  /// Liste satırının iç boşluğu. Satır yüksekliğini metin değil soldaki
  /// görsel/avatar belirlediği için dikeyde dar.
  static const tile = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  /// Görseli olmayan, yüksekliğini metnin belirlediği satır ([tile] kadar
  /// daraltılırsa sıkışık görünüyor).
  static const infoTile = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  /// Kendi çerçevesi olan, tek başına duran satır (menü tile'ı). Çerçeve
  /// metne yapışmasın diye [infoTile]'dan bir tık ferah.
  static const tileTall = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// Textfield'ın iç boşluğu. Yatayda ana boşlukla, dikeyde alanın
  /// [AppSizes.fieldHeight] yüksekliğini dolduracak şekilde hizalı.
  static const field = EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0);

  /// Rozet ve etiketlerin (chip) iç boşluğu.
  static const chip = EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  /// Küçük durum rozeti; [chip]'ten dar, tek kelimelik metin taşıyor.
  static const badge = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  // ----------------------------------------------------------------- Buton

  /// Ana boşluktan dar yatay boşluk; buton çubuğunun içindeki butonun
  /// çubuğun kendi boşluğuna ikinci kez eklenmemesi için.
  static const horizontalSmall = EdgeInsets.symmetric(horizontal: 12);

  /// Ana butonların iç boşluğu.
  static const button = EdgeInsets.all(12);

  /// İkon butonların iç boşluğu; dokunma alanını 48px'e tamamlıyor.
  static const iconButton = EdgeInsets.all(8);

  // ---------------------------------------------------------------- Navbar

  /// Employee tarafındaki yüzen navbar'ın ekran kenarlarına uzaklığı.
  /// Yanlardaki 36, hap'ın ekran genişliğinden belirgin biçimde dar kalması
  /// için ana boşluktan geniş.
  static const EdgeInsets bottomNavBarPadding = EdgeInsets.only(
    bottom: 30,
    left: 36,
    right: 36,
  );

  /// Yüzen navbar'ın kendi iç boşluğu.
  static const navBarContent = EdgeInsets.all(10);

  /// Sayfanın altına sabitlenen buton çubuğunun boşluğu. Alt güvenli alan
  /// payını çubuk çalışma zamanında ekliyor, o yüzden burada alt değer
  /// güvenli alanın *üstüne* binen paydan ibaret.
  static const bottomBar = EdgeInsets.fromLTRB(16, 12, 16, 12);

  /// Business navbar'ının yatay boşluğu. Alt güvenli alan payını `BShellPage`
  /// çalışma zamanında ekliyor, o yüzden burada dikey değer yok.
  static const bNavBarPadding = EdgeInsets.symmetric(horizontal: 8);

  // --------------------------------------------------------------- Sayfalar

  /// Auth sayfalarının içeriği. Üstte boşluk yok: başlık appbar'ın hemen
  /// altından başlıyor.
  static const authContent = EdgeInsets.only(left: 16, right: 16, bottom: 16);

  /// Kayıt tipi seçim sayfasının içeriği; iki büyük kart taşıdığı için
  /// [authContent]'ten geniş.
  static const authContentWide = EdgeInsets.only(
    left: 28,
    right: 28,
    bottom: 16,
  );

  /// Auth sayfalarının en altındaki "hesabın var mı?" satırı.
  static const authFooter = EdgeInsets.only(bottom: 40, left: 12, right: 12);

  /// Kayıt tipi seçim kartının iç boşluğu; içindeki görsel kartın kenarına
  /// yapışmasın diye [card]'dan geniş.
  static const selectionCard = EdgeInsets.all(14);

  /// Bottom sheet'in iç boşluğu. Alt güvenli alan payı çalışma zamanında
  /// ayrıca ekleniyor.
  static const sheet = EdgeInsets.all(20);

  /// Bölüm başlığının boşluğu; üstündeki içerikten ayrılsın diye tepesi geniş.
  static const sectionHeader = EdgeInsets.only(top: 24, bottom: 8);

  /// Sohbet balonunun iç boşluğu.
  static const messageBubble = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );
}
