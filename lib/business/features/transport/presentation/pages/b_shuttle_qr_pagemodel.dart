part of 'b_shuttle_qr_page.dart';

abstract class BShuttleQrPagemodel extends State<BShuttleQrPage>
    with WidgetsBindingObserver {
  TransportService get _service =>
      widget.transportService ?? TransportService();

  /// Basılı (süresiz) QR seçili mi.
  bool isStatic = false;

  /// Anahtar yenileme sunucuda.
  bool rotating = false;

  late final BoardingQrController controller = BoardingQrController(
    load: _loader(isStatic: false),
  );

  String get title {
    final name = widget.shuttleName?.trim();
    return name == null || name.isEmpty ? 'Servis QR\'ı' : name;
  }

  BoardingQrLoader _loader({required bool isStatic}) =>
      () => _service.fetchShuttleQr(widget.shuttleId, isStatic: isStatic);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(controller.refresh());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        controller.pause();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> selectMode({required bool isStatic}) async {
    if (this.isStatic == isStatic) return;
    setState(() => this.isStatic = isStatic);
    await controller.switchTo(_loader(isStatic: isStatic));
  }

  /// Onaydan sonra anahtarı yeniler. Yanıt yeni dönen QR; basılı QR
  /// seçiliyse yeni anahtarla basılı QR ayrıca istenir.
  Future<void> rotate() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'QR yenilensin mi?',
      message: BShuttleQrPage.rotateMessage,
      actionLabel: 'Yenile',
    );
    if (confirmed != true || !mounted) return;

    setState(() => rotating = true);
    try {
      final rotated = await _service.rotateShuttleQr(widget.shuttleId);
      if (!mounted) return;
      if (isStatic) {
        await controller.refresh();
      } else {
        controller.replace(rotated);
      }
      if (!mounted) return;
      AppToast.success(context, 'QR yenilendi; eski QR\'lar geçersiz.');
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(error));
    } finally {
      if (mounted) setState(() => rotating = false);
    }
  }

  String errorMessage(ApiException error) {
    if (error.type == ApiErrorType.notFound) {
      return 'Servis bulunamadı ya da bu servisi yönetme yetkiniz yok.';
    }
    return BoardingFailure.classify(
      error,
    ).message(BoardingActor.employer, serverMessage: error.message);
  }
}
