part of 'company_detail_page.dart';

abstract class CompanyDetailPagemodel extends State<CompanyDetailPage> {
  final JobService _jobService = JobService();
  final ScrollController scrollController = ScrollController();

  bool isFollowing = false;
  double _scrollOffset = 0.0;
  late Future<List<Job>> companyJobsFuture;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    companyJobsFuture = _loadCompanyJobs();
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

  Future<List<Job>> _loadCompanyJobs() async {
    final allJobs = (await _jobService.search()).jobs;
    return allJobs.where((job) => job.company == widget.company.name).toList();
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

  void toggleFollow() {
    setState(() {
      isFollowing = !isFollowing;
    });

    // TODO(backend): Takip bilgisi gerçek servise yazılacak.
    AppToast.info(
      context,
      isFollowing
          ? '${widget.company.name} takip edildi'
          : '${widget.company.name} takipten çıkarıldı',
    );
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
