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

  /// Birden çok satıra sarabilen gövde metinlerinin satır aralığı: onay
  /// kutusunun açıklaması ve atama panelindeki zaman çizelgesi satırı.
  static const double _multilineHeight = 1.4;

  JobService get _jobService => widget.jobService ?? JobService();

  EmployerJobService get _employerJobService =>
      widget.employerJobService ?? EmployerJobService();

  BPaymentService get _paymentService =>
      widget.paymentService ?? BPaymentService();

  BPaymentBrowser get _paymentBrowser =>
      widget.paymentBrowser ?? BPaymentBrowser();

  ChatService get _chatService => widget.chatService ?? ChatService();

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

  /// Bu ilanın atamaları ve ekranda açıkça seçilmiş olanı.
  List<Assignment> _assignments = const [];
  Assignment? _assignment;

  /// Atama listesiyle ona bağlı iş takibi verisinin son yenileme durumu.
  ///
  /// Başarılı boş yanıt gerçek "atama yok" hâlidir. Hata ise mevcut güvenilir
  /// snapshot'ı korur ama bu doğruluk kapısını kapatır; para ve durum değiştiren
  /// eylemler eski veriyle çalışamaz.
  bool _hasLoadedAssignments = false;
  bool _isAssignmentLoading = false;
  String? _assignmentLoadError;
  String? _workSessionsError;
  int _assignmentLoadGeneration = 0;
  String? _pendingAssignmentId;

  String? get _assignmentSnapshotError =>
      _assignmentLoadError ?? _workSessionsError;

  bool get _isAssignmentListVerified =>
      _hasLoadedAssignments &&
      !_isAssignmentLoading &&
      _assignmentLoadError == null;

  bool get _isAssignmentStateVerified =>
      _isAssignmentListVerified && _workSessionsError == null;

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

  bool get _hasActivePaymentAttempt =>
      _paymentAttempts.any((attempt) => attempt.status.isActive);

  bool get _hasOpenDispute => _disputes.any((dispute) => dispute.isOpen);

  bool get _canStartPayment =>
      _isAssignmentSnapshotVerified && !_hasActivePaymentAttempt;

  /// Atamanın uyuşmazlıkları; kart üzerinde açık olan gösteriliyor.
  List<Dispute> _disputes = const [];
  bool _areDisputesLoading = true;
  String? _disputesError;

  bool get _isDisputeStateVerified =>
      !_areDisputesLoading && _disputesError == null;

  bool get _isPaymentAttemptStateVerified =>
      !_arePaymentAttemptsLoading && _paymentAttemptsError == null;

  bool get _isAssignmentSnapshotVerified =>
      _isAssignmentStateVerified &&
      _isDisputeStateVerified &&
      _isPaymentAttemptStateVerified;

  bool _canCompleteAssignment(Assignment assignment) =>
      _isAssignmentSnapshotVerified &&
      !_hasOpenDispute &&
      (assignment.status == AssignmentStatus.confirmed ||
          assignment.status == AssignmentStatus.inProgress);

  /// Değerlendirme yalnızca `COMPLETED` atamada: sunucu da aynı kapıyı
  /// `409 REVIEW_WORK_NOT_COMPLETED` ile tutuyor. İptal/ret edilen atamada
  /// değerlendirilecek bir iş yok.
  bool _canReviewWorker(Assignment assignment) =>
      assignment.status == AssignmentStatus.completed;

  bool _canOpenDisputeFor(Assignment assignment) =>
      _isAssignmentSnapshotVerified &&
      assignment.paymentStatus == PaymentStatus.heldInEscrow &&
      !_hasOpenDispute;

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

  /// Doğrudan bağlantıda ilan listesi de gelmemiş olabilir. Tekrar deneme
  /// önce ilan özetini geri getirir, ancak ondan sonra bu ilana ait
  /// başvuranları yeniler.
  Future<void> _retryApplicants() async {
    final provider = context.read<BJobsProvider>();
    if (provider.getPostByJobId(widget.jobId) == null) {
      await provider.load(force: true);
      if (!mounted || provider.getPostByJobId(widget.jobId) == null) return;
    }
    await provider.ensureApplicants(widget.jobId, force: true);
  }

  /// İlanın atamasını ve ona bağlı yardımcı kayıtları tek snapshot olarak
  /// yeniler.
  ///
  /// Atama listesi çekilemezse son güvenilir snapshot korunur ve hata görünür
  /// kalır. Başarılı boş yanıt ise bütün ilişkili alanları gerçekten temizler.
  /// Aynı anda başlayan yenilemelerde yalnızca en yeni istek state yazabilir.
  Future<void> _loadAssignment({String? selectedAssignmentId}) async {
    final generation = ++_assignmentLoadGeneration;
    if (mounted) {
      setState(() {
        if (selectedAssignmentId != null) {
          _pendingAssignmentId = selectedAssignmentId;
        }
        _isAssignmentLoading = true;
        _assignmentLoadError = null;
      });
    }

    try {
      final matches = await _employerJobService.fetchAssignmentsForJob(
        widget.jobId,
      );
      final selectedId =
          selectedAssignmentId ?? _pendingAssignmentId ?? _assignment?.id;
      final match = matches.isEmpty
          ? null
          : matches.firstWhere(
              (assignment) => assignment.id == selectedId,
              orElse: () => matches.first,
            );

      if (!mounted || generation != _assignmentLoadGeneration) return;
      if (match == null) {
        setState(() {
          _assignment = null;
          _assignments = const [];
          _workSessions = const [];
          _workSessionsError = null;
          _disputes = const [];
          _areDisputesLoading = false;
          _disputesError = null;
          _paymentAttempts = const [];
          _paymentAttemptsError = null;
          _arePaymentAttemptsLoading = false;
          _hasLoadedAssignments = true;
          _isAssignmentLoading = false;
          _assignmentLoadError = null;
          _pendingAssignmentId = null;
        });
        return;
      }

      final (
        workSessionsResult,
        disputesResult,
        paymentAttemptsResult,
      ) = await (
        LoadResult.capture(_assignmentService.fetchWorkSessions(match.id)),
        LoadResult.capture(_assignmentService.fetchDisputes(match.id)),
        LoadResult.capture(_paymentService.fetchAttempts(match.id)),
      ).wait;

      if (!mounted || generation != _assignmentLoadGeneration) return;
      final keepsRelatedSnapshot = _assignment?.id == match.id;
      setState(() {
        _assignments = matches;
        _assignment = match;
        _workSessions =
            workSessionsResult.value ??
            (keepsRelatedSnapshot ? _workSessions : const []);
        _workSessionsError = workSessionsResult.error?.message;
        _disputes =
            disputesResult.value ??
            (keepsRelatedSnapshot ? _disputes : const []);
        _areDisputesLoading = false;
        _disputesError = disputesResult.error?.message;
        _paymentAttempts =
            paymentAttemptsResult.value ??
            (keepsRelatedSnapshot ? _paymentAttempts : const []);
        _arePaymentAttemptsLoading = false;
        _paymentAttemptsError = paymentAttemptsResult.error?.message;
        _hasLoadedAssignments = true;
        _isAssignmentLoading = false;
        _assignmentLoadError = null;
        _pendingAssignmentId = null;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _assignmentLoadGeneration) return;
      setState(() {
        _isAssignmentLoading = false;
        _assignmentLoadError = error.message;
      });
    }
  }

  /// Değerlendirme ekranını bu atamanın çalışanı için açar.
  ///
  /// Ekran başarı ve hata toast'larını kendisi gösteriyor. Dönüşte satır
  /// [ReviewProvider]'ın oturum belleğinden düğmesiz hâline geçiyor; bir
  /// sonraki yüklemede sunucunun `myReview` alanı esas.
  Future<void> _reviewWorker(Assignment assignment) async {
    if (!_canReviewWorker(assignment)) return;
    await context.push('/review', extra: ReviewSubject.forWorker(assignment));
  }

  Future<void> _selectAssignment(String assignmentId) async {
    final match = _assignments
        .where((item) => item.id == assignmentId)
        .firstOrNull;
    if (match == null ||
        match.id == _assignment?.id ||
        !_isAssignmentListVerified) {
      return;
    }

    await _loadAssignment(selectedAssignmentId: assignmentId);
  }

  Future<void> _loadDisputes(String assignmentId) async {
    if (_isAssignmentLoading) return;
    final generation = _assignmentLoadGeneration;
    if (mounted && _assignment?.id == assignmentId) {
      setState(() {
        _areDisputesLoading = true;
        _disputesError = null;
      });
    }

    try {
      final disputes = await _assignmentService.fetchDisputes(assignmentId);
      if (mounted &&
          generation == _assignmentLoadGeneration &&
          _assignment?.id == assignmentId) {
        setState(() {
          _disputes = disputes;
          _disputesError = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted &&
          generation == _assignmentLoadGeneration &&
          _assignment?.id == assignmentId) {
        setState(() {
          _disputesError = error.message;
        });
      }
    } finally {
      if (mounted &&
          generation == _assignmentLoadGeneration &&
          _assignment?.id == assignmentId) {
        setState(() => _areDisputesLoading = false);
      }
    }
  }

  Future<void> _loadPaymentAttempts([String? assignmentId]) async {
    if (!mounted || _isAssignmentLoading) return;
    final generation = _assignmentLoadGeneration;
    final id = assignmentId ?? _assignment?.id;
    if (id == null) return;

    setState(() {
      _arePaymentAttemptsLoading = true;
      _paymentAttemptsError = null;
    });

    try {
      final attempts = await _paymentService.fetchAttempts(id);
      if (!mounted ||
          generation != _assignmentLoadGeneration ||
          _assignment?.id != id) {
        return;
      }
      setState(() => _paymentAttempts = attempts);
    } on ApiException catch (error) {
      if (!mounted ||
          generation != _assignmentLoadGeneration ||
          _assignment?.id != id) {
        return;
      }
      setState(() => _paymentAttemptsError = error.message);
    } finally {
      if (mounted &&
          generation == _assignmentLoadGeneration &&
          _assignment?.id == id) {
        setState(() => _arePaymentAttemptsLoading = false);
      }
    }
  }

  /// Atamaya sabitlenmiş backend dökümünü gösterip açık onay alır.
  Future<void> _requestPayment() async {
    final assignment = _assignment;
    if (assignment == null ||
        !assignment.needsEmployerPayment ||
        _isStartingPayment ||
        !_canStartPayment) {
      return;
    }
    final generation = _assignmentLoadGeneration;

    final breakdown = assignment.pricing;
    if (breakdown == null) {
      AppToast.error(context, 'Atamanın fiyat dökümü alınamadı.');
      return;
    }

    setState(() => _isStartingPayment = true);
    try {
      final confirmed = await _confirmPayment(breakdown);
      final currentAssignment = _assignment;
      if (confirmed != true ||
          !mounted ||
          generation != _assignmentLoadGeneration ||
          currentAssignment?.id != assignment.id ||
          currentAssignment == null ||
          !currentAssignment.needsEmployerPayment ||
          !_canStartPayment) {
        return;
      }

      await _startPayment(currentAssignment);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      // Bireysel işverenin adresi yokken İyzico alıcı kaydı kurulamıyor ve
      // sunucu "İşverenin adres bilgisi eksik." diyor. Mesaj ne yapılacağını
      // söylemiyor; kullanıcı doğrudan adres ekranına götürülüyor, kayıt
      // `UserProvider`'ı tazeliyor ve ödeme yeniden denenebiliyor.
      if (AddressRequiredErrorCodes.matches(error)) {
        await AccountNavigation.openAddress(context);
      }
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
    if (assignment == null ||
        _isRunningAssignmentAction ||
        !_canCompleteAssignment(assignment)) {
      return;
    }
    final generation = _assignmentLoadGeneration;

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

    var currentAssignment = _assignment;
    if (!mounted ||
        generation != _assignmentLoadGeneration ||
        currentAssignment?.id != assignment.id ||
        currentAssignment == null ||
        !_canCompleteAssignment(currentAssignment)) {
      return;
    }

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

    currentAssignment = _assignment;
    if (reason == null ||
        !mounted ||
        generation != _assignmentLoadGeneration ||
        currentAssignment?.id != assignment.id ||
        currentAssignment == null ||
        !_canCompleteAssignment(currentAssignment)) {
      return;
    }

    await _runAssignmentAction(
      (id) async {
        final cancellation = await _assignmentService.cancel(
          assignmentId: id,
          reason: reason,
        );
        return cancellation.hasFee
            ? 'İş iptal edildi · %${cancellation.feePercent} kesinti uygulandı'
            : 'İş iptal edildi, kesinti uygulanmadı';
      },
      expectedAssignmentId: assignment.id,
      expectedGeneration: generation,
      isEligible: _canCompleteAssignment,
    );
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
          'tamamı (${TurkishMoneyFormatter.format(preview.refundAmount, 'TRY')}) iade edilir. '
          'Tutar iptal anında yeniden hesaplanır.';
    }

    final started = preview.hasStarted
        ? ' İş başladığı için iade yapılmıyor.'
        : '';

    return '$opening\n\nŞu an iptal edersen %${preview.feePercent} kesinti '
        'uygulanır: ${TurkishMoneyFormatter.format(preview.feeAmount, 'TRY')} kesilir, '
        '${TurkishMoneyFormatter.format(preview.refundAmount, 'TRY')} iade edilir.$started '
        'Tutar iptal anında yeniden hesaplanır.';
  }

  /// Uyuşmazlık açar.
  ///
  /// Yalnızca para emanetteyken açılabiliyor ve emanetteki parayı donduruyor:
  /// çalışana ödeme yapılmıyor, sunucunun kendiliğinden tamamlaması duruyor.
  Future<void> _openDispute() async {
    final assignment = _assignment;
    if (assignment == null || !_canOpenDisputeFor(assignment)) return;
    final generation = _assignmentLoadGeneration;

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

    final currentAssignment = _assignment;
    if (reason == null ||
        !mounted ||
        generation != _assignmentLoadGeneration ||
        currentAssignment?.id != assignment.id ||
        currentAssignment == null ||
        !_canOpenDisputeFor(currentAssignment)) {
      return;
    }

    await _runAssignmentAction(
      (id) async {
        await _assignmentService.openDispute(assignmentId: id, reason: reason);
        return 'Sorun bildirildi, Koala inceleyecek';
      },
      expectedAssignmentId: assignment.id,
      expectedGeneration: generation,
      isEligible: _canOpenDisputeFor,
    );
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
    Future<String> Function(String assignmentId) action, {
    required String expectedAssignmentId,
    required int expectedGeneration,
    required bool Function(Assignment assignment) isEligible,
  }) async {
    final assignment = _assignment;
    if (assignment == null ||
        assignment.id != expectedAssignmentId ||
        _assignmentLoadGeneration != expectedGeneration ||
        _isRunningAssignmentAction ||
        !isEligible(assignment)) {
      return;
    }

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
      if (error.type.serverStateMoved) await _loadAssignment();
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
    if (assignment == null ||
        _isCompleting ||
        !_canCompleteAssignment(assignment)) {
      return;
    }
    final generation = _assignmentLoadGeneration;

    final confirmed = await _confirmCompletion(assignment);
    final currentAssignment = _assignment;
    if (confirmed != true ||
        !mounted ||
        generation != _assignmentLoadGeneration ||
        currentAssignment?.id != assignment.id ||
        currentAssignment == null ||
        !_canCompleteAssignment(currentAssignment)) {
      return;
    }

    setState(() => _isCompleting = true);

    try {
      await _employerJobService.completeAssignment(currentAssignment.id);
      if (!mounted) return;
      AppToast.success(context, 'İş tamamlandı olarak işaretlendi');
      // Tamamlama ilanın durumunu da değiştiriyor.
      await _loadDetail();
      if (mounted) await _loadAssignment();
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      if (error.type.serverStateMoved) await _loadAssignment();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  /// Tamamlama onayı. Açık mesai varsa uyarı metni farklı.
  Future<bool?> _confirmCompletion(Assignment assignment);

  /// Adayın bu ilandaki ataması; yoksa `null`.
  ///
  /// Sunucu başvuruyla birlikte atamanın kimliğini gönderiyorsa
  /// (`JobApplicantDto.assignmentId`, koala-backend#282) doğrudan o kayıt.
  /// Göndermiyorsa çalışan kimliğiyle eşleniyor: aynı çalışanın birden
  /// fazla ataması olabilir (iptal sonrası yeniden kabul) ve sunucunun
  /// `closed` hesabıyla aynı seçim yapılıyor — en yeni atama tarihi olan.
  /// Tarihsiz kayıt en eski sayılıyor.
  Assignment? _assignmentOf(JobApplicant applicant) {
    final byId = applicant.assignmentId == null
        ? null
        : _assignments
              .where((assignment) => assignment.id == applicant.assignmentId)
              .firstOrNull;
    if (byId != null) return byId;

    Assignment? latest;
    for (final assignment in _assignments) {
      if (assignment.worker?.id != applicant.user.id) continue;
      final current = latest;
      if (current == null || _isNewer(assignment, current)) latest = assignment;
    }
    return latest;
  }

  static bool _isNewer(Assignment candidate, Assignment current) {
    final candidateDate = candidate.assignmentDateTime;
    final currentDate = current.assignmentDateTime;
    if (candidateDate == null) return false;
    if (currentDate == null) return true;
    return candidateDate.isAfter(currentDate);
  }

  /// Başvuran kartındaki "Ödemeye Git" kısayolu.
  ///
  /// Ödeme akışı ekranda seçili atama üzerinden yürüyor; kart başka bir
  /// çalışanınsa önce o atama seçiliyor. Snapshot doğrulanmadan ödeme
  /// başlatılmıyor ([_canStartPayment]); o durumda sessiz kalmak yerine
  /// kullanıcıya söyleniyor.
  Future<void> _openPaymentFor(Assignment assignment) async {
    if (_assignment?.id != assignment.id) {
      await _selectAssignment(assignment.id);
      if (!mounted || _assignment?.id != assignment.id) return;
    }

    if (!_canStartPayment) {
      AppToast.info(
        context,
        'Ödeme durumu doğrulanıyor; birazdan tekrar dene.',
      );
      return;
    }

    await _requestPayment();
  }

  /// Başvuru kartından, seçilen adayla bu ilana bağlı sohbeti açar.
  ///
  /// Sunucu aynı ilan/çalışan çifti için mevcut konuşmayı döndürdüğünden bu
  /// buton güvenle tekrar kullanılabilir; kopya sohbet oluşmaz.
  ///
  /// Sunucu kapıyı kapattıysa (`403 MESSAGING_PAYMENT_REQUIRED`,
  /// `409 MESSAGING_WINDOW_CLOSED`) düğmenin yerine yazılan metnin aynısı
  /// gösteriliyor ve atama yeniden çekiliyor: düğme görünüyorsa elimizdeki
  /// atama bayat demek.
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
      if (!mounted) return;
      final gate = MessagingAvailability.fromErrorCode(error.errorCode);
      if (gate == null) {
        AppToast.error(context, error.message);
        return;
      }
      AppToast.error(context, gate.noteFor(asEmployer: true) ?? error.message);
      await _loadAssignment();
    } finally {
      if (mounted) setState(() => _openingChatUserId = null);
    }
  }

  /// Adayın özgeçmişini harici tarayıcıda açar.
  ///
  /// Bağlantı `JobApplicantDto.cvUrl`'den geliyor ve sunucu onu yalnızca bu
  /// ilanın işverenine dolduruyor; açılamazsa kullanıcıya söyleniyor.
  Future<void> _openCv(JobApplicant applicant) async {
    final url = applicant.cvUrl;
    if (url == null || url.isEmpty) return;

    final open =
        widget.openExternalUrl ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    final opened = await open(Uri.parse(url));
    if (!mounted || opened) return;
    AppToast.error(context, 'Özgeçmiş açılamadı');
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
