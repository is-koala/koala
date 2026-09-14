part of 'work_detail_page.dart';

abstract class WorkDetailPagemodel
    extends WorkActionsPagemodel<WorkDetailPage> {
  @override
  AssignmentService get assignmentService =>
      widget.assignmentService ?? AssignmentService();

  @override
  ChatService get chatService => widget.chatService ?? ChatService();

  JobService get _jobService => widget.jobService ?? JobService();

  /// Ekranın gösterdiği kayıt. Rotadan gelenle başlıyor; bir eylemden sonra
  /// sunucudan yeniden okunup yerine konuyor.
  late MyJob job = widget.job;

  /// İlanın tam hâli: adres, açıklama, ilanı açan kişi ve şirket.
  ///
  /// Satırın taşıdığı özet bunları içermiyor (`JobSummaryDto`), o yüzden
  /// ayrı bir istek. Gelemezse sayfa çökmüyor: adres ilçe/il'e, işveren adı
  /// özetteki şirket adına düşüyor ve [detailError] üstte bir şerit çiziyor.
  JobDetail? detail;
  String? detailError;

  /// Atamanın mesai oturumları; çizelgenin giriş/çıkış satırları ve süren
  /// işteki "başladın" satırı buradan.
  List<WorkSession> sessions = const [];

  /// Süren işin açık oturumu; yoksa `null`.
  WorkSession? get openSession =>
      sessions.where((session) => session.isOpen).firstOrNull;

  /// İptal kaydı: `GET .../cancellation` ile çekilen tam kayıt. Çekilemezse
  /// atamanın içinde gelen özet ([Assignment.cancellation]) kullanılıyor.
  Cancellation? cancellation;

  /// Bir eylem sonrası kayıt yeniden okunurken.
  bool refreshing = false;

  /// Açık mesai süresini işleten sayaç; İşlerim'dekiyle aynı gerekçe.
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
    unawaited(_loadAssignmentRecords());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(initializeTimesheetQueue());
    });
  }

  @override
  void dispose() {
    disposeTimesheetQueue();
    _elapsedTicker?.cancel();
    super.dispose();
  }

  /// Eylemden sonra yalnızca bu kaydı tazeler.
  ///
  /// Atama `GET /job-assignments/{id}` ile tek istekte geliyor. Başvuru
  /// için böyle bir uç yok; [ApplyProvider] listesini yeniden çekiyor ve
  /// aynı kimlikli kayıt oradan alınıyor. Kayıt bir atamaya dönüştüyse
  /// (kabul edildi) listeden düşer; o zaman eldeki hâl kalıyor — kullanıcı
  /// İşlerim'e döndüğünde yeni satırı görecek.
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
        setState(() => job = MyJob.fromAssignment(assignment));
        await _loadAssignmentRecords();
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

  /// Mesai oturumlarını ve iptal kaydını çeker.
  ///
  /// İkisi de yalnızca ilgili durumda isteniyor: oturum, onaydan önce
  /// olamaz; iptal kaydı, iptal edilmemiş atamada `null` döner ve boşuna
  /// bir istektir. Hata sayfayı kapatmıyor — çizelge o satırlar olmadan
  /// çiziliyor, iptal kartı atamanın içindeki özete düşüyor.
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

    if (job.status == MyJobStatus.cancelled) {
      try {
        final loaded = await assignmentService.fetchCancellation(assignmentId);
        if (!mounted) return;
        setState(() => cancellation = loaded);
      } on ApiException {
        if (!mounted) return;
      }
    }

    _syncElapsedTicker();
  }

  /// Mesai yalnızca çalışan onayladıktan sonra başlayabiliyor; cevap
  /// bekleyen ya da reddedilmiş atamada oturum yok.
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

  /// Açık oturum varken sayacı çalıştırır, kalmadığında durdurur.
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

  /// Sayfanın gösterdiği ilan özeti; sohbet ve ilan sheet'i bunu istiyor.
  Job? get summaryJob => job.assignment?.job ?? job.application?.job;

  /// Şirket sayfasına gider; kimlik bilinmiyorsa dokunma bağlanmıyor.
  VoidCallback? get openCompany {
    final companyId = job.companyId ?? detail?.company?.id;
    if (companyId == null) return null;
    return () => context.push('/company-detail', extra: companyId);
  }

  /// Başvuruyu geri çeker; başarılıysa kaydı tazeler ki satır "Geri
  /// Çektin" olarak görünsün.
  Future<void> withdraw() async {
    final withdrawn = await withdrawApplication(job);
    if (withdrawn && mounted) await refreshWork();
  }
}
