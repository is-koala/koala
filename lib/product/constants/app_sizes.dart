/// İkon boyutları, bileşen ölçüleri ve dikey/yatay boşluk değerleri.
///
/// Bu dosyadaki değerler kodda en sık geçen ölçülerden türetildi; yeni bir
/// ölçüye ihtiyacın olursa sayıyı widget'a gömmek yerine buraya anlamlı bir
/// isimle ekle ve **neden** o değer olduğunu yaz.
class AppSizes {
  // ---------------------------------------------------------------- İkonlar

  /// Rozet, etiket ve satır içi küçük ikonlar.
  static const double iconSmall = 16.0;

  /// Liste satırlarındaki ikincil ikonlar (chevron, saat, konum).
  static const double iconMedium = 20.0;

  /// Varsayılan ikon boyutu: appbar, navbar ve buton ikonları.
  static const double icon = 24.0;

  /// Boş durum (empty state) ve başlık ikonları.
  static const double iconLarge = 40.0;

  /// Onboarding ve boş liste görsellerindeki dev ikon.
  static const double iconHuge = 64.0;

  // ------------------------------------------------------------- Bileşenler

  /// Liste satırındaki kare görsel (ilan kartı, sohbet satırı). Metin
  /// bloğundan kasıtlı olarak yüksek: satır yüksekliğini hep görsel
  /// belirlesin ve tüm satırlar eşit boyda kalsın.
  static const double thumbnail = 72.0;

  /// Sohbet listesi ve başvuran satırındaki avatar.
  static const double avatar = 48.0;

  /// Appbar'daki ve profil satırındaki küçük avatar.
  static const double avatarSmall = 40.0;

  /// Profil sayfasının başındaki büyük avatar.
  static const double avatarLarge = 88.0;

  /// Ayar ve bilgi satırlarındaki dolu renkli ikon dairesi.
  static const double iconCircle = 40.0;

  /// Harita üzerindeki iş pininin kenar uzunluğu.
  static const double mapPin = 48.0;

  /// Ana butonların ve form alanlarının yüksekliği. İkisi aynı: giriş
  /// ekranlarında alt alta dizildiklerinde eşit boyda durmaları gerekiyor.
  static const double buttonHeight = 60.0;
  static const double fieldHeight = 60.0;

  /// Bottom sheet içindeki eylem butonu; sayfa butonundan alçak çünkü
  /// sheet'in kendi yüksekliği sınırlı.
  static const double buttonHeightCompact = 56.0;

  /// Filtre çubuğundaki hap butonun yüksekliği.
  static const double filterButton = 40.0;

  /// Navbar ikonu; sayfa içi ikonlardan büyük çünkü tek başına duruyor,
  /// yanında etiket yok.
  static const double iconNav = 28.0;

  /// Employee navbar'ının yüksekliği ve yüzen hap (floating pill) genişliği.
  /// Sabit genişlik verilerek ekran boyutundan bağımsız tutarlı bir ikon
  /// aralığı ve görünüm sağlanır.
  static const double navBar = 64.0;
  static const double navBarWidth = 250.0;

  /// Business navbar'ının yüksekliği; employee'ninkinden yüksek çünkü
  /// öğeleri ikon + etiket olarak iki satır taşıyor.
  static const double bNavBar = 76.0;

  /// Okunmamış mesaj / bildirim rozeti.
  static const double badgeDot = 8.0;

  /// Bottom sheet'in üstündeki tutamaç.
  static const double sheetHandleWidth = 40.0;
  static const double sheetHandleHeight = 4.0;

  // --------------------------------------------------------------- Boşluklar

  /// Etiket ile hemen altındaki değeri arası; iki satır tek blok gibi
  /// okunsun diye en küçük boşluk.
  static const double smallGap = 2.0;

  /// İkon ile hemen yanındaki etiket arası.
  static const double spaceTiny = 4.0;

  /// Satır içi öğeler arası.
  static const double spaceSmall = 8.0;

  /// Varsayılan dikey boşluk; form alanları ve kart içi bloklar arası.
  static const double space = 12.0;

  /// Kartlar ve liste öğeleri arası.
  static const double spaceMedium = 16.0;

  /// İki bölüm arası (başlık bloğu ile içerik gibi).
  static const double spaceLarge = 24.0;

  /// Başlık bloğu ile onu izleyen içerik arası.
  static const double spaceXLarge = 32.0;

  /// Sayfa içindeki bağımsız bölümler arası.
  static const double sectionSpace = 40.0;

  /// Sayfanın en tepesindeki nefes payı (giriş ve onboarding ekranları).
  static const double spaceHuge = 64.0;

  /// Yüzen navbar'ın altında kalmasın diye listelerin sonuna eklenen pay.
  /// Navbar yüksekliği + kenar boşluğu + biraz nefes.
  static const double navBarClearance = 100.0;
}
