import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_gateway.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_store.dart';
import 'package:koala/employee/features/jobs/services/timesheet_retry_trigger.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';

typedef TimesheetUtcNow = DateTime Function();
typedef TimesheetMonotonicNow = int Function();
typedef TimesheetEventIdFactory = String Function();

final Stopwatch _processClock = Stopwatch()..start();

/// Çevrimdışı mesai olayının kalıcılık, sıra ve uzlaştırma modülü.
class TimesheetQueueProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  TimesheetQueueProvider()
    : this.withAdapters(
        store: SqfliteTimesheetEventStore(),
        gateway: AssignmentTimesheetEventGateway(),
        retryTrigger: ConnectivityTimesheetRetryTrigger(),
        sessionManager: SessionManager(),
      );

  @visibleForTesting
  TimesheetQueueProvider.withAdapters({
    required TimesheetEventStore store,
    required TimesheetEventGateway gateway,
    required TimesheetRetryTrigger retryTrigger,
    TimesheetUtcNow? utcNow,
    TimesheetMonotonicNow? monotonicNow,
    TimesheetEventIdFactory? eventIdFactory,
    SessionManager? sessionManager,
  }) : _store = store,
       _gateway = gateway,
       _retryTrigger = retryTrigger,
       _utcNow = utcNow ?? DateTime.now,
       _monotonicNow =
           monotonicNow ?? (() => _processClock.elapsedMicroseconds),
       _eventIdFactory = eventIdFactory ?? _newEventId,
       _sessionManager = sessionManager {
    WidgetsBinding.instance.addObserver(this);
    _retrySubscription = _retryTrigger.onNetworkAvailable.listen((_) {
      _schedule(flush);
    });
    _sessionManager?.addListener(_onSessionChanged);
  }

  static const String _conflictMessage =
      'Mesai kaydı sunucudaki durumla uzlaştırılamadı. Destekle iletişime geç.';
  static const String _permanentFailureMessage =
      'Mesai kaydı sunucu tarafından kabul edilmedi. Destekle iletişime geç.';

  final TimesheetEventStore _store;
  final TimesheetEventGateway _gateway;
  final TimesheetRetryTrigger _retryTrigger;
  final TimesheetUtcNow _utcNow;
  final TimesheetMonotonicNow _monotonicNow;
  final TimesheetEventIdFactory _eventIdFactory;
  final SessionManager? _sessionManager;
  late final StreamSubscription<void> _retrySubscription;
  bool _isDisposed = false;
  Future<void>? _retryCancellation;

  String? _activeUserId;
  List<TimesheetEvent> _events = const [];
  Future<void>? _flushFuture;
  bool _flushAgain = false;
  int _generation = 0;
  int _deliveryRevision = 0;
  TimesheetEvent? _lastDeliveredEvent;

  List<TimesheetEvent> get events => List.unmodifiable(_events);
  String? get activeUserId => _activeUserId;
  int get deliveryRevision => _deliveryRevision;
  TimesheetEvent? get lastDeliveredEvent => _lastDeliveredEvent;

  /// Son teslim bilgisini, sayfa olaydan sonra bağlansa bile, tam bir kez
  /// gösterebilmesi için tüketir.
  TimesheetEvent? takeDeliveryAcknowledgement() {
    final event = _lastDeliveredEvent;
    _lastDeliveredEvent = null;
    return event;
  }

  Future<void> startForUser(String userId) async {
    if (_isDisposed) return;
    final generation = ++_generation;
    _activeUserId = userId;
    try {
      await _store.setLastActiveUser(userId);
      await _reload(userId, generation);
      await flush();
    } catch (_) {
      if (!_isDisposed && generation == _generation) {
        _activeUserId = null;
        _events = const [];
      }
      rethrow;
    }
  }

  /// UI/lifecycle başlatmasının yakalanmayan async hataya dönüşmesini
  /// engeller. Etkileşimli kayıt yolu, kullanıcıya hata gösterebilmek için
  /// [startForUser] üzerinden hatayı yükseltmeye devam eder.
  Future<bool> tryStartForUser(String userId) async {
    if (_isDisposed) return false;
    try {
      await startForUser(userId);
      return true;
    } catch (_) {
      _reportBackgroundFailure();
      return false;
    }
  }

  /// Profil isteği çevrimdışıyken de önceki oturumun kalıcı kuyruğunu açar.
  Future<void> resumeLastUser() async {
    if (_isDisposed) return;
    final userId = await _store.readLastActiveUser();
    if (_isDisposed || userId == null || _activeUserId != null) return;
    final generation = ++_generation;
    _activeUserId = userId;
    await _reload(userId, generation);
    await flush();
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    _generation++;
    _activeUserId = null;
    _events = const [];
    _lastDeliveredEvent = null;
    await _store.setLastActiveUser(null);
    if (!_isDisposed) notifyListeners();
  }

  void _onSessionChanged() {
    final session = _sessionManager;
    if (_isDisposed || session == null || !session.isInitialized) return;
    if (session.isLoggedIn && session.userType == SessionManager.employeeType) {
      _schedule(resumeLastUser);
      return;
    }
    _schedule(pause);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule(flush);
  }

  List<TimesheetEvent> eventsForAssignment(String assignmentId) => _events
      .where((event) => event.assignmentId == assignmentId)
      .toList(growable: false);

  Future<TimesheetSubmission> recordCheckIn({
    required String assignmentId,
    double? latitude,
    double? longitude,
  }) => _record(
    assignmentId: assignmentId,
    action: TimesheetEventAction.checkIn,
    latitude: latitude,
    longitude: longitude,
  );

  Future<TimesheetSubmission> recordCheckOut({
    required String assignmentId,
    double? latitude,
    double? longitude,
  }) => _record(
    assignmentId: assignmentId,
    action: TimesheetEventAction.checkOut,
    latitude: latitude,
    longitude: longitude,
  );

  Future<TimesheetSubmission> _record({
    required String assignmentId,
    required TimesheetEventAction action,
    required double? latitude,
    required double? longitude,
  }) async {
    if (_isDisposed) {
      throw StateError('Mesai kuyruğu kapatıldı.');
    }
    final userId = _activeUserId;
    if (userId == null) {
      throw StateError('Mesai kuyruğu kullanıcı oturumu için hazır değil.');
    }

    final event = TimesheetEvent(
      clientEventId: _eventIdFactory(),
      userId: userId,
      assignmentId: assignmentId,
      action: action,
      capturedAt: _utcNow().toUtc(),
      monotonicMicros: _monotonicNow(),
      latitude: latitude,
      longitude: longitude,
    );
    await _store.add(event);
    await _reload(userId, _generation);
    await flush();

    final remaining = _events
        .where((item) => item.clientEventId == event.clientEventId)
        .firstOrNull;
    if (remaining == null) return TimesheetSubmission.sent;
    return remaining.requiresSupport
        ? TimesheetSubmission.requiresSupport
        : TimesheetSubmission.pending;
  }

  /// Açılış, resume, bağlantı dönüşü ve yeni olay aynı tek-uçuş yolunu kullanır.
  Future<void> flush() {
    if (_isDisposed || _activeUserId == null) return Future.value();
    _flushAgain = true;
    final running = _flushFuture;
    if (running != null) return running;

    final future = _drain();
    _flushFuture = future;
    return future.whenComplete(() {
      if (identical(_flushFuture, future)) {
        _flushFuture = null;
        if (!_isDisposed) notifyListeners();
      }
    });
  }

  Future<void> _drain() async {
    while (_flushAgain && !_isDisposed) {
      _flushAgain = false;
      final userId = _activeUserId;
      final generation = _generation;
      if (_isDisposed || userId == null) return;

      await _reload(userId, generation);
      if (_isDisposed || generation != _generation) return;

      final blockedAssignments = <String>{};
      for (final event in _events) {
        if (_isDisposed || generation != _generation) return;
        if (event.requiresSupport) {
          blockedAssignments.add(event.assignmentId);
          continue;
        }
        if (blockedAssignments.contains(event.assignmentId)) {
          continue;
        }

        final canContinue = await _deliver(event, generation);
        if (!canContinue) blockedAssignments.add(event.assignmentId);
      }

      await _reload(userId, generation);
    }
  }

  Future<bool> _deliver(TimesheetEvent event, int generation) async {
    try {
      await _gateway.send(event);
      if (generation != _generation) return false;
      // Makullük bayrakları ret değil, sunucuda kalıcılaştırılmış bir
      // inceleme işaretidir. Başarılı 2xx olayı kuyrukta bırakmak aynı
      // atamanın sonraki check-in/check-out olaylarını sonsuza dek kilitler.
      // Sayfa modeli teslim revizyonuyla oturumları yeniden yükleyip sunucudaki
      // bayraklı kaydı görür.
      await _acknowledge(event);
      return true;
    } on ApiException catch (error) {
      if (generation != _generation) return false;
      // İki çakışma kategorisi de "sunucudaki hâl kuyruktakinden farklı"
      // demek; olayı kuyrukta kilitli bırakmamak için ikisi de uzlaştırmaya
      // gidiyor.
      if (error.type.isConflict) {
        if (error.errorCode == 'TIMESHEET_IDEMPOTENCY_CONFLICT') {
          await _store.markRequiresSupport(
            event.clientEventId,
            _conflictMessage,
          );
          return false;
        }
        return _reconcileConflict(event, generation);
      }
      if (error.type == ApiErrorType.validation ||
          error.type == ApiErrorType.notFound) {
        await _store.markRequiresSupport(
          event.clientEventId,
          _permanentFailureMessage,
        );
      }
      return false;
    }
  }

  Future<bool> _reconcileConflict(TimesheetEvent event, int generation) async {
    try {
      final sessions = await _gateway.fetchSessions(event.assignmentId);
      if (generation != _generation) return false;
      final matching = sessions
          .where((session) => _matchesEvent(session, event))
          .firstOrNull;

      if (matching == null) {
        await _store.markRequiresSupport(event.clientEventId, _conflictMessage);
        return false;
      }
      await _acknowledge(event);
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> _acknowledge(TimesheetEvent event) async {
    await _store.remove(event.clientEventId);
    if (_isDisposed) return;
    _lastDeliveredEvent = event;
    _deliveryRevision++;
  }

  bool _matchesEvent(WorkSession session, TimesheetEvent event) {
    final (eventId, capturedAt, latitude, longitude) = switch (event.action) {
      TimesheetEventAction.checkIn => (
        session.checkInClientEventId,
        session.checkInCapturedAt,
        session.checkInLatitude,
        session.checkInLongitude,
      ),
      TimesheetEventAction.checkOut => (
        session.checkOutClientEventId,
        session.checkOutCapturedAt,
        session.checkOutLatitude,
        session.checkOutLongitude,
      ),
    };

    return eventId == event.clientEventId &&
        capturedAt?.toUtc() == event.capturedAt.toUtc() &&
        _normalizedCoordinate(latitude) ==
            _normalizedCoordinate(event.latitude) &&
        _normalizedCoordinate(longitude) ==
            _normalizedCoordinate(event.longitude);
  }

  int? _normalizedCoordinate(double? value) =>
      value == null ? null : (value * 1000000).round();

  Future<void> _reload(String userId, int generation) async {
    if (_isDisposed) return;
    final loaded = await _store.readForUser(userId);
    if (_isDisposed || generation != _generation || userId != _activeUserId) {
      return;
    }
    _events = loaded;
    notifyListeners();
  }

  void _schedule(Future<void> Function() operation) {
    if (_isDisposed) return;
    unawaited(_runBackground(operation));
  }

  Future<void> _runBackground(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      if (_isDisposed) return;
      _reportBackgroundFailure();
    }
  }

  void _reportBackgroundFailure() {
    // SQLite hata metni sorgu argümanlarını (kullanıcı kimliği/konum)
    // içerebilir. Arka plan sınırında yalnız sabit, PII'siz mesaj yaz.
    debugPrint('Mesai kuyruğu arka plan işlemi tamamlanamadı.');
  }

  void _beginDispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation++;
    _activeUserId = null;
    _events = const [];
    _lastDeliveredEvent = null;
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager?.removeListener(_onSessionChanged);
  }

  Future<void> _cancelRetrySubscription() {
    return _retryCancellation ??= _retrySubscription.cancel();
  }

  @visibleForTesting
  Future<void> disposeAsync() {
    _beginDispose();
    return _cancelRetrySubscription();
  }

  @override
  void dispose() {
    _beginDispose();
    unawaited(_cancelRetrySubscription());
    super.dispose();
  }

  static String _newEventId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
