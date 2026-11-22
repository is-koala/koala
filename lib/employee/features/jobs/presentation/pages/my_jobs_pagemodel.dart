part of 'my_jobs_page.dart';

abstract class MyJobsPagemodel extends WorkActionsPagemodel<MyJobsPage> {
  static const double _spinnerStroke = 2;

  @override
  AssignmentService get assignmentService =>
      widget.assignmentService ?? AssignmentService();

  @override
  ChatService get chatService => widget.chatService ?? ChatService();

  /// Eylem satırı başka bölüme taşıyor; tek satırı güncellemek yetmez.
  @override
  Future<void> refreshWork() => _loadJobs();

  bool showAllPastJobs = false;

  List<MyJob> allJobs = [];
  bool loading = true;

  String? errorMessage;

  static const int collapsedPastJobCount = 2;

  /// Süren işlerin açık oturumları; aynı anda tek süren iş olduğu için N+1
  /// değil. `null` "okundu, açık yok".
  final Map<String, WorkSession?> openSessions = {};

  /// Süre `now()` ile hesaplanıyor; çizilmezse donuk kalır. Dakikada bir yeter.
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ApplyProvider>().load();
      if (mounted) unawaited(initializeTimesheetQueue());
    });
  }

  /// Kabul edilmiş işler; bekleyen başvurular [ApplyProvider]'dan.
  Future<void> _loadJobs() async {
    setState(() {
      loading = allJobs.isEmpty;
      errorMessage = null;
    });

    try {
      final page = await assignmentService.fetchMyAssignments();
      if (!mounted) return;
      setState(() {
        allJobs = page.assignments
            .map(MyJob.fromAssignment)
            .toList(growable: false);
      });
      await _loadOpenSessions();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> reload() async {
    await _loadJobs();
    if (mounted) await context.read<ApplyProvider>().load(force: true);
  }

  @override
  void dispose() {
    disposeTimesheetQueue();
    _elapsedTicker?.cancel();
    super.dispose();
  }

  void _syncElapsedTicker() {
    final hasOpenSession = openSessions.values.any(
      (session) => session != null,
    );

    if (!hasOpenSession) {
      _elapsedTicker?.cancel();
      _elapsedTicker = null;
      return;
    }

    _elapsedTicker ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Çekilemezse satır "Giriş Yap" gösterir, sunucu gerekirse `409` ile
  /// düzeltir.
  Future<void> _loadOpenSessions() async {
    final ids = allJobs
        .where((job) => job.status == MyJobStatus.inProgress)
        .map((job) => job.assignmentId)
        .whereType<String>()
        .toList(growable: false);

    openSessions.removeWhere((id, _) => !ids.contains(id));

    for (final id in ids) {
      try {
        final sessions = await assignmentService.fetchWorkSessions(id);
        if (!mounted) return;
        openSessions[id] = sessions
            .where((session) => session.isOpen)
            .firstOrNull;
      } on ApiException {
        if (!mounted) return;
        openSessions.remove(id);
      }
    }

    if (!mounted) return;
    _syncElapsedTicker();
    setState(() {});
  }

  /// İki kaynak birleşir: başvurular ve atamalar; backend ayrı tutuyor.
  List<MyJob> jobsByStatus(
    MyJobStatus status, {
    List<MyJob> extraJobs = const [],
  }) => [
    ...extraJobs.where((job) => job.status == status),
    ...allJobs.where((job) => job.status == status),
  ];

  void togglePastJobs() {
    setState(() {
      showAllPastJobs = !showAllPastJobs;
    });
  }

  /// Detayda durum değişmiş olabilir; dönüşte liste tazelenir.
  Future<void> openDetail(MyJob job) async {
    await context.push('/work-detail', extra: job);
    if (mounted) await reload();
  }

  void navigateToCompany(MyJob job) {
    final companyId = job.companyId;
    if (companyId == null) return;

    context.push('/company-detail', extra: companyId);
  }
}
