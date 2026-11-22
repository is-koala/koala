part of 'b_job_detail_page.dart';

abstract class BJobDetailPageModel extends State<BJobDetailPage>
    with WidgetsBindingObserver {
  static const double _tintAlpha = 0.12;

  static const double _detailLabelWidth = 80;

  static const double _applicantAvatar = 48;

  static const double _workerAvatar = 56;

  /// Varsayılan 4 bu boyutta dolu daire gibi görünüyor.
  static const double _spinnerStroke = 2;

  static const double _multilineHeight = 1.4;

  JobService get _jobService => widget.jobService ?? JobService();

  EmployerJobService get _employerJobService =>
      widget.employerJobService ?? EmployerJobService();

  BPaymentService get _paymentService =>
      widget.paymentService ?? BPaymentService();

  BPaymentBrowser get _paymentBrowser =>
      widget.paymentBrowser ?? BPaymentBrowser();

  ChatService get _chatService => widget.chatService ?? ChatService();

  /// Mesai oturumlarını iki taraf da okuyor; tek servis iki uygulamaya.
  AssignmentService get _assignmentService =>
      widget.assignmentService ?? AssignmentService();

  TransportService get _transportService =>
      widget.transportService ?? TransportService();

  /// İlanın ulaşım planı (#197). Plan yoksa `null` ve "plan ekle"; ucu
  /// tanımayan eski sunucuda bölüm hiç çizilmez ([_transportUnavailable]).
  TransportPlan? _transportPlan;
  bool _isTransportLoading = true;
  bool _transportUnavailable = false;
  String? _transportError;

  /// Liste ucu açıklama/görev/adres döndürmediği için ayrıca çekiliyor.
  JobDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  /// O kartın butonları kilitli, diğerleri çalışır.
  String? _respondingApplicationId;

  /// Aynı anda iki konuşma açılmasın.
  String? _openingChatUserId;

  List<Assignment> _assignments = const [];
  Assignment? _assignment;

  /// Atama listesinin son yenileme durumu. Boş yanıt gerçek "atama yok"; hata
  /// eski snapshot'ı korur ama para ve durum değiştiren eylemleri kapatır.
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

  List<WorkSession> _workSessions = const [];

  bool _isCompleting = false;

  bool _isStartingPayment = false;

  /// Ayrı hata durumuna düşer; atamayı ve mesaiyi kapatmaz.
  List<BPaymentAttempt> _paymentAttempts = const [];
  bool _arePaymentAttemptsLoading = false;
  String? _paymentAttemptsError;

  bool get _hasActivePaymentAttempt =>
      _paymentAttempts.any((attempt) => attempt.status.isActive);

  bool get _hasOpenDispute => _disputes.any((dispute) => dispute.isOpen);

  bool get _canStartPayment =>
      _isAssignmentSnapshotVerified && !_hasActivePaymentAttempt;

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

  /// Yalnız `COMPLETED` atamada; sunucu da `409 REVIEW_WORK_NOT_COMPLETED`.
  bool _canReviewWorker(Assignment assignment) =>
      assignment.status == AssignmentStatus.completed;

  bool _canOpenDisputeFor(Assignment assignment) =>
      _isAssignmentSnapshotVerified &&
      assignment.paymentStatus == PaymentStatus.heldInEscrow &&
      !_hasOpenDispute;

  bool _isRunningAssignmentAction = false;

  bool _isSavingTemplate = false;

  /// Sigorta için açılan kimlik; yalnız bellekte. Her okuma kayda geçip
  /// çalışana bildirildiği için [_identityRevealWindow] boyunca tutulur, sonra
  /// silinir.
  WorkerIdentity? _workerIdentity;

  /// Başka atama seçilince kart yanlış çalışanın altında kalmasın.
  String? _workerIdentityAssignmentId;
  Timer? _workerIdentityTimer;
  bool _isRevealingIdentity = false;

  /// Sunucunun `404` dediği atamalar; düğme bir daha çizilmez.
  final Set<String> _identityUnavailableAssignmentIds = {};

  /// Sigorta ekranına yazacak kadar uzun, açık unutulmayacak kadar kısa (#195).
  static const Duration _identityRevealWindow = Duration(seconds: 60);

  /// Yalnız işe alınmış atamada; sunucu da diğerlerini `404` ile kapatıyor.
  bool _canRevealWorkerIdentity(Assignment assignment) =>
      !_identityUnavailableAssignmentIds.contains(assignment.id) &&
      switch (assignment.status) {
        AssignmentStatus.confirmed ||
        AssignmentStatus.inProgress ||
        AssignmentStatus.completed => true,
        AssignmentStatus.pendingConfirmation ||
        AssignmentStatus.rejected ||
        AssignmentStatus.cancelled => false,
      };

  /// Testler için: temizleme yolları ekrandan değil buradan doğrulanıyor; kart
  /// kaybolup değer kalmış olabilirdi.
  @visibleForTesting
  bool get holdsWorkerIdentity =>
      _workerIdentity != null ||
      _workerIdentityAssignmentId != null ||
      _workerIdentityTimer != null;

  WorkerIdentity? _revealedIdentityFor(Assignment assignment) =>
      _workerIdentityAssignmentId == assignment.id ? _workerIdentity : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDetail();
    unawaited(_loadTransportPlan());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Doğrudan bağlantıyla gelinmişse liste çekilmemiş olabilir.
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
    _clearWorkerIdentity();
    super.dispose();
  }

  /// Ödeme sayfasından dönünce mutabakatın son durumunu gösterir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadAssignment());
    }
    // Arka plana alınınca kimlik silinir: dönüşte sayfa TCKN'yle açılmamalı.
    if (state == AppLifecycleState.paused && _workerIdentity != null) {
      setState(_clearWorkerIdentity);
    }
  }

  /// `404` iki anlamlı, yalnız `errorCode` ayırıyor: `TRANSPORT_PLAN_NOT_FOUND`
  /// "henüz plan yok" → "plan ekle"; diğer `404` eski sunucu → bölüm gizli.
  /// Yoksa eski sunucuda "plan ekle" çıkar ve `PUT` de `404` alırdı.
  Future<void> _loadTransportPlan() async {
    setState(() {
      _isTransportLoading = true;
      _transportUnavailable = false;
      _transportError = null;
    });
    try {
      final plan = await _transportService.fetchPlan(widget.jobId);
      if (!mounted) return;
      setState(() => _transportPlan = plan);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.type == ApiErrorType.notFound) {
        final noPlan = error.errorCode == TransportErrorCodes.planNotFound;
        setState(() {
          _transportPlan = null;
          _transportUnavailable = !noPlan;
        });
      } else {
        setState(() => _transportError = error.message);
      }
    } finally {
      if (mounted) setState(() => _isTransportLoading = false);
    }
  }

  Future<void> _editTransportPlan() async {
    final current = _transportPlan;
    final saved = await context.push<TransportPlan>(
      BusinessRoutes.transportPlan,
      extra: BTransportPlanArgs(
        jobId: widget.jobId,
        initial: current == null ? null : TransportPlanDraft.fromPlan(current),
        original: current,
        jobStart: _detail?.startDateTime,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _transportPlan = saved);
  }

  void _openShuttleBoardings(ShuttleDraft shuttle) {
    final shuttleId = shuttle.id;
    if (shuttleId == null) return;
    unawaited(
      context.push(
        BusinessRoutes.shuttleBoardingsLocation(shuttleId, name: shuttle.name),
      ),
    );
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
      unawaited(_adoptIfOutsideList(detail));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  /// İlan listede olmayabilir (başka yetkilinin şirket ilanı ya da eski ilan);
  /// sunucu başvuruları yine açıyor. [BJobsProvider.adoptJob] ile benimsenir.
  Future<void> _adoptIfOutsideList(JobDetail detail) async {
    final provider = context.read<BJobsProvider>();
    final viewerId = context.read<UserProvider>().user?.id;
    if (provider.adoptJob(detail, viewerId: viewerId)) {
      await provider.ensureApplicants(detail.id);
    }
  }

  /// Önce ilan özetini, sonra başvuranları yeniler.
  Future<void> _retryApplicants() async {
    final provider = context.read<BJobsProvider>();
    if (provider.getPostByJobId(widget.jobId) == null) {
      await provider.load(force: true);
      if (!mounted || provider.getPostByJobId(widget.jobId) == null) return;
    }
    await provider.ensureApplicants(widget.jobId, force: true);
  }

  /// Atamayı ve bağlı kayıtları tek snapshot olarak yeniler. Hata eski
  /// snapshot'ı korur, boş yanıt temizler; yalnız en yeni istek yazar.
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

  /// Ekran toast'ları kendisi gösterir; sonraki yüklemede sunucunun
  /// `myReview`'u esas.
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

    // Başka çalışana geçerken öncekinin kimliği bellekte kalmasın.
    if (_workerIdentity != null) setState(_clearWorkerIdentity);
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
      // İşverenin adresi yoksa ödeme başlamıyor ve sunucunun mesajı ne
      // yapılacağını söylemiyor; kullanıcı adres ekranına götürülür.
      if (AddressRequiredErrorCodes.matches(error)) {
        await AccountNavigation.openAddress(context);
      }
    } finally {
      if (mounted) setState(() => _isStartingPayment = false);
    }
  }

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
    if (!mounted) {
      return;
    }
    context.go(
      Uri(
        path: '/payment-result',
        queryParameters: {'assignmentId': assignment.id},
      ).toString(),
    );
  }

  Future<bool?> _confirmPayment(BPricingBreakdown breakdown);

  /// Atamayı iptal eder. Önce kesinti önizlemesi çekilir: para kaybettiren
  /// karar bilmeden verilmemeli. Önizleme alınamazsa kutu kuralı kelimeyle
  /// anlatır.
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

  /// Tutar bağlayıcı değil: kutu açıkken cezasız pencere kapanabilir, sunucu
  /// yeniden hesaplar.
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

  /// Dönünce durum tazelenir; karar bu arada verilmiş olabilir.
  Future<void> _openDisputeScreen(Dispute dispute) =>
      _openDisputeScreenFor(dispute.assignmentId);

  Future<void> _openDisputeScreenFor(String assignmentId) async {
    await context.push(DisputeRoutes.location(assignmentId));
    if (!mounted) return;
    unawaited(_loadDisputes(assignmentId));
  }

  /// Uyuşmazlık açar; yalnız para emanetteyken, parayı dondurur.
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

    final opened = await _runAssignmentAction(
      (id) async {
        await _assignmentService.openDispute(assignmentId: id, reason: reason);
        return 'Sorun bildirildi, Koala inceleyecek';
      },
      expectedAssignmentId: assignment.id,
      expectedGeneration: generation,
      isEligible: _canOpenDisputeFor,
    );

    // Açılınca doğrudan kanıt ekleme ekranı; dosya çoğu zaman elde.
    if (opened && mounted) await _openDisputeScreenFor(assignment.id);
  }

  // ------------------------------------------------------ Kimlik bilgileri

  /// Sigorta için kimliği açar. Önce onay: sunucu her okumayı çalışana
  /// bildiriyor. `409` doğrulama eksik, `429` bütçe dolu; `404` yetki ya da
  /// durum uymuyor ve düğme kalkar.
  Future<void> _revealWorkerIdentity(Assignment assignment) async {
    if (_isRevealingIdentity || !_canRevealWorkerIdentity(assignment)) return;
    final generation = _assignmentLoadGeneration;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Kimlik bilgilerini göster',
      message:
          'Görüntülemeniz kayda geçer ve çalışana bildirilir. Bilgiler '
          'yalnızca sigorta bildirimi için gösterilir ve bir dakika sonra '
          'gizlenir.',
      actionLabel: 'Göster',
      isDestructive: false,
    );

    if (confirmed != true ||
        !mounted ||
        generation != _assignmentLoadGeneration ||
        _assignment?.id != assignment.id ||
        !_canRevealWorkerIdentity(assignment)) {
      return;
    }

    setState(() => _isRevealingIdentity = true);
    try {
      final identity = await _employerJobService.fetchWorkerIdentity(
        assignment.id,
      );
      if (!mounted) return;
      _workerIdentityTimer?.cancel();
      setState(() {
        _workerIdentity = identity;
        _workerIdentityAssignmentId = assignment.id;
      });
      _workerIdentityTimer = Timer(_identityRevealWindow, () {
        if (mounted) setState(_clearWorkerIdentity);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.errorCode == WorkerIdentityErrorCodes.workerNotVerified) {
        AppToast.error(context, 'Çalışanın kimliği doğrulanmamış');
      } else if (error.errorCode == WorkerIdentityErrorCodes.tooManyRequests ||
          error.type == ApiErrorType.tooManyRequests) {
        AppToast.error(context, 'Çok sık görüntülendi, biraz sonra deneyin');
      } else if (error.type == ApiErrorType.notFound) {
        setState(() => _identityUnavailableAssignmentIds.add(assignment.id));
        AppToast.info(
          context,
          'Kimlik bilgileri bu atama için görüntülenemiyor',
        );
      } else {
        AppToast.error(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _isRevealingIdentity = false);
    }
  }

  Future<void> _copyIdentityNumber(WorkerIdentity identity) async {
    await Clipboard.setData(ClipboardData(text: identity.tcIdentityNumber));
    if (!mounted) return;
    AppToast.success(context, 'TCKN kopyalandı');
  }

  /// `setState` çağıranın; `dispose`'tan da çağrılıyor.
  void _clearWorkerIdentity() {
    _workerIdentityTimer?.cancel();
    _workerIdentityTimer = null;
    _workerIdentity = null;
    _workerIdentityAssignmentId = null;
  }

  // ------------------------------------------------------------ Şablonlar

  /// İlan gelmeden çizilmez: şablon var olan ilandan çıkarılıyor.
  Widget? _saveAsTemplateAction() {
    if (_detail == null) return null;

    return IconButton(
      tooltip: 'Şablon olarak kaydet',
      icon: AppIcon(AppIcons.fileText, color: context.textPrimary),
      onPressed: _isSavingTemplate ? null : _saveAsTemplate,
    );
  }

  /// İlanı şablon olarak kaydeder; yalnız ad ve kimlik gider. Ad zorunlu olduğu
  /// için boşken onayı kapalı tutan [ReasonDialog].
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
        // Toast sayfadan uzun yaşayabilir; ayrılmış sayfanın context'i hata
        // verirdi.
        onAction: () {
          if (mounted) context.push('/business/job-templates');
        },
      );
    } else {
      AppToast.error(context, provider.errorMessage ?? 'Şablon kaydedilemedi');
    }
  }

  /// İptal ve uyuşmazlığın ortak gövdesi; başarılıysa `true`.
  Future<bool> _runAssignmentAction(
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
      return false;
    }

    setState(() => _isRunningAssignmentAction = true);

    try {
      final message = await action(assignment.id);
      if (!mounted) return true;
      AppToast.success(context, message);
      await _loadDetail();
      if (mounted) await _loadAssignment();
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      AppToast.error(context, error.message);
      if (error.type.serverStateMoved) await _loadAssignment();
      return false;
    } finally {
      if (mounted) setState(() => _isRunningAssignmentAction = false);
    }
  }

  /// Geri alınamaz: para çıkışa hazırlanır. Önce onay, özellikle mesai
  /// sürerken.
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

  Future<bool?> _confirmCompletion(Assignment assignment);

  /// Adayın bu ilandaki ataması. Sunucu `assignmentId` gönderiyorsa o; yoksa
  /// çalışan kimliğiyle eşlenir ve sunucunun seçimiyle aynı şekilde en yeni
  /// atama alınır.
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

  /// "Ödemeye Git": kart başka çalışanınsa önce o atama seçilir. Snapshot
  /// doğrulanmadan ödeme başlamaz; o zaman kullanıcıya söylenir.
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

  /// Adayla ilana bağlı sohbeti açar; sunucu mevcut konuşmayı döndürür. Kapı
  /// kapalıysa (`403`/`409`) aynı açıklama gösterilir ve atama yeniden çekilir:
  /// düğme görünüyorsa eldeki atama bayattır.
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
      // Kabul atama açtığı için detay yeniden çekiliyor.
      await _loadDetail();
      if (!mounted) return;
      isDestructive
          ? AppToast.error(context, successMessage)
          : AppToast.success(context, successMessage);
    } else {
      AppToast.error(context, provider.errorMessage ?? 'İşlem tamamlanamadı');
    }
  }

  /// İptalde `null`, boşsa boş metin ("gerekçesiz reddet").
  Future<String?> _askRejectionReason(JobApplicant applicant);
}
