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

  /// Son yorum sayısı. Profil bir değerlendirme sayfası değil; tamamı için
  /// ayrı bir ekran gerekir.
  static const int _visibleReviewCount = 3;

  BCandidateProfileService get _profileService =>
      widget.profileService ?? BCandidateProfileService();

  AvailabilityService get _availabilityService =>
      widget.availabilityService ?? AvailabilityService();

  ReviewService get _reviewService => widget.reviewService ?? ReviewService();

  /// Adayın herkese açık profili. Başvuru kaydında olmayan alanlar —
  /// meslek, hakkında, konum, özgeçmiş — buradan geliyor.
  PublicProfile? _profile;

  /// Profil yanıtındaki özet alanlar (tamamlanan iş, puan, rozet). Sunucu
  /// göndermiyorsa boş kalıyor; puan ve rozet için asıl kaynak ayrı uçlar.
  BCandidateProfile? _candidate;
  bool _isLoading = true;
  String? _errorMessage;

  /// İtibar bölümü: puan özeti, son yorumlar ve rozetler. Üç uç birbirinden
  /// bağımsız; biri düşünce diğerleri yine çiziliyor.
  RatingSummary? _ratingSummary;
  List<Review> _reviews = const [];
  List<BBadge>? _badges;
  bool _isReputationLoading = true;
  String? _reputationErrorMessage;

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
    _loadReputation();
  }

  /// Puan özeti, son yorumlar ve rozetler; üçü paralel.
  ///
  /// Uçların biri düşerse eldekiler çiziliyor, düşen için profil yanıtındaki
  /// kopya (`PublicProfileDto.averageRating/reviewCount/badges`) yedek; o da
  /// yoksa şerit ve tekrar deneme. Yorumların profil yanıtında karşılığı yok.
  Future<void> _loadReputation() async {
    setState(() {
      _isReputationLoading = true;
      _reputationErrorMessage = null;
    });

    final userId = _profileUserId;
    final (summaryResult, reviewsResult, badgesResult) = await (
      _capture(_reviewService.fetchRatingSummary(userId)),
      _capture(
        _reviewService.fetchReviewsAbout(userId, size: _visibleReviewCount),
      ),
      _capture(_profileService.fetchBadges(userId)),
    ).wait;
    if (!mounted) return;

    setState(() {
      _ratingSummary = summaryResult.error == null
          ? summaryResult.value
          : _candidate?.ratingSummary;
      _reviews = reviewsResult.value?.reviews ?? const [];
      _badges = badgesResult.value ?? _candidate?.badges;
      _reputationErrorMessage =
          reviewsResult.error?.message ??
          (_ratingSummary == null ? summaryResult.error?.message : null) ??
          (_badges == null ? badgesResult.error?.message : null);
      _isReputationLoading = false;
    });
  }

  /// Puan özetinin son hâli: uçtan geldiyse o, gelmediyse profildeki kopya.
  RatingSummary? get _effectiveRatingSummary =>
      _ratingSummary ?? _candidate?.ratingSummary;

  List<BBadge>? get _effectiveBadges => _badges ?? _candidate?.badges;

  Future<_ReputationResult<T>> _capture<T>(Future<T> operation) async {
    try {
      return _ReputationResult.success(await operation);
    } on ApiException catch (error) {
      return _ReputationResult.failure(error);
    }
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isAvailabilityLoading = true;
      _availabilityErrorMessage = null;
    });

    try {
      final availability = await _availabilityService.fetchForUser(
        _profileUserId,
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
      final candidate = await _profileService.fetchProfile(_profileUserId);
      if (!mounted) return;
      setState(() {
        _candidate = candidate;
        _profile = candidate.profile;
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
  /// Havuzdan açılışta başvuru `cvUrl`'i yoktur; yalnız profildeki adres
  /// kullanılır, boş yer tutucu çizilmez.
  String? get _cvUrl {
    final fromApplication = widget.applicant?.cvUrl;
    if (fromApplication != null && fromApplication.isNotEmpty) {
      return fromApplication;
    }
    return _profile?.cvUrl;
  }

  /// Meslek: profil geldiyse oradan, gelmediyse başvurudakinden.
  String? get _jobTitle => _profile?.jobTitle ?? widget.applicant?.jobTitle;

  bool get _isFromApplication => widget.applicant != null;

  String get _profileUserId => widget.applicant?.user.id ?? widget.userId ?? '';

  String get _displayName =>
      _profile?.fullName ?? widget.applicant?.fullName ?? '';

  String? get _photoUrl =>
      _profile?.profilePictureUrl ?? widget.applicant?.profilePictureUrl;

  /// Havuzdan açılışta boş özgeçmiş kartı çizilmez.
  bool get _showsCvSection =>
      _isFromApplication || (_cvUrl?.isNotEmpty ?? false);

  JobCreator? get _poolWorker {
    final applicant = widget.applicant;
    if (applicant != null) return applicant.user;
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) return null;
    final profile = _profile;
    if (profile == null) {
      return JobCreator(id: userId, firstName: '', lastName: '');
    }
    return JobCreator(
      id: profile.id,
      firstName: profile.firstName,
      lastName: profile.lastName,
      username: profile.username,
      profilePictureUrl: profile.profilePictureUrl,
    );
  }

  /// Başlık çubuğundaki şikayet düğmesi.
  ///
  /// Kullanıcı kimliği gelmemiş bir başvuruda çizilmiyor: hedefsiz şikayet
  /// sunucudan `400` alırdı, basıldığında hata veren bir düğme göstermek
  /// yerine düğme hiç olmuyor.
  Widget? _reportAction() {
    final userId = _profileUserId;
    if (userId.isEmpty) return null;

    return IconButton(
      tooltip: 'Şikayet Et',
      icon: AppIcon(AppIcons.flag, color: context.textPrimary),
      onPressed: () => ReportSheet.show(
        context,
        ReportTarget.user(userId: userId, name: _displayName),
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
    final userId = _profileUserId;
    if (userId.isEmpty) return null;

    return IconButton(
      tooltip: 'Engelle',
      icon: const AppIcon(AppIcons.userBlock, color: AppColors.danger),
      onPressed: () => BlockUserAction.confirmAndBlock(
        context,
        userId: userId,
        name: _displayName,
      ),
    );
  }
}

class _ReputationResult<T> {
  const _ReputationResult.success(this.value) : error = null;

  const _ReputationResult.failure(this.error) : value = null;

  final T? value;
  final ApiException? error;
}
