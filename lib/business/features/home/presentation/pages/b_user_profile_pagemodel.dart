part of 'b_user_profile_page.dart';

abstract class BUserProfilePageModel extends State<BUserProfilePage> {
  static const double _infoLabelWidth = 100;

  static const String _missing = '—';

  /// Profil değerlendirme sayfası değil.
  static const int _visibleReviewCount = 3;

  BCandidateProfileService get _profileService =>
      widget.profileService ?? BCandidateProfileService();

  AvailabilityService get _availabilityService =>
      widget.availabilityService ?? AvailabilityService();

  ReviewService get _reviewService => widget.reviewService ?? ReviewService();

  PublicProfile? _profile;

  /// Sunucu göndermiyorsa boş; asıl kaynak ayrı uçlar.
  BCandidateProfile? _candidate;
  bool _isLoading = true;
  String? _errorMessage;

  /// İtibar uçlarının ham sonuçları; biri düşünce diğerleri çizilir. Görünen
  /// değerler bunlardan **türetiliyor** ki profil sonradan gelse de yedek kopya
  /// devreye girsin.
  LoadResult<RatingSummary?>? _ratingSummaryResult;
  LoadResult<ReviewPage>? _reviewsResult;
  LoadResult<List<UserBadge>>? _badgesResult;
  bool _isReputationLoading = true;

  Availability? _availability;
  bool _isAvailabilityLoading = true;
  String? _availabilityErrorMessage;

  bool _isOpeningCv = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAvailability();
    _loadReputation();
  }

  /// Puan, yorum ve rozet paralel. Düşen için profil yanıtındaki kopya yedek; o
  /// da yoksa şerit. Yorumların yedeği yok.
  Future<void> _loadReputation() async {
    setState(() => _isReputationLoading = true);

    final userId = _profileUserId;
    final (summaryResult, reviewsResult, badgesResult) = await (
      LoadResult.capture(_reviewService.fetchRatingSummary(userId)),
      LoadResult.capture(
        _reviewService.fetchReviewsAbout(userId, size: _visibleReviewCount),
      ),
      LoadResult.capture(_profileService.fetchBadges(userId)),
    ).wait;
    if (!mounted) return;

    setState(() {
      _ratingSummaryResult = summaryResult;
      _reviewsResult = reviewsResult;
      _badgesResult = badgesResult;
      _isReputationLoading = false;
    });
  }

  /// Uç başarılıysa onun değeri (boş olabilir), düştüyse profildeki kopya.
  RatingSummary? get _effectiveRatingSummary {
    final result = _ratingSummaryResult;
    if (result == null || result.failed) return _candidate?.ratingSummary;
    return result.value;
  }

  /// İkisi de yoksa `null` (bilinmiyor).
  List<UserBadge>? get _effectiveBadges =>
      _badgesResult?.value ?? _candidate?.badges;

  List<Review> get _reviews => _reviewsResult?.value?.reviews ?? const [];

  bool get _ratingSummaryFailed =>
      _ratingSummaryResult?.failed == true && _candidate?.ratingSummary == null;

  bool get _badgesFailed =>
      _badgesResult?.failed == true && _effectiveBadges == null;

  /// Yedeği olan hata şerit üretmez.
  String? get _reputationErrorMessage {
    final reviewsError = _reviewsResult?.error?.message;
    if (reviewsError != null) return reviewsError;
    if (_ratingSummaryFailed) return _ratingSummaryResult?.error?.message;
    if (_badgesFailed) return _badgesResult?.error?.message;
    return null;
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

  /// Sunucu sahipliği doğrulayıp kısa ömürlü adrese yönlendiriyor; harici
  /// tarayıcı yeterli.
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

  /// Başvurudaki adres hemen elde; havuzdan açılışta yalnız profildeki.
  String? get _cvUrl {
    final fromApplication = widget.applicant?.cvUrl;
    if (fromApplication != null && fromApplication.isNotEmpty) {
      return fromApplication;
    }
    return _profile?.cvUrl;
  }

  String? get _jobTitle => _profile?.jobTitle ?? widget.applicant?.jobTitle;

  bool get _isFromApplication => widget.applicant != null;

  String get _profileUserId => widget.applicant?.user.id ?? widget.userId ?? '';

  String get _displayName =>
      _profile?.fullName ?? widget.applicant?.fullName ?? '';

  String? get _photoUrl =>
      _profile?.profilePictureUrl ?? widget.applicant?.profilePictureUrl;

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

  /// Kimliksiz başvuruda çizilmez: hedefsiz şikayet `400` alırdı.
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

  /// Engelleme; kimliksiz başvuruda çizilmez. Ekran kapanmaz: işveren başvuruyu
  /// görmeye devam etmeli.
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
