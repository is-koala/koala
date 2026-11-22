part of 'b_applications_page.dart';

/// `id` boşsa "Tüm ilanlar".
typedef _JobChoice = ({String? id, String title});

abstract class BApplicationsPagemodel extends State<BApplicationsPage> {
  static const double _loadMoreThreshold = 240;

  /// `unknown` yok: sunucu bilinmeyen duruma `400` veriyor.
  static const List<ApplicationStatus> _filterStatuses = [
    ApplicationStatus.applied,
    ApplicationStatus.accepted,
    ApplicationStatus.rejected,
    ApplicationStatus.withdrawn,
  ];

  /// Sayfaya ait; uygulama boyunca yaşamıyor.
  late final BApplicationInboxProvider _inbox;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inbox = BApplicationInboxProvider(service: widget.service);
    _scrollController.addListener(_onScroll);
    unawaited(_inbox.load());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _inbox.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining <= _loadMoreThreshold) unawaited(_inbox.loadMore());
  }

  /// Eldeki satırlar varken başarısızlık toast'la söylenir; boş ekran kendi
  /// hatasını çizer.
  Future<void> _onRefresh() async {
    final hadItems = _inbox.items.isNotEmpty;
    final ok = await _inbox.refresh();
    if (ok || !hadItems || !mounted) return;
    AppToast.error(context, _inbox.errorMessage ?? 'Başvurular yenilenemedi.');
  }

  /// Seçicinin ilanları: kendi ilanları ve listede görünenler. Başka yetkilinin
  /// açtığı şirket ilanı ancak bir satırda görününce seçilebilir.
  List<_JobChoice> _knownJobs(List<BJobPost> ownPosts) {
    final jobs = <String, String>{
      for (final post in ownPosts) post.job.id: post.job.title,
      for (final application in _inbox.items)
        application.jobId: application.postingTitle,
    };
    return [
      for (final entry in jobs.entries) (id: entry.key, title: entry.value),
    ];
  }

  Future<void> _pickJob(List<BJobPost> ownPosts) async {
    const all = (id: null, title: 'Tüm ilanlar');
    final jobs = _knownJobs(ownPosts);
    // "Tüm ilanlar" da bir seçim; `null` vazgeçmek demek.
    final picked = await OptionSheet.show<_JobChoice>(
      context,
      title: 'İlana göre süz',
      options: [all, ...jobs],
      labelOf: (job) => job.title,
      selected: jobs.where((job) => job.id == _inbox.jobId).firstOrNull ?? all,
    );
    if (picked == null || !mounted) return;
    final id = picked.id;
    unawaited(id == null ? _inbox.clearJob() : _inbox.setJob(id, picked.title));
  }

  /// İlanın karar ekranını açar; dönünce liste derinlik korunarak tazelenir,
  /// başarısızsa söylenir ki bayat durum güncel sanılmasın.
  Future<void> _openReview(ReceivedApplication application) async {
    await context.push('/business/job-detail', extra: application.jobId);
    if (!mounted) return;
    unawaited(_onRefresh());
  }

  Future<void> _openProfile(ReceivedApplication application) {
    return context.push(
      BusinessRoutes.userProfile,
      extra: application.toJobApplicant(),
    );
  }
}
