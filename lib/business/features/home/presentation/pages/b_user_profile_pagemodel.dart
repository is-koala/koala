part of 'b_user_profile_page.dart';

abstract class BUserProfilePageModel extends State<BUserProfilePage> {
  /// Kapaktaki profil fotoğrafı ve çevresindeki beyaz halka.
  static const double _avatarSize = 100;
  static const double _avatarBorder = 3;

  /// Bilgi satırındaki etiket sütununun genişliği; değerler hizalı dursun
  /// diye sabit.
  static const double _infoLabelWidth = 100;

  /// Kapaktaki gradyanın koyu ucu.
  static const double _gradientEndAlpha = 0.8;

  /// Kapak üzerindeki ikincil metin ve rozetlerin opaklıkları.
  static const double _onCoverMuted = 0.9;
  static const double _onCoverSurface = 0.2;

  /// Karşılığı henüz gelmemiş alanların yerine yazılan işaret.
  static const String _missing = '—';

  final _userService = UserService();
  final _availabilityService = AvailabilityService();

  /// Adayın herkese açık profili. Başvuru kaydında olmayan alanlar —
  /// meslek, hakkında, konum, özgeçmiş — buradan geliyor.
  PublicProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  Availability? _availability;
  bool _isAvailabilityLoading = true;
  String? _availabilityErrorMessage;

  /// Özgeçmiş açılırken beklenen kısa an; buton iki kez tetiklenmesin diye.
  bool _isOpeningCv = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isAvailabilityLoading = true;
      _availabilityErrorMessage = null;
    });

    try {
      final availability = await _availabilityService.fetchForUser(
        widget.applicant.user.id,
      );
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _isAvailabilityLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _availabilityErrorMessage = error.message;
        _isAvailabilityLoading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _userService.fetchPublicProfile(
        widget.applicant.user.id,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  /// Özgeçmişi tarayıcıda açar.
  ///
  /// Bağlantı doğrudan dosya değil: sunucu kimliği ve sahipliği doğrulayıp
  /// kısa ömürlü imzalı bir adrese yönlendiriyor. Uygulama içinde göstermek
  /// bir PDF görüntüleyici gerektirirdi; harici tarayıcı yeterli.
  Future<void> _openCv() async {
    final url = _cvUrl;
    if (url == null || _isOpeningCv) return;

    setState(() => _isOpeningCv = true);

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;
    setState(() => _isOpeningCv = false);

    if (!opened) {
      AppToast.error(context, 'Özgeçmiş açılamadı');
    }
  }

  /// Özgeçmişin adresi.
  ///
  /// İki kaynaktan da gelebiliyor: başvuru listesi (`JobApplicantDto.cvUrl`)
  /// ve profil ucu. İlki elde zaten var, o yüzden profil gelmeden de açılabilir.
  String? get _cvUrl {
    final fromApplication = widget.applicant.cvUrl;
    if (fromApplication != null && fromApplication.isNotEmpty) {
      return fromApplication;
    }
    return _profile?.cvUrl;
  }

  /// Meslek: profil geldiyse oradan, gelmediyse başvurudakinden.
  String? get _jobTitle => _profile?.jobTitle ?? widget.applicant.jobTitle;

  /// Başlık çubuğundaki şikayet düğmesi.
  ///
  /// Kullanıcı kimliği gelmemiş bir başvuruda çizilmiyor: hedefsiz şikayet
  /// sunucudan `400` alırdı, basıldığında hata veren bir düğme göstermek
  /// yerine düğme hiç olmuyor.
  Widget? _reportAction() {
    final userId = widget.applicant.user.id;
    if (userId.isEmpty) return null;

    return IconButton(
      tooltip: 'Şikayet Et',
      icon: AppIcon(AppIcons.flag, color: context.textPrimary),
      onPressed: () => ReportSheet.show(
        context,
        ReportTarget.user(userId: userId, name: widget.applicant.fullName),
      ),
    );
  }

  /// Başlık çubuğundaki engelleme düğmesi.
  ///
  /// Şikayet düğmesiyle aynı sebeple kimliksiz başvuruda çizilmiyor. İşveren
  /// burada hep bir **adayı** görüyor, kendini değil: kendini engelleme yolu
  /// açılmıyor.
  ///
  /// Şikayetten farklı olarak ekran kapanmıyor — sohbet değil profil, iş
  /// başvurusu duruyor ve işveren başvuruyu görmeye devam edebilmeli.
  Widget? _blockAction() {
    final userId = widget.applicant.user.id;
    if (userId.isEmpty) return null;

    return IconButton(
      tooltip: 'Engelle',
      icon: const AppIcon(AppIcons.userBlock, color: AppColors.danger),
      onPressed: () => BlockUserAction.confirmAndBlock(
        context,
        userId: userId,
        name: widget.applicant.fullName,
      ),
    );
  }
}
