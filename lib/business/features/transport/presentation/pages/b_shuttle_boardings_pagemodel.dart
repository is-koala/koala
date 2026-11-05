part of 'b_shuttle_boardings_page.dart';

/// Aynı durak ve kalkış saatindeki koltuklar.
class BoardingStopGroup {
  BoardingStopGroup({
    required this.stopId,
    required this.stopName,
    required this.scheduledAt,
  });

  final String stopId;
  final String stopName;
  final DateTime scheduledAt;
  final List<ShuttleBoardingRow> rows = [];

  int get boardedCount => rows.where((row) => row.boarded).length;
}

abstract class BShuttleBoardingsPagemodel extends State<BShuttleBoardingsPage> {
  TransportService get _service =>
      widget.transportService ?? TransportService();

  /// Sunucunun listesi; ilk yükleme bitene kadar `null`.
  List<ShuttleBoardingRow>? rows;
  String? errorMessage;

  /// İşareti sunucuda olan koltuk; satırların düğmeleri kilitli.
  String? busySeatId;

  int _generation = 0;

  String get title {
    final name = widget.shuttleName?.trim();
    return name == null || name.isEmpty ? 'Biniş listesi' : name;
  }

  /// Durak + kalkış saatine göre gruplar, saate göre sıralı; grup içinde
  /// ada göre.
  List<BoardingStopGroup> get groupedRows {
    final groups = <String, BoardingStopGroup>{};
    for (final row in rows ?? const <ShuttleBoardingRow>[]) {
      final key = '${row.stopId}|${row.scheduledAt.toIso8601String()}';
      groups
          .putIfAbsent(
            key,
            () => BoardingStopGroup(
              stopId: row.stopId,
              stopName: row.stopName,
              scheduledAt: row.scheduledAt,
            ),
          )
          .rows
          .add(row);
    }
    final sorted = groups.values.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    for (final group in sorted) {
      group.rows.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_generation;
    setState(() => errorMessage = null);
    try {
      final loaded = await _service.fetchShuttleBoardings(widget.shuttleId);
      if (!mounted || generation != _generation) return;
      setState(() => rows = loaded);
    } on ApiException catch (error) {
      if (!mounted || generation != _generation) return;
      final message = error.type == ApiErrorType.notFound
          ? 'Servis bulunamadı ya da bu servisi yönetme yetkiniz yok.'
          : BoardingFailure.classify(
              error,
            ).message(BoardingActor.employer, serverMessage: error.message);
      if (rows == null) {
        setState(() => errorMessage = message);
      } else {
        AppToast.error(context, message);
      }
    }
  }

  /// Listeden BİNDİ / BİNMEDİ işareti; token yok, kaynak `EMPLOYER_MARKED`.
  Future<void> mark(ShuttleBoardingRow row, BoardingKind kind) async {
    if (busySeatId != null) return;
    setState(() => busySeatId = row.seatAssignmentId);
    try {
      final event = await _service.markSeatBoarding(
        row.seatAssignmentId,
        clientEventId: newBoardingClientEventId(),
        kind: kind,
      );
      if (!mounted) return;
      setState(() => _replaceRow(row.seatAssignmentId, event));
      AppToast.success(
        context,
        kind == BoardingKind.boarded
            ? '${row.displayName} bindi olarak işaretlendi.'
            : '${row.displayName} binmedi olarak işaretlendi.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final failure = BoardingFailure.classify(error);
      AppToast.error(
        context,
        failure.message(BoardingActor.employer, serverMessage: error.message),
      );
      if (failure.staleView || failure == BoardingFailure.invalidQr) {
        unawaited(load());
      }
    } finally {
      if (mounted) setState(() => busySeatId = null);
    }
  }

  void _replaceRow(String seatAssignmentId, BoardingEvent event) {
    final current = rows;
    if (current == null) return;
    rows = [
      for (final row in current)
        row.seatAssignmentId == seatAssignmentId ? row.withEvent(event) : row,
    ];
  }

  Future<void> openShuttleQr() async {
    await context.push(
      BusinessRoutes.shuttleQrLocation(
        widget.shuttleId,
        name: widget.shuttleName,
      ),
    );
  }

  /// Tarama ekranından dönünce liste yeniden okunur: okutulan binişler
  /// sunucuda.
  Future<void> openScanner() async {
    await context.push(
      BusinessRoutes.shuttleScanLocation(
        widget.shuttleId,
        name: widget.shuttleName,
      ),
    );
    if (mounted) unawaited(load());
  }
}
