part of 'my_jobs_page.dart';

abstract class MyJobsPagemodel extends State<MyJobsPage> {
  final MyJobsService _repository = MyJobsService();
  final CompanyService _companyService = CompanyService();

  /// Geçmiş bölümü varsayılan olarak kısaltılmış; kullanıcı isterse açıyor.
  bool showAllPastJobs = false;

  List<MyJob> allJobs = [];
  bool loading = true;

  /// Geçmiş bölümünde kısaltılmışken gösterilen iş sayısı.
  static const int collapsedPastJobCount = 2;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final jobs = await _repository.getMyJobs();
    if (!mounted) return;
    setState(() {
      allJobs = jobs;
      loading = false;
    });
  }

  /// Bir duruma ait işleri döndürür.
  ///
  /// [extraJobs] bu oturumda yapılan başvurular: henüz sahte repository'ye
  /// yazılmadıkları için listeye ayrıca ekleniyorlar.
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
