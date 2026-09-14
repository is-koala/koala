part of 'b_payment_result_page.dart';

typedef _PaymentResultPresentation = ({
  String title,
  String message,
  AppIconData icon,
  Color color,
});

abstract class BPaymentResultPagemodel extends State<BPaymentResultPage>
    with WidgetsBindingObserver {
  /// Web istemcisindeki mutabakat penceresiyle aynı, sert üst sınırlı sıra.
  /// Saat geri alınsa ya da gecikme bağımlılığı erken dönse bile liste sonlu.
  static const _pollDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isPolling = false;
  bool _automaticPollingFinished = false;
  bool _isAppActive = true;
  String? _error;
  Assignment? _assignment;
  Future<bool>? _requestInFlight;
  int _nextPollIndex = 0;
  int _pollGeneration = 0;

  AssignmentService get _service => widget.service ?? AssignmentService();

  DateTime get _now => (widget.now ?? DateTime.now)();

  Future<void> _delay(Duration duration) =>
      (widget.delay ?? Future<void>.delayed)(duration);

  bool get _isPending =>
      _assignment?.paymentStatus == PaymentStatus.pendingCollection;

  _PaymentResultPresentation get _presentation {
    final PaymentStatus? status = _assignment?.paymentStatus;
    late final _PaymentResultPresentation base;

    switch (status) {
      case PaymentStatus.heldInEscrow:
      case PaymentStatus.releasedToWorker:
        base = (
          title: 'Ödeme Güvende',
          message:
              'Ücret Koala güvencesinde tutuluyor. Çalışan artık mesaiye '
              'başlayabilir.',
          icon: AppIcons.shield,
          color: AppColors.success,
        );
      case PaymentStatus.failed:
        base = (
          title: 'Ödeme Başarısız',
          message:
              'Ödeme tamamlanamadı. İlan detayına dönüp yeniden deneyebilirsin.',
          icon: AppIcons.cancelCircle,
          color: AppColors.danger,
        );
      case PaymentStatus.refunded:
        base = (
          title: 'Ödeme İade Edildi',
          message:
              'Ücret iade edildi. Güncel ayrıntılar için ilan sayfasına '
              'dönebilirsin.',
          icon: AppIcons.info,
          color: AppColors.warning,
        );
      case PaymentStatus.pendingCollection:
        if (_isPolling && !_automaticPollingFinished) {
          base = (
            title: 'Ödeme Sonucu Kontrol Ediliyor',
            message:
                'Sağlayıcı sonucu işliyor. Otomatik olarak tekrar kontrol '
                'ediyoruz; bu sırada yeni ödeme başlatma.',
            icon: AppIcons.info,
            color: AppColors.warning,
          );
        } else {
          base = _unverifiedPresentation;
        }
      case null:
        base = _unverifiedPresentation;
    }

    final error = _error;
    if (error == null) return base;
    return (
      title: base.title,
      message: error,
      icon: base.icon,
      color: base.color,
    );
  }

  static const _PaymentResultPresentation _unverifiedPresentation = (
    title: 'Ödeme Henüz Doğrulanmadı',
    message:
        'Sonuç henüz ulaşmadı. Yeni ödeme başlatmadan önce birkaç dakika '
        'sonra tekrar kontrol et.',
    icon: AppIcons.info,
    color: AppColors.warning,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadInitially());
  }

  @override
  void dispose() {
    _isAppActive = false;
    _pollGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isAppActive) return;
      _isAppActive = true;
      _cancelWaitingPoll();
      unawaited(_refreshAfterResume());
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isAppActive = false;
      _cancelWaitingPoll();
    }
  }

  Future<void> _loadInitially() async {
    final succeeded = await _refresh(initial: true);
    if (!mounted || !_isAppActive || !succeeded || !_isPending) return;
    _startPolling(resetBudget: true);
  }

  Future<void> _refreshAfterResume() async {
    final succeeded = await _refresh();
    if (!mounted || !_isAppActive || !succeeded || !_isPending) return;
    _startPolling();
  }

  Future<void> _retry() async {
    if (_requestInFlight != null) return;
    _cancelWaitingPoll();
    final succeeded = await _refresh();
    if (!mounted || !_isAppActive || !succeeded || !_isPending) return;
    _startPolling();
  }

  /// Aynı anda yalnız tek backend sorgusu yürür. Manuel kontrol, yaşam döngüsü
  /// dönüşü ve otomatik deneme aynı olay turunda buluşursa aynı Future'ı
  /// paylaşır; geç kalan eski yanıt yeni durumu geri ezemez.
  Future<bool> _refresh({bool initial = false}) {
    final current = _requestInFlight;
    if (current != null) return current;

    late final Future<bool> operation;
    operation = _performRefresh(initial: initial).whenComplete(() {
      if (identical(_requestInFlight, operation)) {
        _requestInFlight = null;
      }
    });
    _requestInFlight = operation;
    return operation;
  }

  Future<bool> _performRefresh({required bool initial}) async {
    if (!mounted) return false;
    setState(() {
      if (initial && _assignment == null) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _error = null;
    });

    try {
      final assignment = await _service.fetchAssignment(widget.assignmentId);
      if (!mounted) return false;
      setState(() {
        _assignment = assignment;
        _isLoading = false;
        _isRefreshing = false;
      });
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      setState(() {
        _error = error.message;
        _isLoading = false;
        _isRefreshing = false;
      });
      return false;
    }
  }

  void _startPolling({bool resetBudget = false}) {
    if (resetBudget) {
      _nextPollIndex = 0;
      _automaticPollingFinished = false;
    }
    if (!mounted || !_isAppActive || !_isPending || _isPolling) return;
    if (_nextPollIndex >= _pollDelays.length) {
      _finishPolling(exhausted: true);
      return;
    }

    final generation = ++_pollGeneration;
    setState(() {
      _isPolling = true;
      _automaticPollingFinished = false;
    });
    unawaited(_runPolling(generation));
  }

  Future<void> _runPolling(int generation) async {
    while (mounted &&
        _isAppActive &&
        generation == _pollGeneration &&
        _isPending &&
        _nextPollIndex < _pollDelays.length) {
      final duration = _pollDelays[_nextPollIndex++];
      final dueAt = _now.add(duration);
      await _delay(duration);
      if (!mounted ||
          !_isAppActive ||
          generation != _pollGeneration ||
          !_isPending) {
        return;
      }

      // Enjekte edilen bekleme erken dönerse sıkı döngüye girmek yerine bu
      // pencereyi kapat. Deneme sayısı ayrıca her koşulda sert üst sınırdır.
      if (_now.isBefore(dueAt)) {
        _finishPolling(exhausted: true, generation: generation);
        return;
      }

      await _refresh();
      if (!mounted ||
          !_isAppActive ||
          generation != _pollGeneration ||
          !_isPending) {
        if (mounted && generation == _pollGeneration) {
          _finishPolling(generation: generation);
        }
        return;
      }
    }

    if (mounted && generation == _pollGeneration) {
      _finishPolling(
        exhausted: _isPending && _nextPollIndex >= _pollDelays.length,
        generation: generation,
      );
    }
  }

  void _cancelWaitingPoll() {
    _pollGeneration++;
    if (!mounted || !_isPolling) return;
    setState(() => _isPolling = false);
  }

  void _finishPolling({bool exhausted = false, int? generation}) {
    if (!mounted || (generation != null && generation != _pollGeneration)) {
      return;
    }
    setState(() {
      _isPolling = false;
      if (exhausted) _automaticPollingFinished = true;
    });
  }
}
