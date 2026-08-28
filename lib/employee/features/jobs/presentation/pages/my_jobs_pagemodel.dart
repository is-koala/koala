part of 'my_jobs_page.dart';

abstract class MyJobsPagemodel extends State<MyJobsPage> {
  final JobApplicationService _service = JobApplicationService();
  final CompanyService _companyService = CompanyService();

  /// Geçmiş bölümü varsayılan olarak kısaltılmış; kullanıcı isterse açıyor.
  bool showAllPastJobs = false;

  List<MyJob> allJobs = [];
  bool loading = true;

  /// Atamalar çekilemediyse gösterilecek mesaj.
  String? errorMessage;

  /// Geçmiş bölümünde kısaltılmışken gösterilen iş sayısı.
  static const int collapsedPastJobCount = 2;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    // Başvurular ayrı bir uçtan geliyor; sekmeye her girişte tekrar
    // çekilmesin diye provider ilk çağrıdan sonra ağa çıkmıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ApplyProvider>().load();
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
      final page = await _service.fetchMyAssignments();
      if (!mounted) return;
      setState(() {
        allJobs = page.assignments
            .map(MyJob.fromAssignment)
            .whereType<MyJob>()
            .toList(growable: false);
      });
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

  /// Şirket detayına gider. Önce id ile, bulunamazsa adla aranıyor —
  /// sahte veride her işin şirket id'si yok.
  Future<void> navigateToCompany(MyJob job) async {
    Company? company;

    if (job.companyId != null) {
      company = await _companyService.getCompanyById(job.companyId!);
    }

    if (!mounted) return;

    company ??= await _companyService.getCompanyByName(job.company);

    if (company != null && mounted) {
      context.push('/company-detail', extra: company);
    }
  }
}
