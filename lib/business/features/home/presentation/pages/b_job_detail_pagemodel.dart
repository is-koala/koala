part of 'b_job_detail_page.dart';

abstract class BJobDetailPageModel extends State<BJobDetailPage>
    with WidgetsBindingObserver {
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

  /// Buton içindeki bekleme halkasının kalınlığı; varsayılan 4 bu boyutta
  /// dolu bir daire gibi görünüyor.
  static const double _spinnerStroke = 2;

  /// Onay kutusundaki çok satırlı gövdenin satır aralığı.
  static const double _dialogLineHeight = 1.4;

  JobService get _jobService => widget.jobService ?? JobService();

  EmployerJobService get _employerJobService =>
      widget.employerJobService ?? EmployerJobService();

  BPaymentService get _paymentService =>
      widget.paymentService ?? BPaymentService();

  BPaymentBrowser get _paymentBrowser =>
      widget.paymentBrowser ?? BPaymentBrowser();

  ChatService get _chatService => ChatService();

  /// Mesai oturumlarını iki taraf da okuyabiliyor; sohbette olduğu gibi tek
  /// servis iki uygulamaya hizmet ediyor.
  AssignmentService get _assignmentService =>
      widget.assignmentService ?? AssignmentService();

  /// İlanın tam hâli. Liste ucu açıklama/görev/adres döndürmediği için ekran
  /// açılırken `GET /jobs/{id}` ayrıca çağrılıyor.
  JobDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  /// Kabul/ret sırasında beklenen başvurunun kimliği; o kartın butonları
  /// kilitleniyor, diğerleri çalışmaya devam ediyor.
  String? _respondingApplicationId;

  /// Sohbet açılırken seçilen aday; aynı anda iki konuşma açılmasını önler.
  String? _openingChatUserId;

  /// Bu ilanın ataması; başvuru kabul edilmemişse `null`.
  Assignment? _assignment;

  /// Atamanın mesai oturumları, girişten çıkışa.
  List<WorkSession> _workSessions = const [];

  /// "İşi Tamamla" isteği sunucuya gitti mi.
  bool _isCompleting = false;

  bool _isStartingPayment = false;

  /// Bu atamanın ödeme girişimleri. Deneme listesi, atamanın kendisini veya
  /// mesai bölümünü kapatmadan ayrı hata durumuna düşer.
  List<BPaymentAttempt> _paymentAttempts = const [];
  bool _arePaymentAttemptsLoading = false;
  String? _paymentAttemptsError;

  /// Atamanın uyuşmazlıkları; kart üzerinde açık olan gösteriliyor.
  List<Dispute> _disputes = const [];

  /// İptal ya da uyuşmazlık isteği sunucuya gitti mi.
  bool _isRunningAssignmentAction = false;

  /// Şablon çıkarma isteği sunucuya gitti mi; düğme kilitleniyor.
  bool _isSavingTemplate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDetail();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // İlan listesi bu ekrana doğrudan bağlantıyla gelinmişse henüz
      // çekilmemiş olabilir; başvuranlar da yalnızca istendiğinde geliyor.
      final provider = context.read<BJobsProvider>();
      final companyProvider = context.read<BCompanyProvider>();
      final user = context.read<UserProvider>().user;
      await provider.load();
      if (!mounted) return;
      if (user != null) {
        await companyProvider.loadFor(user);
      }
      if (!mounted) return;
      await provider.ensureApplicants(widget.jobId);
      await _loadAssignment();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Hosted checkout'tan uygulamaya dönüldüğünde backend mutabakatının son
  /// atama ve deneme durumunu görünür kılar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadAssignment());
    }
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

  /// İlanın atamasını ve ona bağlı yardımcı kayıtları çeker.
  ///
  /// Bölüm ilanın ön koşulu değil: çekilemezse sessiz geçiliyor ve ekranın
  /// geri kalanı yerinde kalıyor. Ataması olmayan ilanda zaten hiç
  /// çizilmiyor.
  Future<void> _loadAssignment() async {
    try {
      final page = await _employerJobService.fetchMyAssignments();
      final match = page.assignments
          .where((assignment) => assignment.job.id == widget.jobId)
          .firstOrNull;

      if (!mounted) return;
      if (match == null) {
        setState(() {
          _assignment = null;
          _workSessions = const [];
          _disputes = const [];
          _paymentAttempts = const [];
          _paymentAttemptsError = null;
          _arePaymentAttemptsLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _assignment = match;
        _workSessions = const [];
        _disputes = const [];
        _paymentAttempts = const [];
        _paymentAttemptsError = null;
        _arePaymentAttemptsLoading = false;
      });

      await Future.wait([
        _loadWorkSessions(match.id),
        _loadDisputes(match.id),
        _loadPaymentAttempts(match.id),
      ]);
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _assignment = null;
        _workSessions = const [];
        _disputes = const [];
        _paymentAttempts = const [];
        _paymentAttemptsError = null;
        _arePaymentAttemptsLoading = false;
      });
    }
  }

  Future<void> _loadWorkSessions(String assignmentId) async {
    try {
      final sessions = await _assignmentService.fetchWorkSessions(assignmentId);
      if (mounted && _assignment?.id == assignmentId) {
        setState(() => _workSessions = sessions);
      }
    } on ApiException {
      // Mesai kaydı yardımcı bölümdür; ilanın kalanını kapatmaz.
    }
  }

  Future<void> _loadDisputes(String assignmentId) async {
    try {
      final disputes = await _assignmentService.fetchDisputes(assignmentId);
      if (mounted && _assignment?.id == assignmentId) {
        setState(() => _disputes = disputes);
      }
    } on ApiException {
      // Uyuşmazlık listesi yardımcı bölümdür; ilanın kalanını kapatmaz.
    }
  }

  Future<void> _loadPaymentAttempts([String? assignmentId]) async {
    if (!mounted) return;
    final id = assignmentId ?? _assignment?.id;
    if (id == null) return;

    setState(() {
      _arePaymentAttemptsLoading = true;
      _paymentAttemptsError = null;
    });

    try {
      final attempts = await _paymentService.fetchAttempts(id);
      if (!mounted || _assignment?.id != id) return;
      setState(() => _paymentAttempts = attempts);
    } on ApiException catch (error) {
      if (!mounted || _assignment?.id != id) return;
      setState(() => _paymentAttemptsError = error.message);
    } finally {
      if (mounted && _assignment?.id == id) {
        setState(() => _arePaymentAttemptsLoading = false);
      }
    }
  }

  /// Atamaya sabitlenmiş backend dökümünü gösterip açık onay alır.
  Future<void> _requestPayment() async {
    final assignment = _assignment;
    if (assignment == null || _isStartingPayment) return;

    final breakdown = assignment.pricing;
    if (breakdown == null) {
      AppToast.error(context, 'Atamanın fiyat dökümü alınamadı.');
      return;
    }

    setState(() => _isStartingPayment = true);
    try {
      final confirmed = await _confirmPayment(breakdown);
      if (confirmed != true || !mounted) return;

      await _startPayment(assignment);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isStartingPayment = false);
    }
  }

  /// Açık onaydan sonra Iyzico oturumunu başlatır.
  Future<void> _startPayment(Assignment assignment) async {
    final session = await _employerJobService.createPaymentSession(
      assignment.id,
    );
    final opened = await _paymentBrowser.open(session.paymentPageUrl);
    if (!opened) {
      throw const ApiException(
        message: 'Ödeme sayfası açılamadı.',
        type: ApiErrorType.unknown,
      );
    }
    if (mounted) {
      AppToast.success(
        context,
        'Ödemeyi tamamladıktan sonra Koala uygulamasına döneceksin.',
      );
    }
  }

  /// Fiyat dökümünü taşıyan ödeme onayı. Gövdesi arayüz dosyasında.
  Future<bool?> _confirmPayment(BPricingBreakdown breakdown);

  /// Atamayı iptal eder.
  ///
  /// Kutu açılmadan önce kesinti önizlemesi çekiliyor. İşverenin iptalinde
  /// kesinti kuralı çalışanınkinden farklı: cezasız pencere içinde yok,
  /// dışında geç iptal ücreti, iş başladıysa iade yok. Rakamı önden
  /// göstermek bu ekranın asıl işi — para kaybettiren bir karar bilmeden
  /// verilmemeli.
  ///
  /// Önizleme alınamazsa akış durmuyor; kutu kuralı kelimeyle anlatıyor.
  Future<void> _cancelAssignment() async {
    final assignment = _assignment;
    if (assignment == null || _isRunningAssignmentAction) return;

    setState(() => _isRunningAssignmentAction = true);
    CancellationPreview? preview;
    try {
      preview = await _assignmentService.fetchCancellationPreview(
        assignment.id,
      );
    } on ApiException {
      preview = null;
    } finally {
      if (mounted) setState(() => _isRunningAssignmentAction = false);
    }

    if (!mounted) return;

    if (preview != null && !preview.cancellableNow) {
      AppToast.error(context, 'Bu iş artık iptal edilemez');
      await _loadAssignment();
      return;
    }

    final reason = await ReasonDialog.show(
      context,
      title: 'İşi iptal et',
      description: _cancellationDescription(preview),
      fieldLabel: 'İptal gerekçen',
      confirmLabel: 'İptal Et',
    );

    if (reason == null || !mounted) return;

    await _runAssignmentAction((id) async {
      final cancellation = await _assignmentService.cancel(
        assignmentId: id,
        reason: reason,
      );
      return cancellation.hasFee
          ? 'İş iptal edildi · %${cancellation.feePercent} kesinti uygulandı'
          : 'İş iptal edildi, kesinti uygulanmadı';
    });
  }

  /// İptal kutusunun gövdesi.
  ///
  /// Tutar bağlayıcı değil: kesinti işin başlamasına kalan süreye bağlı ve
  /// kutu açıkken cezasız pencere kapanabilir. Sunucu iptalde yeniden
  /// hesaplıyor, metin de bunu söylüyor.
  String _cancellationDescription(CancellationPreview? preview) {
    const opening = 'İş iptal edilecek ve geri alınamayacak.';

    if (preview == null) {
      return '$opening\n\nİşin başlamasına yeterli süre varsa kesinti '
          'uygulanmaz; süre daraldıysa geç iptal ücreti kesilir, iş '
          'başladıysa iade yapılmaz. Uygulanan tutarı iptalden sonra '
          'göreceksin.';
    }

    if (!preview.hasFee) {
      return '$opening\n\nŞu an iptal edersen kesinti uygulanmaz, ücretin '
          'tamamı (₺${preview.refundAmount.toStringAsFixed(0)}) iade edilir. '
          'Tutar iptal anında yeniden hesaplanır.';
    }

    final started = preview.hasStarted
        ? ' İş başladığı için iade yapılmıyor.'
        : '';

    return '$opening\n\nŞu an iptal edersen %${preview.feePercent} kesinti '
        'uygulanır: ₺${preview.feeAmount.toStringAsFixed(0)} kesilir, '
        '₺${preview.refundAmount.toStringAsFixed(0)} iade edilir.$started '
        'Tutar iptal anında yeniden hesaplanır.';
  }

  /// Uyuşmazlık açar.
  ///
  /// Yalnızca para emanetteyken açılabiliyor ve emanetteki parayı donduruyor:
  /// çalışana ödeme yapılmıyor, sunucunun kendiliğinden tamamlaması duruyor.
  Future<void> _openDispute() async {
    final assignment = _assignment;
    if (assignment == null) return;

    final reason = await ReasonDialog.show(
      context,
      title: 'Sorun bildir',
      description:
          'Bu işle ilgili bir sorun bildireceksin. Emanetteki ücret, Koala '
          'konuyu inceleyip sonuçlandırana kadar dondurulur; çalışana ödeme '
          'yapılmaz ve iş kendiliğinden tamamlanmaz.',
      fieldLabel: 'Yaşadığın sorun',
      confirmLabel: 'Bildir',
      isDestructive: false,
    );

    if (reason == null || !mounted) return;

    await _runAssignmentAction((id) async {
      await _assignmentService.openDispute(assignmentId: id, reason: reason);
      return 'Sorun bildirildi, Koala inceleyecek';
    });
  }

  // ------------------------------------------------------------ Şablonlar

  /// Başlık çubuğundaki "Şablon olarak kaydet" düğmesi.
  ///
  /// İlan gelmeden çizilmiyor: şablon var olan bir ilandan çıkarıldığı için
  /// elde ilan yokken basılacak bir düğme göstermek anlamsız.
  Widget? _saveAsTemplateAction() {
    if (_detail == null) return null;

    return IconButton(
      tooltip: 'Şablon olarak kaydet',
      icon: AppIcon(AppIcons.fileText, color: context.textPrimary),
      onPressed: _isSavingTemplate ? null : _saveAsTemplate,
    );
  }

  /// İlanı şablon olarak kaydeder.
  ///
  /// Sunucu şablonu ilandan kendisi çıkarıyor; istemcinin gönderdiği tek şey
  /// ad ve ilanın kimliği. Ad zorunlu (`@NotBlank`), o yüzden alanı boşken
  /// onayı kapalı tutan [ReasonDialog] kullanılıyor — `ConfirmDialog`'un
  /// metin alanı yok.
  Future<void> _saveAsTemplate() async {
    if (_isSavingTemplate) return;

    final name = await ReasonDialog.show(
      context,
      title: 'Şablon olarak kaydet',
      description:
          'İlanın başlığı, kategorisi, ücreti ve gereksinimleri şablona '
          'kopyalanır. Adres ve tarih kopyalanmaz; sonraki ilanda yeniden '
          'girilir.',
      fieldLabel: 'Şablon adı',
      confirmLabel: 'Kaydet',
      // Yıkıcı bir işlem değil: kırmızı düğme yanlış sinyal verirdi.
      isDestructive: false,
    );

    if (name == null || !mounted) return;

    setState(() => _isSavingTemplate = true);

    final provider = context.read<BJobTemplatesProvider>();
    final created = await provider.createFromJob(
      jobId: widget.jobId,
      templateName: name,
    );

    if (!mounted) return;
    setState(() => _isSavingTemplate = false);

    if (created) {
      AppToast.success(
        context,
        'Şablon kaydedildi',
        actionLabel: 'Şablonlarım',
        // Toast sayfadan uzun yaşayabiliyor; ayrılmış bir sayfanın
        // context'iyle gezinmek hata verirdi.
        onAction: () {
          if (mounted) context.push('/business/job-templates');
        },
      );
    } else {
      AppToast.error(context, provider.errorMessage ?? 'Şablon kaydedilemedi');
    }
  }

  /// İptal ve uyuşmazlığın ortak gövdesi: kilit, hata ve tazeleme.
  Future<void> _runAssignmentAction(
    Future<String> Function(String assignmentId) action,
  ) async {
    final assignment = _assignment;
    if (assignment == null || _isRunningAssignmentAction) return;

    setState(() => _isRunningAssignmentAction = true);

    try {
      final message = await action(assignment.id);
      if (!mounted) return;
      AppToast.success(context, message);
      await _loadDetail();
      if (mounted) await _loadAssignment();
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      if (error.type == ApiErrorType.conflict) await _loadAssignment();
    } finally {
      if (mounted) setState(() => _isRunningAssignmentAction = false);
    }
  }

  /// İşi tamamlanmış işaretler.
  ///
  /// Geri alınamıyor: emanetteki para çıkışa hazır hâle geliyor. Bu yüzden
  /// önce onay soruluyor, hele ki çalışan hâlâ mesaideyken.
  Future<void> _completeAssignment() async {
    final assignment = _assignment;
    if (assignment == null || _isCompleting) return;

    final confirmed = await _confirmCompletion(assignment);
    if (confirmed != true || !mounted) return;

    setState(() => _isCompleting = true);

    try {
      await _employerJobService.completeAssignment(assignment.id);
      if (!mounted) return;
      AppToast.success(context, 'İş tamamlandı olarak işaretlendi');
      // Tamamlama ilanın durumunu da değiştiriyor.
      await _loadDetail();
      if (mounted) await _loadAssignment();
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      if (error.type == ApiErrorType.conflict) await _loadAssignment();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  /// Tamamlama onayı. Açık mesai varsa uyarı metni farklı.
  Future<bool?> _confirmCompletion(Assignment assignment);

  /// Başvuru kartından, seçilen adayla bu ilana bağlı sohbeti açar.
  ///
  /// Sunucu aynı ilan/çalışan çifti için mevcut konuşmayı döndürdüğünden bu
  /// buton güvenle tekrar kullanılabilir; kopya sohbet oluşmaz.
  Future<void> _openChat(JobApplicant applicant) async {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null || _openingChatUserId != null) return;

    setState(() => _openingChatUserId = applicant.user.id);
    try {
      final conversation = await _chatService.openConversationForJob(
        jobId: widget.jobId,
        currentUserId: currentUser.id,
        workerId: applicant.user.id,
      );
      if (!mounted) return;
      await context.push('/business/chat-detail', extra: conversation);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _openingChatUserId = null);
    }
  }

  /// Başvuruyu kabul eder.
  Future<void> _approve(JobApplicant applicant) async {
    await _respond(
      applicant,
      call: (provider) => provider.approveApplicant(
        jobId: widget.jobId,
        applicationId: applicant.id,
      ),
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
        jobId: widget.jobId,
        applicationId: applicant.id,
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
