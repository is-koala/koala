part of 'dispute_page.dart';

abstract class DisputePagemodel extends State<DisputePage> {
  /// Sayfanın kendi örneği: uygulama boyunca yaşayan provider yok, çıkışta
  /// temizlenecek bir şey kalmıyor ([DisputeProvider]).
  late final DisputeProvider _provider;

  late final EvidencePicker _picker = widget.picker ?? const EvidencePicker();

  @override
  void initState() {
    super.initState();
    _provider = DisputeProvider(
      assignmentId: widget.assignmentId,
      assignmentService: widget.assignmentService,
      evidenceService: widget.evidenceService,
    );
    unawaited(_provider.start());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  /// Çekip yenileme. Eldeki uyuşmazlıklar varken başarısız olursa liste yerinde
  /// kalıyor ve nedenini bir toast söylüyor; boş ekranda hata durumu zaten
  /// kendi mesajını çiziyor.
  Future<void> _onRefresh() async {
    await _provider.refresh();
    if (!mounted) return;
    final message = _provider.errorMessage;
    if (message != null && _provider.cases.isNotEmpty) {
      AppToast.error(context, message);
    }
  }

  /// Kanıt ekleme: kaynak seç → dosyayı al → doğrula ve yükle.
  ///
  /// Seçici vazgeçilirse sessizce dönüyor. Sınırlardan dönen dosya ve sunucu
  /// reddi aynı yoldan, kullanıcının **ne yapacağını** söyleyen bir toast
  /// ([AttachResult.message]); sunucu "durum değişmiş" dediğinde sayfa kendini
  /// zaten yeniden okuyor ([DisputeProvider.attach]).
  Future<void> _attach(DisputeCase entry) async {
    final source = await OptionSheet.show<EvidenceSource>(
      context,
      title: 'Kanıt ekle',
      options: EvidenceSource.values,
      labelOf: _sourceLabel,
      iconOf: _sourceIcon,
    );
    if (source == null || !mounted) return;

    final EvidenceCandidate? candidate;
    try {
      candidate = await _picker.pick(source);
    } on PlatformException catch (error) {
      if (!mounted) return;
      AppToast.error(context, _pickFailureMessage(source, error));
      return;
    }
    if (candidate == null || !mounted) return;

    final result = await _provider.attach(entry.dispute.id, candidate);
    if (!mounted) return;
    if (result.isAttached) {
      AppToast.success(context, 'Kanıt eklendi.');
      return;
    }
    final message = result.message;
    if (message != null) AppToast.error(context, message);
  }

  /// İndirme: imzalı adres üç dakika geçerli, o yüzden hemen harici tarayıcıya
  /// veriliyor ve saklanmıyor.
  Future<void> _download(DisputeEvidence evidence) async {
    final result = await _provider.download(evidence);
    if (!mounted) return;

    final url = result.url;
    if (url != null) {
      final open =
          widget.openExternalUrl ??
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
      final opened = await open(url);
      if (!mounted || opened) return;
      AppToast.error(context, 'Dosya açılamadı.');
      return;
    }

    if (result.isStreamed) {
      AppToast.error(
        context,
        'Bu dosya uygulamadan indirilemiyor. Koala web sitesinden '
        'indirebilirsiniz.',
      );
      return;
    }

    final failure = result.failure;
    if (failure != null) AppToast.error(context, failure.message);
  }

  static String _sourceLabel(EvidenceSource source) => switch (source) {
    EvidenceSource.camera => 'Fotoğraf çek',
    EvidenceSource.gallery => 'Galeriden seç',
    EvidenceSource.document => 'PDF belgesi seç',
  };

  static AppIconData? _sourceIcon(EvidenceSource source) => switch (source) {
    EvidenceSource.camera => AppIcons.camera,
    EvidenceSource.gallery => AppIcons.gallery,
    EvidenceSource.document => AppIcons.fileText,
  };

  /// İzin reddi ile diğer seçici hatalarını ayırır; ilki kullanıcının
  /// düzeltebileceği bir şey.
  static String _pickFailureMessage(
    EvidenceSource source,
    PlatformException error,
  ) {
    final denied =
        error.code == 'camera_access_denied' ||
        error.code == 'photo_access_denied';
    if (denied) {
      return source == EvidenceSource.camera
          ? 'Kameraya erişim izni verilmemiş. Ayarlardan izin verip yeniden dene.'
          : 'Fotoğraflara erişim izni verilmemiş. Ayarlardan izin verip '
                'yeniden dene.';
    }
    return 'Dosya seçilemedi. Yeniden dene.';
  }
}
