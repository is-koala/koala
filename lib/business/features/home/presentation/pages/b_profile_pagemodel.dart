part of 'b_profile_page.dart';

abstract class BProfilePageModel extends State<BProfilePage> {
  /// Kapaktaki şirket logosu ve çevresindeki beyaz halka.
  static const double _logoSize = 90;
  static const double _logoBorder = 3;

  /// Kapak üzerindeki ikincil metin ve rozet zeminlerinin opaklıkları.
  static const double _onCoverMuted = 0.9;
  static const double _onCoverSurface = 0.2;

  /// Navbar'ın altında kalmasın diye sayfanın sonuna eklenen pay; profilde
  /// liste değil tek sütun var, o yüzden standart paydan geniş.
  static const double _bottomClearance = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Kullanıcıyı, ardından şirketini ve istatistiklerini çeker.
  ///
  /// Sıra zorunlu: hangi şirketin isteneceği `/users/me` yanıtındaki üyelik
  /// listesinden çıkıyor.
  Future<void> _load({bool force = false}) async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    // Kimlik rozeti için inceleme durumu her açılışta ve yenilemede
    // tazeleniyor; kullanıcı yüklemesini bekletmiyor.
    unawaited(context.read<IdentityReviewProvider>().load(silent: true));
    if (userProvider.user == null || force) {
      await userProvider.load(silent: !force);
    }

    if (!mounted) return;
    final user = userProvider.user;
    if (user == null) return;

    await context.read<BCompanyProvider>().loadFor(user, force: force);
  }

  /// Ayarlara gider ve dönüşte veriyi tazeler: firma bilgileri orada
  /// düzenlenebiliyor.
  Future<void> _openSettings() async {
    await context.push('/business/settings');
    if (!mounted) return;
    await _load(force: true);
  }

  /// Adres ekranını açar. Kayıt `UserProvider`'ı zaten tazeliyor; dönüşte
  /// bu sayfa `watch` ettiği kullanıcıyla kendiliğinden yenileniyor.
  Future<void> _openAddress() => AccountNavigation.openAddress(context);
}
