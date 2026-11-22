part of 'b_profile_page.dart';

abstract class BProfilePageModel extends State<BProfilePage> {
  static const double _logoSize = 90;
  static const double _logoBorder = 3;

  static const double _onCoverMuted = 0.9;
  static const double _onCoverSurface = 0.2;

  /// Tek sütun olduğu için standart paydan geniş.
  static const double _bottomClearance = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Önce kullanıcı, sonra şirket ve istatistikler; şirket üyelikten çıkıyor.
  Future<void> _load({bool force = false}) async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    // Kimlik rozeti için; kullanıcı yüklemesini bekletmez.
    unawaited(context.read<IdentityReviewProvider>().load(silent: true));
    if (userProvider.user == null || force) {
      await userProvider.load(silent: !force);
    }

    if (!mounted) return;
    final user = userProvider.user;
    if (user == null) return;

    await context.read<BCompanyProvider>().loadFor(user, force: force);
  }

  /// Firma bilgileri ayarlarda değişebildiği için dönüşte tazeler.
  Future<void> _openSettings() async {
    await context.push('/business/settings');
    if (!mounted) return;
    await _load(force: true);
  }

  Future<void> _openAddress() => AccountNavigation.openAddress(context);
}
