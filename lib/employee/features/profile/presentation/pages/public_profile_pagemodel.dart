part of 'public_profile_page.dart';

abstract class PublicProfilePagemodel extends State<PublicProfilePage> {
  UserService get _userService => widget.userService ?? UserService();

  JobService get _jobService => widget.jobService ?? JobService();

  /// Sunucudaki profil; gelene kadar `null`.
  PublicProfile? profile;

  bool isLoading = true;

  /// Profil çekilemediyse sebebi. Ekranda sebep değil yalnız *kesin mi,
  /// geçici mi* ayrımı kullanılıyor ([isRefused]).
  ApiException? failure;

  /// Kişinin temsil ettiği şirket; çözülene kadar ya da yoksa `null`.
  JobCompany? company;

  /// Kendi profili açıldı, profil sekmesine yönleniyor.
  bool isRedirecting = false;

  /// Sunucu bu profili vermiyor: yok/silinmiş (`404`) ya da — savunmacı
  /// olarak, bugün üretilmiyor — görme yetkisi yok (`403`). İkisi aynı ekranı
  /// çiziyor ve tekrar denemek bir şey değiştirmiyor.
  bool get isRefused {
    final type = failure?.type;
    return type == ApiErrorType.notFound || type == ApiErrorType.forbidden;
  }

  /// Puan özeti profil yanıtından; yanıt `reviewCount` **ve** `averageRating`
  /// taşımıyorsa (eski sunucu, yarım yanıt) `null` ve `ProfileReviews` özeti
  /// kendi ucundan çekiyor. Yarım özet "0.0" çizdirirdi.
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

  /// Kapaktaki ad: sunucunun söylediği, yoksa çağıranın verdiği.
  String get displayName {
    final fromProfile = profile?.fullName;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return widget.args.name ?? '';
  }

  /// Profil geldiyse fotoğrafın tek kaynağı o: kişi fotoğrafını kaldırdıysa
  /// çağıranın elindeki eski bağlantı geri gelmiyor.
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

  /// Kişi bir şirketi temsil edebiliyorsa (işveren ya da şirket yetkilisi)
  /// ve sohbetin ilanı biliniyorsa şirketi o ilanın detayından çözer.
  ///
  /// Ne profil yanıtında ne katılımcı satırında şirket var; tek kaynak ilan
  /// detayı (`company{id,name}`). Yalnız **şirket ilanında** satır çiziliyor.
  /// Profil geldikten sonra isteniyor ve sessiz başarısız oluyor: şirket
  /// satırı profilin tamamlayıcısı, ön koşulu değil.
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
