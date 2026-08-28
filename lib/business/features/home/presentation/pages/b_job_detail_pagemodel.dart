part of 'b_job_detail_page.dart';

abstract class BJobDetailPageModel extends State<BJobDetailPage> {
  /// Rozet zeminlerinin opaklığı.
  static const double _tintAlpha = 0.12;

  /// Detay satırındaki etiket sütununun genişliği; değerler hizalı dursun
  /// diye sabit.
  static const double _detailLabelWidth = 80;

  /// Başvuran satırındaki avatar.
  static const double _applicantAvatar = 48;

  /// Geçmiş işi yapan kişinin avatarı; başvuranınkinden büyük çünkü tek
  /// başına duruyor.
  static const double _workerAvatar = 56;

  final _jobService = JobService();

  /// İlanın tam hâli. Liste ucu açıklama/görev/adres döndürmediği için ekran
  /// açılırken `GET /jobs/{id}` ayrıca çağrılıyor.
  JobDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  /// Kabul/ret sırasında beklenen başvurunun kimliği; o kartın butonları
  /// kilitleniyor, diğerleri çalışmaya devam ediyor.
  String? _respondingApplicationId;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Başvurular provider'da; ilan detayına doğrudan bağlantıyla
      // gelinmişse liste henüz çekilmemiş olabilir.
      if (mounted) context.read<BJobsProvider>().load();
    });
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _jobService.getById(widget.jobId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  /// Başvuruyu kabul eder.
  Future<void> _approve(JobApplicant applicant) async {
    await _respond(
      applicant,
      call: (provider) => provider.approveApplicant(applicant.id),
      successMessage: '${applicant.fullName} onaylandı',
    );
  }

  /// Reddetme gerekçesini sorup başvuruyu reddeder.
  Future<void> _reject(JobApplicant applicant) async {
    final reason = await _askRejectionReason(applicant);
    if (reason == null || !mounted) return;

    await _respond(
      applicant,
      call: (provider) => provider.rejectApplicant(
        applicant.id,
        reason: reason.isEmpty ? null : reason,
      ),
      successMessage: '${applicant.fullName} reddedildi',
      isDestructive: true,
    );
  }

  Future<void> _respond(
    JobApplicant applicant, {
    required Future<bool> Function(BJobsProvider) call,
    required String successMessage,
    bool isDestructive = false,
  }) async {
    if (_respondingApplicationId != null) return;
    setState(() => _respondingApplicationId = applicant.id);

    final provider = context.read<BJobsProvider>();
    final succeeded = await call(provider);

    if (!mounted) return;
    setState(() => _respondingApplicationId = null);

    if (succeeded) {
      // İlanın durumu da değişmiş olabilir (kabul atama açıyor); detay
      // yeniden çekiliyor.
      await _loadDetail();
      if (!mounted) return;
      isDestructive
          ? AppToast.error(context, successMessage)
          : AppToast.success(context, successMessage);
    } else {
      AppToast.error(context, provider.errorMessage ?? 'İşlem tamamlanamadı');
    }
  }

  /// Gerekçeyi soran kutu. İptal edilirse `null`, boş bırakılırsa boş metin
  /// dönüyor — ikisi farklı: boş metin "gerekçesiz reddet" demek.
  Future<String?> _askRejectionReason(JobApplicant applicant);
}
