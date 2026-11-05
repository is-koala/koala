part of 'worker_boarding_qr_page.dart';

abstract class WorkerBoardingQrPagemodel extends State<WorkerBoardingQrPage>
    with WidgetsBindingObserver {
  late final BoardingQrController controller = BoardingQrController(
    load: () => (widget.transportService ?? TransportService()).fetchWorkerQr(
      widget.assignmentId,
      direction: widget.direction,
    ),
  );

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

  /// Arka planda zamanlayıcı işlemez; öne gelince QR hemen tazelenir —
  /// arada `refreshAt` geçmiş olabilir.
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

  /// QR alınamadığında ekrandaki cümle. `404` burada "QR tanınmadı" değil,
  /// atamanın bu işçiye ait olmadığı ya da kalktığı demek.
  String errorMessage(ApiException error) {
    final failure = BoardingFailure.classify(error);
    if (failure == BoardingFailure.invalidQr) {
      return 'Bu işin biniş QR\'ı alınamadı; iş size ait değil ya da '
          'kaldırılmış.';
    }
    return failure.message(BoardingActor.worker, serverMessage: error.message);
  }
}
