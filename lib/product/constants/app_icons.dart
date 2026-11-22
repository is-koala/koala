/// İkon adları; `AppIcon` `Reicon.outline` / `Reicon.filled`'dan çözer. Yeni ad
/// eklerken pakette olduğuna bak: `Reicon.outline.names`.
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

  /// Taşma menüsü (üç nokta).
  static const String more = 'more';

  // ────────────────────────────────────── Genel Eylemler & Yönler
  static const String arrowLeft = 'arrowLeft';
  static const String arrowRight = 'arrowRight';

  /// Uygulama dışına çıkan bağlantı (tarayıcı, harita, arama).
  static const String arrowUpRight = 'arrowRightUp';
  static const String check = 'check';
  static const String checkCircle = 'checkCircle';
  static const String cancelCircle = 'closeCircle';
  static const String tick = 'check';

  /// Tek seçimi temizleyen çarpı. `xmark` çevredeki ikonlarla aynı çizgi
  /// kalınlığında; [cancelCircle] daha ağır bir "iptal".
  static const String close = 'xmark';

  /// Altında liste açılacağını anlatan ok; gezinme için [arrowRight].
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

  static const String bank = 'bank';
  static const String calendar = 'calendar';

  static const String calendarTick = 'calendarTick';
  static const String clock = 'clock';
  static const String route = 'route';

  static const String bus = 'bus';

  static const String seat = 'armchair';

  static const String qr = 'qr';

  static const String scan = 'scanBarcode';

  static const String flashlight = 'flashlight';
  static const String flashlightOn = 'flashlightOn';

  static const String refresh = 'refresh';

  /// Haritayı cihaz konumuna götüren düğme; [location] pini "seçilen yer", bu
  /// "bulunduğunuz yer".
  static const String myLocation = 'gps';
  static const String sort = 'sort';

  /// Süzgeç; sıralamadan ayrı kavram olduğu için [sort]'la aynı değil.
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

  /// Filled ağırlığıyla kullanılıyor.
  static const String verified = 'verified';

  /// Şikayet; [shield] güvenlik bölümünün kendisi.
  static const String flag = 'flag';

  static const String share = 'share';

  static const String userBlock = 'userBlock';
  static const String building = 'building';

  static const String personalCard = 'personalcard';
  static const String paint = 'palette';
  static const String task = 'task';
  static const String dress = 'tshirt';

  static const String gallery = 'gallery';

  // ────────────────────────────────────── İş Kategorileri Pinler Filled
  // ağırlığı çizdiği için her adın Filled karşılığı olmalı.
  static const String camera = 'camera';
  static const String foodTray = 'foodTray';
  static const String pet = 'pet';
  static const String paintbrush = 'paintbrush';
  static const String coffee = 'coffee';

  static const String briefcase = 'briefcase';
}
