part of 'b_shuttle_scan_page.dart';

abstract class BShuttleScanPagemodel extends State<BShuttleScanPage> {
  TransportService get _service =>
      widget.transportService ?? TransportService();

  DeviceLocationSource get _location =>
      widget.locationSource ?? const GeolocatorLocationSource();

  /// Okutma sunucuda.
  bool busy = false;

  /// Son okutmanın sonucu.
  BoardingResultPanel? lastResult;

  /// Koltuk → çalışan adı; sonuç satırında ad yazmak için. Liste
  /// okunamazsa boş kalır ve satır adsız yazılır.
  Map<String, String> _names = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadNames());
  }

  Future<void> _loadNames() async {
    try {
      final rows = await _service.fetchShuttleBoardings(widget.shuttleId);
      if (!mounted) return;
      _names = {for (final row in rows) row.seatAssignmentId: row.displayName};
    } on ApiException {
      // Ad yalnız bilgi; liste yoksa okutma yine çalışır.
    }
  }

  Future<void> onToken(BoardingToken token, DateTime capturedAt) async {
    if (busy) return;
    setState(() {
      busy = true;
      lastResult = null;
    });
    try {
      final result = await BShuttleScanPage.record(
        service: _service,
        location: _location,
        token: token,
        capturedAt: capturedAt,
        names: _names,
      );
      if (mounted) setState(() => lastResult = result);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
