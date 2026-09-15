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

  /// Adresin kesinliği: detay karar veriyor, gelmediyse özet, o da yoksa
  /// yaklaşık — kanıtlanmamış yetki kesin sayılmaz (ADR-0003).
  AddressPrecision get addressPrecision =>
      detail?.addressPrecision ??
      summaryJob?.addressPrecision ??
      AddressPrecision.approximate;

  /// Yol tarifinin hedefi; yalnız **kesin** konumda ve koordinat varsa.
  ///
  /// Koordinat önce detayın adresinden (`address.position`), o yoksa özetten
  /// — ama özetinki yalnız özet de `EXACT` derken: `APPROXIMATE` özet
  /// yuvarlanmış koordinat taşır ve yol tarifi olmayan bir kapıya götürürdü.
  /// Varış hedefi işin başlangıcı (is-koala/koala#188).
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

  /// Toplu taşıma yol tarifini harici haritada açar.
  ///
  /// iOS'ta Apple Haritalar / Google Haritalar seçtiriyor; Google uygulaması
  /// yoksa (`comgooglemaps://` açılamazsa) evrensel bağlantıya düşüyor.
  /// Android'de doğrudan evrensel bağlantı: sistem seçicisi Google
  /// Haritalar'ı ya da tarayıcıyı sunuyor. Kullanıcının konumu hiçbir
  /// bağlantıda yok; harita uygulaması başlangıcı kendisi okuyor.
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

  /// Bağlantıyı açar; açıcı `false` dönerse ya da fırlatırsa `false`.
  /// Android'de işleyicisi olmayan şema `PlatformException` fırlatabiliyor,
  /// yedek bağlantıya geçiş bunu da "açılamadı" saymalı.
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

  /// Şirket sayfasına gider; kimlik bilinmiyorsa dokunma bağlanmıyor.
  VoidCallback? get openCompany {
    final companyId = job.companyId ?? detail?.company?.id;
    if (companyId == null) return null;
    return () => context.push('/company-detail', extra: companyId);
  }

  /// Başvuruyu geri çeker; başarılıysa sayfayı provider'daki hâline
  /// çevirir.
  ///
  /// [ApplyProvider.withdraw] satırı yerinde güncelliyor ve `409`'da
  /// listeyi kendisi yeniden çekiyor; burada ikinci bir yükleme yok, yeni
  /// durum [ApplyProvider.appliedJobs]'tan okunuyor.
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
