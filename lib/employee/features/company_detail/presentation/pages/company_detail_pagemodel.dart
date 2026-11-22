part of 'company_detail_page.dart';

abstract class CompanyDetailPagemodel extends State<CompanyDetailPage> {
  CompanyService get _companyService =>
      widget.companyService ?? CompanyService();
  JobService get _jobService => widget.jobService ?? JobService();
  final ScrollController scrollController = ScrollController();

  /// Şirket. Yüklenene kadar `null`.
  Company? company;

  bool isLoading = true;
  String? errorMessage;

  /// Takip isteği sunucuya gitti mi; buton kilitleniyor.
  bool isTogglingFollow = false;

  /// Açık ilanların tamamı mı gösteriliyor; kapalıyken ilk birkaçı.
  bool showAllJobs = false;

  /// Toplanmış appbar'daki başlığın opaklığı. Kaydırma her karede değişiyor;
  /// bütün sayfa yerine yalnız başlık yeniden çizilsin diye `setState`
  /// değil dinlenebilir değer.
  final ValueNotifier<double> titleOpacity = ValueNotifier(0);
  Future<List<Job>>? companyJobsFuture;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    load();
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    titleOpacity.dispose();
    super.dispose();
  }

  void _onScroll() {
    titleOpacity.value = _opacityAt(scrollController.offset);
  }

  /// Şirketi çeker. Galeri, takipçi sayısı ve takip durumu aynı yanıtta
  /// geldiği için tek istek yetiyor.
  Future<void> load() async {
    setState(() {
      isLoading = company == null;
      errorMessage = null;
    });

    try {
      final fetched = await _companyService.fetchCompany(widget.companyId);
      if (!mounted) return;
      setState(() {
        company = fetched;
        companyJobsFuture = _loadCompanyJobs(fetched.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Şirketin açık ilanlarını kimlik üzerinden, bütün sayfalardan getirir.
  Future<List<Job>> _loadCompanyJobs(String companyId) =>
      _jobService.fetchByCompany(companyId);

  /// Appbar toplanırken başlığın belirme oranı.
  ///
  /// Kapak alanı `kToolbarHeight`e inince başlık görünmeye başlar ve
  /// [_titleFadeDistance] piksel içinde tamamen belirir.
  double _opacityAt(double scrollOffset) {
    final collapseStart =
        CompanyDetailPage.appBarExpandedHeight - kToolbarHeight;
    return ((scrollOffset - collapseStart) / _titleFadeDistance).clamp(
      0.0,
      1.0,
    );
  }

  static const double _titleFadeDistance = 40;

  /// Takip eder ya da takibi bırakır.
  ///
  /// Buton hemen dönüyor, istek arkada gidiyor: iki uç da idempotent ve
  /// sonucu tahmin edilebilir. İstek başarısız olursa eski hâle dönülüyor.
  Future<void> toggleFollow() async {
    final current = company;
    if (current == null || isTogglingFollow) return;

    final willFollow = !current.isFollowing;

    setState(() {
      isTogglingFollow = true;
      company = current.copyWith(
        isFollowing: willFollow,
        followerCount: current.followerCount + (willFollow ? 1 : -1),
      );
    });

    try {
      willFollow
          ? await _companyService.follow(current.id)
          : await _companyService.unfollow(current.id);
      // Başarıda toast yok: butonun kendisi "Takip Ediliyor"a dönüyor ve
      // takipçi sayısı artıyor; aynı şeyi bir de mesajla söylemek gürültü.
    } on ApiException catch (error) {
      if (!mounted) return;
      // İstek düştü: iyimser güncelleme geri alınıyor, yoksa buton
      // sunucudakinin tersini gösterir.
      setState(() => company = current);
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isTogglingFollow = false);
    }
  }

  /// Bütün açık ilanları gösterir ya da ilk birkaçına döner.
  void toggleShowAllJobs() => setState(() => showAllJobs = !showAllJobs);

  /// E-posta, telefon, web sitesi ya da harita bağlantısını cihazın ilgili
  /// uygulamasında açar; açılamazsa kullanıcıya söyler.
  Future<void> openExternal(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppToast.error(context, 'Bağlantı açılamadı');
    }
  }
}
