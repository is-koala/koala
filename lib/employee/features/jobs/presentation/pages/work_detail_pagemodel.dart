part of 'work_detail_page.dart';

abstract class WorkDetailPagemodel
    extends WorkActionsPagemodel<WorkDetailPage> {
  @override
  AssignmentService get assignmentService =>
      widget.assignmentService ?? AssignmentService();

  @override
  ChatService get chatService => widget.chatService ?? ChatService();

  JobService get _jobService => widget.jobService ?? JobService();

  TransportService get _transportService =>
      widget.transportService ?? TransportService();

  /// Eylemden sonra sunucudan yeniden okunup yerine konur.
  late MyJob job = widget.job;

  /// İlanın tam hâli; özet içermiyor. Gelemezse adres ilçe/il'e, işveren özete
  /// düşer ve [detailError] şerit çizer.
  JobDetail? detail;
  String? detailError;

  List<WorkSession> sessions = const [];

  WorkSession? get openSession =>
      sessions.where((session) => session.isOpen).firstOrNull;

  /// Çekilemezse atamadaki özet kullanılır.
  Cancellation? cancellation;

  /// En yeni önde (#215); çekilemezse özet kartı çizilmez.
  List<Dispute> disputes = const [];

  bool refreshing = false;

  /// Ulaşım görünümü (#197); aktif atamada tazelenir, koltuk seçimi sunucunun
  /// döndürdüğünü koyar.
  late AssignmentTransport? transport = job.assignment?.transport;

  ShuttleDirection? seatBusyDirection;

  /// Son bilinende koltuğu olup taze görünümde kalmayan yönler; sunucu "düştü"
  /// bayrağı taşımıyor.
  Set<ShuttleDirection> droppedSeatDirections = const {};

  static Set<ShuttleDirection> _seatedDirections(
    AssignmentTransport? transport,
  ) => {
    if (transport != null)
      for (final direction in ShuttleDirection.values)
        if (transport.selectedStop(direction) != null) direction,
  };

  void _applyTransport(AssignmentTransport? loaded) {
    final before = _seatedDirections(transport);
    final after = _seatedDirections(loaded);
    droppedSeatDirections = {
      ...droppedSeatDirections,
      ...before.difference(after),
    }..removeAll(after);
    transport = loaded;
  }

  /// Sunucu yalnız `PENDING_CONFIRMATION` / `CONFIRMED` / `IN_PROGRESS`'te
  /// kabul ediyor.
  bool get canSelectSeat =>
      job.assignmentId != null &&
      switch (job.status) {
        MyJobStatus.awaitingApproval ||
        MyJobStatus.approved ||
        MyJobStatus.inProgress => true,
        MyJobStatus.pending ||
        MyJobStatus.completed ||
        MyJobStatus.past ||
        MyJobStatus.rejected ||
        MyJobStatus.applicationRejected ||
        MyJobStatus.cancelled ||
        MyJobStatus.withdrawn ||
        MyJobStatus.unknown => false,
      };

  /// Sunucu `CONFIRMED` / `IN_PROGRESS` / `COMPLETED`'de kabul ediyor; iş
  /// bitince okutacak servis kalmadığı için düğme onaylı ve süren işte.
  bool get canBoard =>
      job.assignmentId != null &&
      (job.status == MyJobStatus.approved ||
          job.status == MyJobStatus.inProgress);

  BoardingQueueProvider? _boardingQueue;
  int _boardingRevision = 0;

  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
    unawaited(_loadAssignmentRecords());
    unawaited(_loadTransport());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(initializeTimesheetQueue());
      if (mounted) unawaited(_initializeBoardingQueue());
    });
  }

  @override
  void dispose() {
    _boardingQueue?.removeListener(_onBoardingQueueChanged);
    disposeTimesheetQueue();
    _elapsedTicker?.cancel();
    super.dispose();
  }

  /// Yalnız bu kaydı tazeler. Başvuru için tek kayıt ucu yok, [ApplyProvider]
  /// listeyi çeker; kayıt atamaya dönüştüyse eldeki hâl kalır.
  @override
  Future<void> refreshWork() async {
    final assignmentId = job.assignmentId;
    setState(() => refreshing = true);
    try {
      if (assignmentId != null) {
        final assignment = await assignmentService.fetchAssignment(
          assignmentId,
        );
        if (!mounted) return;
        setState(() {
          job = MyJob.fromAssignment(assignment);
          if (assignment.transport != null) {
            _applyTransport(assignment.transport);
          }
        });
        await _loadAssignmentRecords();
        await _loadTransport();
        return;
      }

      final provider = context.read<ApplyProvider>();
      await provider.load(force: true);
      if (!mounted) return;
      final refreshed = provider.appliedJobs
          .where((candidate) => candidate.id == job.id)
          .firstOrNull;
      if (refreshed != null) setState(() => job = refreshed);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> _loadDetail() async {
    final jobId = job.jobId;
    if (jobId == null) return;

    setState(() => detailError = null);
    try {
      final loaded = await _jobService.getById(jobId);
      if (!mounted) return;
      setState(() => detail = loaded);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => detailError = error.message);
    }
  }

  /// Oturum, iptal kaydı ve uyuşmazlıkları yalnız ilgili durumda çeker; hata
  /// sayfayı kapatmaz. Sayaç oturumlardan hemen sonra kurulur, diğer okumaları
  /// beklemez.
  Future<void> _loadAssignmentRecords() async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null) return;

    if (_mayHaveSessions) {
      try {
        final loaded = await assignmentService.fetchWorkSessions(assignmentId);
        if (!mounted) return;
        setState(() => sessions = loaded);
      } on ApiException {
        if (!mounted) return;
      }
    }
    _syncElapsedTicker();

    await Future.wait([
      if (job.status == MyJobStatus.cancelled) _loadCancellation(assignmentId),
      if (_mayHaveDispute) _loadDisputes(assignmentId),
    ]);
  }

  Future<void> _loadCancellation(String assignmentId) async {
    try {
      final loaded = await assignmentService.fetchCancellation(assignmentId);
      if (!mounted) return;
      setState(() => cancellation = loaded);
    } on ApiException {
      if (!mounted) return;
    }
  }

  Future<void> _loadDisputes(String assignmentId) async {
    try {
      final loaded = await assignmentService.fetchDisputes(assignmentId);
      if (!mounted) return;
      setState(() => disputes = Dispute.newestFirst(loaded));
    } on ApiException {
      if (!mounted) return;
    }
  }

  /// Yalnız emanette para olmuşsa; onay bekleyen ve reddedilmişte istek boşuna.
  bool get _mayHaveDispute => switch (job.status) {
    MyJobStatus.awaitingApproval || MyJobStatus.rejected => false,
    _ => true,
  };

  /// Dönünce özet tazelenir; karar verilmiş olabilir.
  Future<void> openDisputeScreen() async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null) return;

    await context.push(DisputeRoutes.location(assignmentId));
    if (!mounted) return;
    unawaited(_loadAssignmentRecords());
  }

  /// Yalnız koltuk seçilebilen atamada. `404` plan yok demek, kart kalkar;
  /// başka hata eldeki görünümü korur.
  Future<void> _loadTransport() async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || !canSelectSeat) return;

    try {
      final loaded = await _transportService.fetchAssignmentTransport(
        assignmentId,
      );
      if (!mounted) return;
      setState(() => _applyTransport(loaded));
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.type == ApiErrorType.notFound) {
        setState(() => _applyTransport(null));
      }
    }
  }

  /// Önceki oturumda saklanan okutmalar gönderilsin; teslimde biniş durumu
  /// yeniden okunur.
  Future<void> _initializeBoardingQueue() async {
    final queue = Provider.of<BoardingQueueProvider?>(context, listen: false);
    if (queue == null) return;
    _boardingQueue = queue;
    _boardingRevision = queue.deliveryRevision;
    queue.addListener(_onBoardingQueueChanged);
    if (!canBoard || queue.activeUserId != null) return;

    final users = Provider.of<UserProvider?>(context, listen: false);
    if (users == null) return;
    if (users.user == null) await users.load(silent: true);
    final userId = users.user?.id;
    if (!mounted || userId == null) return;
    await queue.tryStartForUser(userId);
  }

  void _onBoardingQueueChanged() {
    final queue = _boardingQueue;
    if (!mounted || queue == null) return;
    if (queue.deliveryRevision == _boardingRevision) return;
    _boardingRevision = queue.deliveryRevision;
    unawaited(_loadTransport());
  }

  Future<void> openBoardingScan(ShuttleDirection direction) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null) return;
    await context.push<bool>(
      EmployeeRoutes.boardingScanLocation(
        assignmentId: assignmentId,
        direction: direction.code,
        shuttleId: transport?.seatFor(direction)?.shuttleId,
      ),
    );
    if (mounted) await _loadTransport();
  }

  Future<void> openMyBoardingQr(ShuttleDirection direction) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null) return;
    await context.push<void>(
      EmployeeRoutes.boardingQrLocation(assignmentId, direction.code),
    );
    if (mounted) await _loadTransport();
  }

  void dismissBoarding(String clientEventId) {
    unawaited(_boardingQueue?.dismiss(clientEventId));
  }

  /// Yön için koltuk seçtirir. `409` ve `404` sunucunun mesajıyla gösterilir ve
  /// görünüm yeniden okunur; doluluk bayat.
  Future<void> selectSeat(ShuttleDirection direction) async {
    final assignmentId = job.assignmentId;
    final current = transport;
    if (assignmentId == null || current == null || seatBusyDirection != null) {
      return;
    }

    final choice = await SeatPickerSheet.show(
      context,
      direction: direction,
      shuttles: current.shuttlesFor(direction),
      selected: current.seatFor(direction),
    );
    if (choice == null || !mounted) return;

    setState(() => seatBusyDirection = direction);
    try {
      final updated = await _transportService.selectSeat(
        assignmentId,
        shuttleId: choice.shuttleId,
        stopId: choice.stopId,
      );
      if (!mounted) return;
      setState(() => _applyTransport(updated));
      AppToast.success(context, 'Koltuk seçiminiz kaydedildi.');
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      final stale =
          error.type.serverStateMoved ||
          error.type == ApiErrorType.notFound ||
          TransportErrorCodes.seatConflicts.contains(error.errorCode);
      if (stale) await _loadTransport();
    } finally {
      if (mounted) setState(() => seatBusyDirection = null);
    }
  }

  Future<void> callDriver(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final opened = await _openExternal(Uri(scheme: 'tel', path: digits));
    if (!mounted || opened) return;
    AppToast.error(context, 'Arama başlatılamadı');
  }

  bool get _mayHaveSessions => switch (job.status) {
    MyJobStatus.approved ||
    MyJobStatus.inProgress ||
    MyJobStatus.completed ||
    MyJobStatus.past ||
    MyJobStatus.cancelled => true,
    MyJobStatus.pending ||
    MyJobStatus.awaitingApproval ||
    MyJobStatus.rejected ||
    MyJobStatus.applicationRejected ||
    MyJobStatus.withdrawn ||
    MyJobStatus.unknown => false,
  };

  void _syncElapsedTicker() {
    if (openSession == null) {
      _elapsedTicker?.cancel();
      _elapsedTicker = null;
      return;
    }

    _elapsedTicker ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Job? get summaryJob => job.assignment?.job ?? job.application?.job;

  /// Detay karar verir, yoksa özet, o da yoksa yaklaşık (ADR-0003).
  AddressPrecision get addressPrecision =>
      detail?.addressPrecision ??
      summaryJob?.addressPrecision ??
      AddressPrecision.approximate;

  /// Yalnız **kesin** konumda. Özetin koordinatı yalnız özet de `EXACT`
  /// diyorsa: yuvarlanmış koordinat olmayan kapıya götürür (#188).
  DirectionsTarget? get directionsTarget {
    if (addressPrecision.isApproximate) return null;
    final position = detail?.address?.position;
    final summary = summaryJob;
    final double latitude;
    final double longitude;
    if (position != null) {
      latitude = position.latitude;
      longitude = position.longitude;
    } else if (summary != null &&
        summary.hasLocation &&
        !summary.addressPrecision.isApproximate) {
      latitude = summary.latitude!;
      longitude = summary.longitude!;
    } else {
      return null;
    }
    return DirectionsTarget(
      latitude: latitude,
      longitude: longitude,
      arrival: detail?.startDateTime ?? summary?.startDateTime,
    );
  }

  /// iOS'ta Apple / Google Haritalar seçtirilir, Google yoksa evrensel
  /// bağlantı; Android'de doğrudan evrensel bağlantı. Kullanıcının konumu
  /// bağlantıda yok.
  Future<void> openDirections(DirectionsTarget target) async {
    final Uri primary;
    Uri? fallback;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final app = await OptionSheet.show<DirectionsApp>(
        context,
        title: 'Yol tarifini nerede açalım?',
        options: DirectionsApp.values,
        labelOf: (app) => app.label,
        iconOf: (_) => AppIcons.route,
      );
      if (app == null || !mounted) return;
      switch (app) {
        case DirectionsApp.apple:
          primary = DirectionsLinks.appleMaps(target);
        case DirectionsApp.google:
          primary = DirectionsLinks.googleMapsApp(target);
          fallback = DirectionsLinks.googleMapsWeb(target);
      }
    } else {
      primary = DirectionsLinks.googleMapsWeb(target);
    }

    var opened = await _openExternal(primary);
    if (!opened && fallback != null) opened = await _openExternal(fallback);
    if (!mounted || opened) return;
    AppToast.error(context, 'Harita uygulaması açılamadı');
  }

  /// Android'de işleyicisi olmayan şema `PlatformException` fırlatabilir; o da
  /// "açılamadı" sayılır.
  Future<bool> _openExternal(Uri url) async {
    final open =
        widget.openExternalUrl ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    try {
      return await open(url);
    } on PlatformException {
      return false;
    }
  }

  VoidCallback? get openCompany {
    final companyId = job.companyId ?? detail?.company?.id;
    if (companyId == null) return null;
    return () => context.push('/company-detail', extra: companyId);
  }

  /// Atamanın `employer`'ı, yoksa ilan detayının `creator`'ı. Kartın adı ve
  /// profil bağlantısı aynı kişiyi buradan okuyor ki ayrışmasın.
  JobCreator? get individualEmployer =>
      job.assignment?.employer ?? detail?.creator;

  /// Yalnız bireysel ilanda (#182).
  VoidCallback? get openEmployerProfile {
    final person = individualEmployer;
    if (person == null || person.id.isEmpty) return null;
    return () => context.push(
      EmployeeRoutes.publicProfile(person.id),
      extra: PublicProfileArgs(
        userId: person.id,
        name: person.fullName.isEmpty ? null : person.fullName,
        imageUrl: person.profilePictureUrl,
        role: ChatParticipantRole.employer,
      ),
    );
  }

  /// [ApplyProvider.withdraw] satırı güncelliyor, `409`'da listeyi kendisi
  /// çekiyor; durum oradan okunur.
  Future<void> withdraw() async {
    final withdrawn = await withdrawApplication(job);
    if (!withdrawn || !mounted) return;
    final refreshed = context
        .read<ApplyProvider>()
        .appliedJobs
        .where((candidate) => candidate.id == job.id)
        .firstOrNull;
    if (refreshed != null) setState(() => job = refreshed);
  }
}
