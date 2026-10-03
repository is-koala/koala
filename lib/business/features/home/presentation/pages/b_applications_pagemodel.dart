part of 'b_applications_page.dart';

/// Süzgeç seçicisinin satırı; `id` boşsa "Tüm ilanlar".
typedef _JobChoice = ({String? id, String title});

abstract class BApplicationsPagemodel extends State<BApplicationsPage> {
  /// Listenin sonuna bu kadar kala sonraki sayfa isteniyor.
  static const double _loadMoreThreshold = 240;

  /// Süzgeç çipleri: "Tümü" ayrıca çiziliyor, `unknown` hiç yok — sunucu
  /// bilinmeyen durum değerine `400` veriyor.
  static const List<ApplicationStatus> _filterStatuses = [
    ApplicationStatus.applied,
    ApplicationStatus.accepted,
    ApplicationStatus.rejected,
    ApplicationStatus.withdrawn,
  ];

  /// Sayfanın kendi örneği: uygulama boyunca yaşayan provider yok, çıkışta
  /// temizlenecek bir şey kalmıyor ([BApplicationInboxProvider]).
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

  /// Çekip yenileme. Eldeki satırlar varken başarısız olursa liste yerinde
  /// kalıyor ve nedenini bir toast söylüyor; boş ekranda hata durumu zaten
  /// kendi mesajını çiziyor.
  Future<void> _onRefresh() async {
    final hadItems = _inbox.items.isNotEmpty;
    final ok = await _inbox.refresh();
    if (ok || !hadItems || !mounted) return;
    AppToast.error(context, _inbox.errorMessage ?? 'Başvurular yenilenemedi.');
  }

  /// Süzgeç seçicisinin ilanları: işverenin kendi açtığı ilanlar (uygulama
  /// bunları zaten bellekte tutuyor) ve listede şimdiye dek görünenler.
  /// Sunucuda "ilanlarım" ucu yalnız **kendi açtığını** verdiği için başka bir
  /// yetkilinin açtığı şirket ilanı ancak bir satırda göründüğünde seçilebilir.
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
    // "Tüm ilanlar" da bir seçim: `null` dönmek vazgeçmek demek, o yüzden
    // seçenek `null` değil bir kayıt.
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

  /// Kartın kendisi: başvurunun geldiği ilanın karar ekranı. Karar orada
  /// veriliyor, dönünce satırın durumu bayat kalmasın diye liste tazeleniyor
  /// (eldeki derinlik korunarak). Yenileme başarısız olursa çekip yenilemeyle
  /// aynı yoldan söyleniyor ([_onRefresh]): kullanıcı bayat durumu güncel
  /// sanmasın.
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
