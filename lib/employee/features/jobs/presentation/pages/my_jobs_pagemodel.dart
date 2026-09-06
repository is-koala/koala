part of 'my_jobs_page.dart';

abstract class MyJobsPagemodel extends State<MyJobsPage> {
  /// Küçük buton göstergesi varsayılan kalınlıkta dolu görünmesin.
  static const double _spinnerStroke = 2;

  final AssignmentService _service = AssignmentService();
  final ChatService _chatService = ChatService();

  /// Geçmiş bölümü varsayılan olarak kısaltılmış; kullanıcı isterse açıyor.
  bool showAllPastJobs = false;

  List<MyJob> allJobs = [];
  bool loading = true;

  /// Atamalar çekilemediyse gösterilecek mesaj.
  String? errorMessage;

  /// Geçmiş bölümünde kısaltılmışken gösterilen iş sayısı.
  static const int collapsedPastJobCount = 2;

  /// Süren işlerin açık mesai oturumları; anahtar atama kimliği.
  ///
  /// Yalnızca `IN_PROGRESS` atamalar için çekiliyor: bir kişinin aynı anda
  /// süren birden fazla işi olmuyor, o yüzden bu N+1 değil. Değer `null`
  /// ise oturumlar okundu ve açık oturum yok demek.
  final Map<String, WorkSession?> openSessions = {};

  /// Mesai isteği sunucuya gitmiş atamanın id'si; butonu kilitliyor.
  String? timesheetBusyAssignmentId;
  TimesheetQueueProvider? _timesheetQueue;
  int _timesheetDeliveryRevision = 0;

  /// Açık mesai süresini işleten sayaç.
  ///
  /// Süre `WorkSession.elapsed` içinde `DateTime.now()` ile hesaplanıyor;
  /// yeniden çizilmezse ekranda donuk kalır ve çalışana yanlış süre gösterir.
  /// Dakikada bir yetiyor — süre zaten dakika hassasiyetinde yazılıyor.
  Timer? _elapsedTicker;

  /// İptal ya da uyuşmazlık isteği sunucuya gitmiş atamanın id'si.
  String? assignmentActionId;

  /// Cevabı sunucuya gitmiş atamanın id'si; iki butonu da kilitliyor.
  ///
  /// Tek bir alan yetiyor çünkü kullanıcı aynı anda tek bir atamaya cevap
  /// veriyor ve cevap dönene kadar liste tazelenmiyor.
  String? respondingAssignmentId;

  /// İlan sohbeti açılırken ikinci navigasyonu engeller.
  String? openingChatJobId;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    // Başvurular ayrı bir uçtan geliyor; sekmeye her girişte tekrar
    // çekilmesin diye provider ilk çağrıdan sonra ağa çıkmıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ApplyProvider>().load();
      if (mounted) unawaited(_initializeTimesheetQueue());
    });
  }

  Future<void> _initializeTimesheetQueue() async {
    try {
      final queue = context.read<TimesheetQueueProvider>();
      _timesheetQueue = queue;
      queue.addListener(_onTimesheetQueueChanged);
      _announceTimesheetDelivery(queue);

      final userProvider = context.read<UserProvider>();
      if (userProvider.user == null) await userProvider.load(silent: true);
      if (!mounted) return;
      final userId = userProvider.user?.id;
      if (userId != null && queue.activeUserId != userId) {
        final started = await queue.tryStartForUser(userId);
        if (!started && mounted) {
          AppToast.error(context, 'Mesai kuyruğu başlatılamadı.');
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Mesai kuyruğu başlatılamadı.');
      }
    }
  }

  void _onTimesheetQueueChanged() {
    final queue = _timesheetQueue;
    if (!mounted || queue == null) return;
    _announceTimesheetDelivery(queue);
  }

  void _announceTimesheetDelivery(TimesheetQueueProvider queue) {
    if (!mounted) return;
    if (queue.deliveryRevision == _timesheetDeliveryRevision) return;
    _timesheetDeliveryRevision = queue.deliveryRevision;
    if (queue.takeDeliveryAcknowledgement() == null) return;
    AppToast.success(context, 'Mesai kaydı gönderildi.');
    unawaited(_loadJobs());
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
            .toList(growable: false);
      });
      await _loadOpenSessions();
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

  /// Başvurunun veya atamanın bağlı olduğu ilan üzerinden işverenle konuşur.
  Future<void> openChat(MyJob job) async {
    final jobId = job.jobId;
    final currentUser = context.read<UserProvider>().user;
    if (jobId == null || currentUser == null || openingChatJobId != null) {
      return;
    }

    setState(() => openingChatJobId = jobId);
    try {
      final conversation = await _chatService.openConversationForJob(
        jobId: jobId,
        currentUserId: currentUser.id,
      );
      if (!mounted) return;
      await context.push('/chat-detail', extra: conversation);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => openingChatJobId = null);
    }
  }

  /// Atamayı kabul eder ya da reddeder.
  ///
  /// Cevap `JobAssignmentDto` dönüyor; ödeme alanlarını taşımadığı için
  /// listedeki kayıt cevaptan güncellenmiyor, atamalar yeniden çekiliyor.
  /// Reddedilen atama listeden tamamen düşüyor: [MyJob.fromAssignment]
  /// `REJECTED` için `null` döndürüyor.
  @override
  void dispose() {
    _timesheetQueue?.removeListener(_onTimesheetQueueChanged);
    _elapsedTicker?.cancel();
    super.dispose();
  }

  /// Açık oturum varken sayacı çalıştırır, kalmadığında durdurur.
  void _syncElapsedTicker() {
    final hasOpenSession = openSessions.values.any(
      (session) => session != null,
    );

    if (!hasOpenSession) {
      _elapsedTicker?.cancel();
      _elapsedTicker = null;
      return;
    }

    _elapsedTicker ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Süren işlerin açık mesai oturumlarını çeker.
  ///
  /// Oturum listesi çekilemezse ekran çökmüyor: açık oturum bilinmediğinde
  /// satır "Giriş Yap" gösteriyor ve sunucu gerekirse `409` ile düzeltiyor.
  Future<void> _loadOpenSessions() async {
    final ids = allJobs
        .where((job) => job.status == MyJobStatus.inProgress)
        .map((job) => job.assignmentId)
        .whereType<String>()
        .toList(growable: false);

    openSessions.removeWhere((id, _) => !ids.contains(id));

    for (final id in ids) {
      try {
        final sessions = await _service.fetchWorkSessions(id);
        if (!mounted) return;
        openSessions[id] = sessions
            .where((session) => session.isOpen)
            .firstOrNull;
      } on ApiException {
        if (!mounted) return;
        openSessions.remove(id);
      }
    }

    if (!mounted) return;
    _syncElapsedTicker();
    setState(() {});
  }

  /// Başvuruyu geri çeker.
  ///
  /// Gerekçe sorulmuyor — sunucu istemiyor ve kullanıcıdan kendi başvurusunu
  /// geri çekmek için açıklama beklemek gereksiz — o yüzden [ReasonDialog]
  /// değil [ConfirmDialog].
  ///
  /// İstek [ApplyProvider] üzerinden gidiyor: liste o provider'da duruyor ve
  /// geri çekilen satır orada güncelleniyor, atamalar yeniden çekilmiyor.
  Future<void> withdrawApplication(MyJob job) async {
    final provider = context.read<ApplyProvider>();
    if (provider.withdrawingId != null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Başvurunu geri çek',
      message:
          '"${job.title}" ilanına yaptığın başvuru geri çekilecek ve işveren '
          'artık yanıtlayamayacak. İlan hâlâ açıksa yeniden başvurabilirsin.',
      actionLabel: 'Geri Çek',
    );

    if (confirmed != true || !mounted) return;

    final withdrawn = await provider.withdraw(job.id);
    if (!mounted) return;

    if (withdrawn) {
      AppToast.success(context, 'Başvurun geri çekildi');
      return;
    }

    // `409` alındıysa provider listeyi zaten tazeledi; burada yalnızca
    // sunucunun Türkçe mesajı gösteriliyor.
    AppToast.error(context, provider.errorMessage ?? 'Başvuru geri çekilemedi');
  }

  /// Atamayı iptal eder.
  ///
  /// Kutu açılmadan önce kesinti önizlemesi çekiliyor: çalışanın iptalinde
  /// kesinti çıkmıyor ama bunu kullanıcıya **tahmin ettirmek** yerine
  /// sunucuya sormak doğrusu — oranlar sunucu ayarından geliyor ve
  /// değişebilir.
  ///
  /// Önizleme alınamazsa akış durmuyor: kutu kuralı kelimeyle anlatıyor.
  /// Kesintiyi öğrenememek iptal hakkını kaldırmamalı.
  Future<void> cancelAssignment(MyJob job) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || assignmentActionId != null) return;

    setState(() => assignmentActionId = assignmentId);
    CancellationPreview? preview;
    try {
      preview = await _service.fetchCancellationPreview(assignmentId);
    } on ApiException {
      preview = null;
    } finally {
      if (mounted) setState(() => assignmentActionId = null);
    }

    if (!mounted) return;

    // Sunucu iptale kapalı atamada hata yerine bu bayrağı döndürüyor.
    if (preview != null && !preview.cancellableNow) {
      AppToast.error(context, 'Bu iş artık iptal edilemez');
      await _loadJobs();
      return;
    }

    final reason = await ReasonDialog.show(
      context,
      title: 'İşi iptal et',
      description: _cancellationDescription(job, preview),
      fieldLabel: 'İptal gerekçen',
      confirmLabel: 'İptal Et',
    );

    if (reason == null || !mounted) return;

    await _runAssignmentAction(
      job,
      action: (id) async {
        final cancellation = await _service.cancel(
          assignmentId: id,
          reason: reason,
        );
        return cancellation.hasFee
            ? 'İş iptal edildi · %${cancellation.feePercent} kesinti uygulandı'
            : 'İş iptal edildi';
      },
    );
  }

  /// İptal kutusunun gövdesi.
  ///
  /// Önizleme geldiyse tutar yazılıyor, gelmediyse kural. Her iki durumda da
  /// tutarın bağlayıcı olmadığı söyleniyor: kesinti işin başlamasına kalan
  /// süreye bağlı ve sunucu iptal anında yeniden hesaplıyor.
  String _cancellationDescription(MyJob job, CancellationPreview? preview) {
    final opening =
        '"${job.title}" işi iptal edilecek ve geri alınamayacak. '
        'Sık iptal profilini etkileyebilir.';

    if (preview == null) {
      return '$opening\n\nSenin iptalinde kesinti uygulanmıyor, ücret '
          'işverene iade ediliyor.';
    }

    if (!preview.hasFee) {
      return '$opening\n\nBu iptalde senden kesinti yapılmayacak.';
    }

    return '$opening\n\nBu iptalde %${preview.feePercent} kesinti '
        'uygulanacak (${TurkishMoneyFormatter.format(preview.feeAmount, 'TRY')}). Tutar iptal '
        'anında yeniden hesaplanır.';
  }

  /// Uyuşmazlık açar.
  ///
  /// Yalnızca para emanetteyken açılabiliyor. Açık uyuşmazlık emanetteki
  /// parayı donduruyor: ödeme durur, sunucunun kendiliğinden tamamlaması da
  /// durur. Yani kullanıcıya "ödemen hızlanır" diye sunulacak bir şey değil.
  Future<void> openDispute(MyJob job) async {
    final reason = await ReasonDialog.show(
      context,
      title: 'Sorun bildir',
      description:
          '"${job.title}" işiyle ilgili bir sorun bildireceksin. Emanetteki '
          'ücret, Koala konuyu inceleyip sonuçlandırana kadar dondurulur — '
          'yani ödeme hızlanmaz, durur.',
      fieldLabel: 'Yaşadığın sorun',
      confirmLabel: 'Bildir',
      isDestructive: false,
    );

    if (reason == null || !mounted) return;

    await _runAssignmentAction(
      job,
      action: (id) async {
        await _service.openDispute(assignmentId: id, reason: reason);
        return 'Sorun bildirildi, Koala inceleyecek';
      },
    );
  }

  /// İptal ve uyuşmazlığın ortak gövdesi: kilit, hata ve tazeleme.
  Future<void> _runAssignmentAction(
    MyJob job, {
    required Future<String> Function(String assignmentId) action,
  }) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || assignmentActionId != null) return;

    setState(() => assignmentActionId = assignmentId);

    try {
      final message = await action(assignmentId);
      if (!mounted) return;
      AppToast.success(context, message);
      await _loadJobs();
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      // 409: durum sunucuda değişmiş — iş zaten iptal edilmiş ya da emanette
      // para kalmamış olabilir. Doğrusunu göstermek için tazeleniyor.
      if (error.type == ApiErrorType.conflict) await _loadJobs();
    } finally {
      if (mounted) setState(() => assignmentActionId = null);
    }
  }

  /// Mesaiye başlar.
  ///
  /// Konum isteğe bağlı; alınamazsa giriş yine yapılıyor. Konumun yokluğu
  /// yüzünden çalışanın mesaisi başlamamazlık edemez.
  Future<void> checkIn(MyJob job) => _runTimesheetAction(
    job,
    action: (queue, id, position) => queue.recordCheckIn(
      assignmentId: id,
      latitude: position?.latitude,
      longitude: position?.longitude,
    ),
  );

  /// Açık mesai oturumunu kapatır.
  Future<void> checkOut(MyJob job) => _runTimesheetAction(
    job,
    action: (queue, id, position) => queue.recordCheckOut(
      assignmentId: id,
      latitude: position?.latitude,
      longitude: position?.longitude,
    ),
  );

  Future<void> _runTimesheetAction(
    MyJob job, {
    required Future<TimesheetSubmission> Function(
      TimesheetQueueProvider queue,
      String id,
      Position? position,
    )
    action,
  }) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || timesheetBusyAssignmentId != null) return;

    setState(() => timesheetBusyAssignmentId = assignmentId);

    try {
      final queue = context.read<TimesheetQueueProvider>();
      if (queue.activeUserId == null) {
        final userProvider = context.read<UserProvider>();
        if (userProvider.user == null) await userProvider.load(silent: true);
        final userId = userProvider.user?.id;
        if (userId == null) {
          throw StateError('Oturum sahibi yüklenemedi.');
        }
        await queue.startForUser(userId);
      }

      final result = await action(
        queue,
        assignmentId,
        await _currentPosition(),
      );
      if (!mounted) return;
      switch (result) {
        case TimesheetSubmission.sent:
          // Listener normalde ACK sırasında bildirir; sayfa kuyruğa henüz
          // bağlanmadıysa aynı tek-tüketim yolunu burada tamamla.
          _announceTimesheetDelivery(queue);
        case TimesheetSubmission.pending:
          AppToast.info(context, 'Kaydedildi, gönderilmeyi bekliyor.');
        case TimesheetSubmission.requiresSupport:
          AppToast.error(
            context,
            'Mesai kaydı için destek gerekiyor.',
            actionLabel: 'Destek Al',
            onAction: () => openTimesheetSupport(job),
          );
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Mesai kaydı cihazda saklanamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => timesheetBusyAssignmentId = null);
    }
  }

  Future<void> openTimesheetSupport(MyJob job) async {
    final jobId = job.jobId;
    if (jobId == null) {
      await context.push('/reports');
      return;
    }
    await ReportSheet.show(
      context,
      ReportTarget.job(jobId: jobId, title: job.title),
    );
  }

  /// Cihazın konumu; alınamazsa `null`.
  ///
  /// Sunucu konumsuz mesai kaydını kabul ediyor, o yüzden izin reddi ya da
  /// GPS hatası burada yutuluyor — akışı durduracak bir şey değil.
  Future<Position?> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

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

  /// Şirket detayına gider.
  ///
  /// TODO(backend): `MyAssignmentDto.job` şirket kimliği taşımıyor (yalnızca
  /// `companyName`), o yüzden [MyJob.companyId] hep boş ve satır tıklanabilir
  /// değil. `JobSummaryDto`'ya `companyId` eklenirse burası çalışır.
  void navigateToCompany(MyJob job) {
    final companyId = job.companyId;
    if (companyId == null) return;

    context.push('/company-detail', extra: companyId);
  }
}
