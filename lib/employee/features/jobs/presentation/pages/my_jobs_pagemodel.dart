part of 'my_jobs_page.dart';

abstract class MyJobsPagemodel extends WorkActionsPagemodel<MyJobsPage> {
  /// Küçük buton göstergesi varsayılan kalınlıkta dolu görünmesin.
  static const double _spinnerStroke = 2;

  @override
  AssignmentService get assignmentService =>
      widget.assignmentService ?? AssignmentService();

  @override
  ChatService get chatService => widget.chatService ?? ChatService();

  /// Eylemler bütün listeyi tazeliyor: bir cevap ya da iptal satırı başka
  /// bir bölüme taşıyor, tek satırı yerinde güncellemek yetmez.
  @override
  Future<void> refreshWork() => _loadJobs();

  /// Geçmiş bölümü varsayılan olarak kısaltılmış; kullanıcı isterse açıyor.
  bool showAllPastJobs = false;

  List<MyJob> allJobs = [];
  bool loading = true;

  /// Atamalar çekilemediyse gösterilecek mesaj.
  String? errorMessage;

  /// Geçmiş bölümünde kısaltılmışken gösterilen iş sayısı.
  static const int collapsedPastJobCount = 2;

  /// Süren işlerin açık mesai oturumları; anahtar atama kimliği.
  ///
  /// Yalnızca `IN_PROGRESS` atamalar için çekiliyor: bir kişinin aynı anda
  /// süren birden fazla işi olmuyor, o yüzden bu N+1 değil. Değer `null`
  /// ise oturumlar okundu ve açık oturum yok demek.
  final Map<String, WorkSession?> openSessions = {};

  /// Açık mesai süresini işleten sayaç.
  ///
  /// Süre `WorkSession.elapsed` içinde `DateTime.now()` ile hesaplanıyor;
  /// yeniden çizilmezse ekranda donuk kalır ve çalışana yanlış süre gösterir.
  /// Dakikada bir yetiyor — süre zaten dakika hassasiyetinde yazılıyor.
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    // Başvurular ayrı bir uçtan geliyor; sekmeye her girişte tekrar
    // çekilmesin diye provider ilk çağrıdan sonra ağa çıkmıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ApplyProvider>().load();
      if (mounted) unawaited(initializeTimesheetQueue());
    });
  }

  /// Kabul edilmiş işleri çeker.
  ///
  /// Bekleyen başvurular buraya girmiyor; onlar ayrı bir uçtan gelip
  /// [ApplyProvider] üzerinden [jobsByStatus]'a ekleniyor.
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

  /// Sayfayı baştan yükler; hata ekranındaki "Tekrar Dene" buna bağlı.
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

  /// Açık oturum varken sayacı çalıştırır, kalmadığında durdurur.
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

  /// Süren işlerin açık mesai oturumlarını çeker.
  ///
  /// Oturum listesi çekilemezse ekran çökmüyor: açık oturum bilinmediğinde
  /// satır "Giriş Yap" gösteriyor ve sunucu gerekirse `409` ile düzeltiyor.
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

  /// Bir duruma ait işleri döndürür.
  ///
  /// İki kaynak birleşiyor: [extraJobs] bekleyen başvurular
  /// (`GET /users/me/applications`), [allJobs] ise kabul edilmiş işler
  /// (`GET /users/me/assignments`). Backend ikisini ayrı tuttuğu için
  /// birleştirme burada yapılıyor.
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

  /// Şirket detayına gider.
  ///
  /// TODO(backend): `MyAssignmentDto.job` şirket kimliği taşımıyor (yalnızca
  /// `companyId` bireysel ilanda boş kalır; satır o zaman tıklanmaz.
  void navigateToCompany(MyJob job) {
    final companyId = job.companyId;
    if (companyId == null) return;

    context.push('/company-detail', extra: companyId);
  }
}
