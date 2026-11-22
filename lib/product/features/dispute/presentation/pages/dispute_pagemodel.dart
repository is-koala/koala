part of 'dispute_page.dart';

abstract class DisputePagemodel extends State<DisputePage> {
  /// Sayfaya ait; uygulama boyunca yaşamıyor.
  late final DisputeProvider _provider;

  late final EvidencePicker _picker = widget.picker ?? const EvidencePicker();

  @override
  void initState() {
    super.initState();
    _provider = DisputeProvider(
      assignmentId: widget.assignmentId,
      assignmentService: widget.assignmentService,
      evidenceService: widget.evidenceService,
      clock: widget.clock,
    );
    unawaited(_provider.start());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  /// Eldeki liste varken başarısızlık toast'la söylenir; boş ekran kendi hata
  /// durumunu çizer.
  Future<void> _onRefresh() async {
    await _provider.refresh();
    if (!mounted) return;
    final message = _provider.errorMessage;
    if (message != null && _provider.cases.isNotEmpty) {
      AppToast.error(context, message);
    }
  }

  /// Kaynak seç → dosyayı al → doğrula ve yükle. Vazgeçilirse sessiz döner; red
  /// ne yapılacağını söyleyen toast olur.
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

  /// İmzalı adres üç dakika geçerli; hemen tarayıcıya veriliyor.
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
    EvidenceSource.camera => 'Kamerayla Çek',
    EvidenceSource.gallery => 'Galeriden Seç',
    EvidenceSource.document => 'PDF Belgesi Seç',
  };

  static AppIconData? _sourceIcon(EvidenceSource source) => switch (source) {
    EvidenceSource.camera => AppIcons.camera,
    EvidenceSource.gallery => AppIcons.gallery,
    EvidenceSource.document => AppIcons.fileText,
  };

  /// İzin reddi kullanıcının düzeltebileceği bir şey; ayrı mesaj.
  static String _pickFailureMessage(
    EvidenceSource source,
    PlatformException error,
  ) {
    final denied =
        error.code == 'camera_access_denied' ||
        error.code == 'photo_access_denied';
    if (denied) {
      return source == EvidenceSource.camera
          ? 'Kameraya erişim izni verilmemiş. Ayarlardan izin verip yeniden '
                'deneyin.'
          : 'Fotoğraflara erişim izni verilmemiş. Ayarlardan izin verip '
                'yeniden deneyin.';
    }
    return 'Dosya seçilemedi. Yeniden deneyin.';
  }
}
