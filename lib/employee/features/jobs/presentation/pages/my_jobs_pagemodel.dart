part of 'my_jobs_page.dart';

abstract class MyJobsPagemodel extends State<MyJobsPage> {
  final AssignmentService _service = AssignmentService();
  final CompanyService _companyService = CompanyService();

  /// Geçmiş bölümü varsayılan olarak kısaltılmış; kullanıcı isterse açıyor.
  bool showAllPastJobs = false;

  List<MyJob> allJobs = [];
  bool loading = true;

  /// Atamalar çekilemediyse gösterilecek mesaj.
  String? errorMessage;

  /// Geçmiş bölümünde kısaltılmışken gösterilen iş sayısı.
  static const int collapsedPastJobCount = 2;

  /// Cevabı sunucuya gitmiş atamanın id'si; iki butonu da kilitliyor.
  ///
  /// Tek bir alan yetiyor çünkü kullanıcı aynı anda tek bir atamaya cevap
  /// veriyor ve cevap dönene kadar liste tazelenmiyor.
  String? respondingAssignmentId;

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

  /// Atamayı kabul eder ya da reddeder.
  ///
  /// Cevap `JobAssignmentDto` dönüyor; ödeme alanlarını taşımadığı için
  /// listedeki kayıt cevaptan güncellenmiyor, atamalar yeniden çekiliyor.
  /// Reddedilen atama listeden tamamen düşüyor: [MyJob.fromAssignment]
  /// `REJECTED` için `null` döndürüyor.
  Future<void> respondToAssignment(MyJob job, {required bool accepted}) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || respondingAssignmentId != null) return;

    setState(() => respondingAssignmentId = assignmentId);

    try {
      await _service.respond(assignmentId: assignmentId, accepted: accepted);
      if (!mounted) return;
      AppToast.success(context, accepted ? 'İşi kabul ettin' : 'İşi reddettin');
      await _loadJobs();
    } on ApiException catch (error) {
      if (!mounted) return;
      // 409: atama bu durumdan çıkmış — başka bir cihazdan cevaplanmış ya da
      // işveren iptal etmiş olabilir. Mesaj sunucudan Türkçe geliyor, ama
      // liste eskimiş demektir; yenilemek doğru olanı gösteriyor.
      AppToast.error(context, error.message);
      if (error.type == ApiErrorType.conflict) await _loadJobs();
    } finally {
      if (mounted) setState(() => respondingAssignmentId = null);
    }
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
