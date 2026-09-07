part of 'company_detail_page.dart';

abstract class CompanyDetailPagemodel extends State<CompanyDetailPage> {
  final CompanyService _companyService = CompanyService();
  final JobService _jobService = JobService();
  final ScrollController scrollController = ScrollController();

  /// Şirket. Yüklenene kadar `null`.
  Company? company;

  bool isLoading = true;
  String? errorMessage;

  /// Takip isteği sunucuya gitti mi; buton kilitleniyor.
  bool isTogglingFollow = false;

  double _scrollOffset = 0.0;
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
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = scrollController.offset;
    });
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
        companyJobsFuture = _loadCompanyJobs(fetched.name);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Şirketin ilanları.
  ///
  /// TODO(backend): Şirkete göre süzen bir uç yok — `GET /jobs` şirket
  /// kimliği almıyor — o yüzden arama sonucu şirket **adına** göre eleniyor.
  /// Aynı adı taşıyan iki şirket varsa ilanları karışır.
  Future<List<Job>> _loadCompanyJobs(String companyName) async {
    final allJobs = (await _jobService.search(const JobSearchQuery())).jobs;
    return allJobs.where((job) => job.company == companyName).toList();
  }

  /// Appbar toplanırken başlığın belirme oranı.
  ///
  /// Kapak alanı `kToolbarHeight`e inince başlık görünmeye başlar ve
  /// [_titleFadeDistance] piksel içinde tamamen belirir.
  double get titleOpacity {
    final collapseStart =
        CompanyDetailPage.appBarExpandedHeight - kToolbarHeight;
    return ((_scrollOffset - collapseStart) / _titleFadeDistance).clamp(
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
      if (!mounted) return;
      AppToast.success(
        context,
        willFollow
            ? '${current.name} takip ediliyor'
            : '${current.name} takipten çıkarıldı',
      );
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

  /// TODO(backend): Şirketle doğrudan sohbetin karşılığı yok. Sunucuda bir
  /// konuşma daima bir ilana bağlı (`POST /jobs/{jobId}/conversation`) ve
  /// arada başvuru şartı var; şirket düzeyinde ayrı bir konuşma türü gerekiyor.
  /// Buton yerinde duruyor, uç gelene kadar durumu açıklıyor.
  void openChat() {
    AppToast.info(
      context,
      'Şirketle doğrudan mesajlaşma henüz açık değil. '
      'İlana başvurduğunda sohbet açılıyor.',
    );
  }
}
