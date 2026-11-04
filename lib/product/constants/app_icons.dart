/// Projede kullanılan ikon adları.
///
/// Değerler `AppIcon` widget'ına verilir; widget adı `Reicon.outline` veya
/// `Reicon.filled` ağırlığından çözer. Yeni ikon eklerken adın pakette
/// bulunduğundan emin ol: `Reicon.outline.names`.
abstract final class AppIcons {
  // ────────────────────────────────────── Navigasyon & Genel
  static const String home = 'home';
  static const String navigation = 'compass';
  static const String work = 'briefcase2';
  static const String chat = 'chatRoundLine';
  static const String bookmark = 'bookmark';
  static const String search = 'search';
  static const String searchList = 'filterSearch';
  static const String menu = 'menu';
  static const String menu2 = 'menu';
  static const String settings = 'gear';
  static const String notification = 'bell';
  static const String plus = 'plus';

  /// Taşma menüsü (üç nokta). Başlık çubuğunda tek başına duran eylemler
  /// yerine birden fazla eylemi bir menüde toplayan düğme.
  static const String more = 'more';

  // ────────────────────────────────────── Genel Eylemler & Yönler
  static const String arrowLeft = 'arrowLeft';
  static const String arrowRight = 'arrowRight';
  static const String check = 'check';
  static const String checkCircle = 'checkCircle';
  static const String cancelCircle = 'closeCircle';
  static const String tick = 'check';

  /// Tek bir seçimi temizleyen çarpı — süzgeç çipinin sağındaki gibi.
  /// Sette çıplak bir çarpı iki adla var: `x` dolu gövdeli, `xmark` ise
  /// çevredeki `chevronDown` ve `arrowLeft` ile aynı 1.5 kalınlıkta çizgi
  /// ailesinden, o yüzden bu seçildi. [cancelCircle] daireli olanı ve daha
  /// ağır bir "iptal" anlamı taşıyor.
  static const String close = 'xmark';

  /// "Dokun ve seç" alanının sağındaki ok. Bir yöne gitmeyi değil, altında bir
  /// liste açılacağını anlatıyor; [arrowRight] gezinme için duruyor.
  static const String chevronDown = 'chevronDown';

  // ────────────────────────────────────── Kullanıcı & Hesap
  static const String user = 'user';
  static const String userAdd = 'userAdd';
  static const String userCheck = 'userCheck';
  static const String userMultiple = 'users';

  // ────────────────────────────────────── Auth
  static const String eyeOpen = 'eye';
  static const String eyeClosed = 'eyeClosed';

  // ────────────────────────────────────── İş & Detay
  static const String location = 'location';
  static const String moneyBag = 'moneyBag';

  /// Banka hesabı; hakediş satırındaki maskeli IBAN.
  static const String bank = 'bank';
  static const String calendar = 'calendar';

  /// Bitiş tarihi; başlangıçtaki [calendar] ile aynı aileden, tikli.
  static const String calendarTick = 'calendarTick';
  static const String clock = 'clock';
  static const String route = 'route';

  /// Ulaşım planı: servis kartlarının ve "Ulaşım" başlığının ikonu
  /// (is-koala/koala#197).
  static const String bus = 'bus';

  /// Koltuk seçimi; servisin içindeki yer. `armchair` sette koltuğa en yakın
  /// biçim, `bus` ile karışmıyor.
  static const String seat = 'armchair';

  /// Haritayı cihazın bulunduğu yere götüren düğme. Nişangâh biçimi
  /// [location] pininden ayrışsın diye: pin "seçilen yer", bu "sizin
  /// olduğunuz yer".
  static const String myLocation = 'gps';
  static const String sort = 'sort';

  /// Süzgeç sheet'ini açan düğme. Sıralamadan ayrı bir kavram olduğu için
  /// [sort] ile aynı ikonu paylaşmıyor.
  static const String filter = 'filter';
  static const String transferV = 'transferV';
  static const String star = 'star';

  // ────────────────────────────────────── İletişim
  static const String mail = 'envelope';
  static const String call = 'phone';
  static const String message = 'message';
  static const String globe = 'globe';
  static const String antenna = 'signal';

  // ────────────────────────────────────── Dosya & Düzenleme
  static const String edit = 'edit';
  static const String file = 'file';
  static const String fileText = 'fileText';
  static const String attachment = 'paperclip';
  static const String download = 'download';
  static const String delete = 'trash';

  /// Panoya kopyalama; hakediş detayındaki sağlayıcı referansı.
  static const String copy = 'copy';

  // ────────────────────────────────────── Görünüm / Tema
  static const String sun = 'sun';
  static const String moon = 'moon';
  static const String mobile = 'mobile';

  // ────────────────────────────────────── Diğer
  static const String logout = 'logout';
  static const String alert = 'alertCircle';
  static const String info = 'infoCircle';
  static const String shield = 'shield';

  /// Şikayet eylemi. "İhbar et / işaretle" anlamı ikon setinde bu adla;
  /// [shield] güvenlik bölümünün kendisini, bu ise tek bir şikayeti
  /// anlatıyor.
  static const String flag = 'flag';

  /// Paylaş: ilanı sistemin paylaşım menüsüyle gönderir.
  static const String share = 'share';

  /// Kullanıcı engelleme. Sette yalın bir yasak işareti (`ban`) da var ama
  /// üstünde insan silüeti olan bu ad, engellenenin bir kişi olduğunu
  /// söylüyor.
  static const String userBlock = 'userBlock';
  static const String building = 'building';

  /// Pozisyon / unvan.
  static const String personalCard = 'personalcard';
  static const String paint = 'palette';
  static const String task = 'task';
  static const String dress = 'tshirt';

  /// Şirket galerisi: boş galeri durumu ve yüklenemeyen görselin yerine.
  static const String gallery = 'gallery';

  // ────────────────────────────────────── İş Kategorileri
  // Liste kartları ve harita pinleri aynı ikonu çiziyor; pinde Filled ağırlığı
  // kullanıldığı için her adın Filled karşılığı olmalı (job_marker_generator).
  static const String camera = 'camera';
  static const String foodTray = 'foodTray';
  static const String pet = 'pet';
  static const String paintbrush = 'paintbrush';
  static const String coffee = 'coffee';

  /// Uygulamanın tanımadığı kategori kodu için nötr ikon.
  static const String briefcase = 'briefcase';
}
