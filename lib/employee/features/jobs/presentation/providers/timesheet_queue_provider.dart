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
      unawaited(flush());
    });
    _sessionManager?.addListener(_onSessionChanged);
  }

  static const String _reviewMessage =
      'Mesai kaydı sunucu incelemesine alındı. Gerekirse destekle iletişime geç.';
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

  Future<void> startForUser(String userId) async {
    final generation = ++_generation;
    _activeUserId = userId;
    await _store.setLastActiveUser(userId);
    await _reload(userId, generation);
    await flush();
  }

  /// Profil isteği çevrimdışıyken de önceki oturumun kalıcı kuyruğunu açar.
  Future<void> resumeLastUser() async {
    final userId = await _store.readLastActiveUser();
    if (userId == null || _activeUserId != null) return;
    final generation = ++_generation;
    _activeUserId = userId;
    await _reload(userId, generation);
    await flush();
  }

  Future<void> pause() async {
    _generation++;
    _activeUserId = null;
    _events = const [];
    _lastDeliveredEvent = null;
    await _store.setLastActiveUser(null);
    notifyListeners();
  }

  void _onSessionChanged() {
    final session = _sessionManager;
    if (session == null || !session.isInitialized) return;
    if (session.isLoggedIn && session.userType == SessionManager.employeeType) {
      unawaited(resumeLastUser());
      return;
    }
    unawaited(pause());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(flush());
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
    if (_activeUserId == null) return Future.value();
    _flushAgain = true;
    final running = _flushFuture;
    if (running != null) return running;

    final future = _drain();
    _flushFuture = future;
    return future.whenComplete(() {
      if (identical(_flushFuture, future)) {
        _flushFuture = null;
        notifyListeners();
      }
    });
  }

  Future<void> _drain() async {
    while (_flushAgain) {
      _flushAgain = false;
      final userId = _activeUserId;
      final generation = _generation;
      if (userId == null) return;

      await _reload(userId, generation);
      if (generation != _generation) return;

      final blockedAssignments = <String>{};
      for (final event in _events) {
        if (generation != _generation) return;
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
      final session = await _gateway.send(event);
      if (generation != _generation) return false;
      if (_needsReview(session, event.action)) {
        await _store.markRequiresSupport(event.clientEventId, _reviewMessage);
        return false;
      }
      await _acknowledge(event);
      return true;
    } on ApiException catch (error) {
      if (generation != _generation) return false;
      if (error.type == ApiErrorType.conflict) {
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
          .where(
            (session) => _eventId(session, event.action) == event.clientEventId,
          )
          .firstOrNull;

      if (matching == null) {
        await _store.markRequiresSupport(event.clientEventId, _conflictMessage);
        return false;
      }
      if (_needsReview(matching, event.action)) {
        await _store.markRequiresSupport(event.clientEventId, _reviewMessage);
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
    _lastDeliveredEvent = event;
    _deliveryRevision++;
  }

  String? _eventId(WorkSession session, TimesheetEventAction action) {
    return switch (action) {
      TimesheetEventAction.checkIn => session.checkInClientEventId,
      TimesheetEventAction.checkOut => session.checkOutClientEventId,
    };
  }

  bool _needsReview(WorkSession session, TimesheetEventAction action) {
    return switch (action) {
      TimesheetEventAction.checkIn => session.checkInNeedsReview,
      TimesheetEventAction.checkOut => session.checkOutNeedsReview,
    };
  }

  Future<void> _reload(String userId, int generation) async {
    final loaded = await _store.readForUser(userId);
    if (generation != _generation || userId != _activeUserId) return;
    _events = loaded;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> disposeAsync() async {
    if (_isDisposed) return;
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager?.removeListener(_onSessionChanged);
    await _retrySubscription.cancel();
  }

  @override
  void dispose() {
    unawaited(disposeAsync());
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
