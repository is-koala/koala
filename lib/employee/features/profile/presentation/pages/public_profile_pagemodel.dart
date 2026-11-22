part of 'public_profile_page.dart';

abstract class PublicProfilePagemodel extends State<PublicProfilePage> {
  UserService get _userService => widget.userService ?? UserService();

  JobService get _jobService => widget.jobService ?? JobService();

  PublicProfile? profile;

  bool isLoading = true;

  /// Ekranda yalnız *kesin mi, geçici mi* ayrımı kullanılıyor ([isRefused]).
  ApiException? failure;

  JobCompany? company;

  bool isRedirecting = false;

  /// `404` ya da (bugün üretilmiyor) `403`; tekrar denemek bir şey değiştirmez.
  bool get isRefused {
    final type = failure?.type;
    return type == ApiErrorType.notFound || type == ApiErrorType.forbidden;
  }

  /// Yanıt `reviewCount` **ve** `averageRating` taşımıyorsa `null`, özet kendi
  /// ucundan gelir; yarım özet "0.0" çizdirirdi.
  RatingSummary? get ratingSummary {
    final loaded = profile;
    final count = loaded?.reviewCount;
    final average = loaded?.averageRating;
    if (loaded == null || count == null || average == null) return null;
    return RatingSummary(
      userId: loaded.id,
      reviewCount: count,
      averageRating: average,
    );
  }

  String get displayName {
    final fromProfile = profile?.fullName;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return widget.args.name ?? '';
  }

  /// Profil geldiyse tek kaynak o: kaldırılan fotoğrafın eski bağlantısı geri
  /// gelmesin.
  String? get photoUrl {
    final loaded = profile;
    return loaded == null ? widget.args.imageUrl : loaded.profilePictureUrl;
  }

  @override
  void initState() {
    super.initState();
    if (_isOwnProfile) {
      isRedirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(EmployeeRoutes.ownProfile);
      });
      return;
    }
    load();
  }

  bool get _isOwnProfile =>
      widget.args.userId == context.read<UserProvider>().user?.id;

  Future<void> load() async {
    setState(() {
      isLoading = true;
      failure = null;
    });

    try {
      final fetched = await _userService.fetchPublicProfile(widget.args.userId);
      if (!mounted) return;
      setState(() {
        profile = fetched;
        isLoading = false;
      });
      unawaited(_loadCompany());
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        failure = error;
        isLoading = false;
      });
    }
  }

  /// Kişi şirketi temsil edebiliyorsa şirketi sohbetin ilanından çözer; yalnız
  /// şirket ilanında. Sessiz başarısız olur: satır tamamlayıcı, ön koşul değil.
  Future<void> _loadCompany() async {
    final jobId = widget.args.companyLookupJobId;
    if (jobId == null) return;

    try {
      final job = await _jobService.getById(jobId);
      if (!mounted) return;
      final found = job.employerType == JobEmployerType.company
          ? job.company
          : null;
      if (found != null && found.name.isNotEmpty) {
        setState(() => company = found);
      }
    } on ApiException {
      // Satır yok; profilin geri kalanı yerinde.
    }
  }
}
