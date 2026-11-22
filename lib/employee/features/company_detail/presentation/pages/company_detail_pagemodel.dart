part of 'company_detail_page.dart';

abstract class CompanyDetailPagemodel extends State<CompanyDetailPage> {
  CompanyService get _companyService =>
      widget.companyService ?? CompanyService();
  JobService get _jobService => widget.jobService ?? JobService();
  final ScrollController scrollController = ScrollController();

  Company? company;

  bool isLoading = true;
  String? errorMessage;

  bool isTogglingFollow = false;

  bool showAllJobs = false;

  /// Kaydırma her karede değiştiriyor; yalnız başlık yeniden çizilsin diye
  /// `setState` değil dinlenebilir değer.
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

  /// Galeri, takipçi ve takip durumu aynı yanıtta.
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

  Future<List<Job>> _loadCompanyJobs(String companyId) =>
      _jobService.fetchByCompany(companyId);

  /// Kapak `kToolbarHeight`e inince başlık belirmeye başlar.
  double _opacityAt(double scrollOffset) {
    final collapseStart =
        CompanyDetailPage.appBarExpandedHeight - kToolbarHeight;
    return ((scrollOffset - collapseStart) / _titleFadeDistance).clamp(
      0.0,
      1.0,
    );
  }

  static const double _titleFadeDistance = 40;

  /// İyimser; uçlar idempotent. Başarısızsa eski hâle dönülür.
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
      // Başarıda toast yok: buton ve sayı zaten değişiyor.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => company = current);
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isTogglingFollow = false);
    }
  }

  void toggleShowAllJobs() => setState(() => showAllJobs = !showAllJobs);

  /// Açılamazsa kullanıcıya söylenir.
  Future<void> openExternal(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppToast.error(context, 'Bağlantı açılamadı');
    }
  }
}
