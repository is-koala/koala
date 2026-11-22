/// İkon, bileşen ve boşluk ölçüleri. Yeni ölçüyü widget'a gömme; buraya anlamlı
/// bir adla ekle ve **neden** o değer olduğunu yaz.
class AppSizes {
  // ---------------------------------------------------------------- İkonlar

  static const double iconSmall = 16.0;

  /// Satırlardaki ikincil ikonlar (chevron, saat, konum).
  static const double iconMedium = 20.0;

  static const double icon = 24.0;

  static const double iconLarge = 40.0;

  static const double iconHuge = 64.0;

  // ------------------------------------------------------------- Bileşenler

  /// Ayırıcı satırları bölmeli, kendisi öğe gibi durmamalı.
  static const double divider = 1.0;

  /// Harita düğme hapının yüksekliği. Düğme kare ki basınca çıkan vurgu oval
  /// değil daire olsun.
  static const double mapPillHeight = 40.0;

  /// Pinler ekrandayken arka plandaki isteği kart açmadan gösteren çizgi.
  static const double refreshBar = 3.0;

  /// Liste satırındaki görsel; metinden yüksek ki satır boyunu hep görsel
  /// belirlesin.
  static const double thumbnail = 72.0;

  static const double avatar = 48.0;

  static const double avatarSmall = 40.0;

  static const double avatarLarge = 88.0;

  static const double iconCircle = 40.0;

  /// İçinde `icon` boyunda ikon ve iki yanında pay var.
  static const double iconTile = 44.0;

  static const double mapPin = 48.0;

  /// Buton ve form alanı aynı yükseklikte: alt alta eşit dursunlar.
  static const double buttonHeight = 60.0;
  static const double fieldHeight = 60.0;

  /// Sheet'in yüksekliği sınırlı olduğu için sayfa butonundan alçak.
  static const double buttonHeightCompact = 56.0;

  /// Kart içi ve alt çubuktaki eylem düğmeleri; tam boy [buttonHeight] kartta
  /// baskın kalıyor.
  static const double actionButtonHeight = 48.0;

  static const double filterButton = 40.0;

  /// Yanında etiket olmadığı için sayfa ikonlarından büyük.
  static const double iconNav = 28.0;

  /// Employee navbar'ı; sabit genişlik ekran boyundan bağımsız ikon aralığı
  /// veriyor.
  static const double navBar = 64.0;

  /// Tam opak geçiş sayfanın altına sert bir bant çiziyor.
  static const double navBarFadeMaxAlpha = 0.85;
  static const double navBarWidth = 250.0;

  /// İkon + etiket taşıdığı için employee navbar'ından yüksek.
  static const double bNavBar = 76.0;

  static const double badgeDot = 8.0;

  static const double sheetHandleWidth = 40.0;
  static const double sheetHandleHeight = 4.0;

  /// Sistemin klavye araç çubuğuyla aynı boy.
  static const double keyboardToolbar = 44.0;

  /// `EditableText` varsayılanı; "Bitti" şeridi varken şerit boyu eklenir.
  static const double caretScrollPadding = 20.0;

  // --------------------------------------------------------------- Boşluklar

  /// Etiket ile değeri tek blok gibi okunsun.
  static const double smallGap = 2.0;

  static const double spaceTiny = 4.0;

  static const double spaceSmall = 8.0;

  /// Form alanları ve kart içi bloklar arası.
  static const double space = 12.0;

  static const double spaceMedium = 16.0;

  static const double spaceLarge = 24.0;

  static const double spaceXLarge = 32.0;

  static const double sectionSpace = 40.0;

  static const double spaceHuge = 64.0;

  /// Yüzen navbar'ın altında kalmasın diye liste sonuna eklenen pay.
  static const double navBarClearance = 100.0;
}
