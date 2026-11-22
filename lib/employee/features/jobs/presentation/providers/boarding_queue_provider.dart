import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:koala/employee/features/jobs/models/pending_boarding.dart';
import 'package:koala/employee/features/jobs/services/boarding_queue_store.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/jobs/services/timesheet_retry_trigger.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';

typedef BoardingUtcNow = DateTime Function();
typedef BoardingEventIdFactory = String Function();

typedef BoardingUserIdResolver = Future<String?> Function();

sealed class BoardingSubmission {
  const BoardingSubmission();
}

/// Zaten kayıtlıysa da (`replayed`).
class BoardingRecorded extends BoardingSubmission {
  const BoardingRecorded(this.event);

  final BoardingEvent event;
}

/// Cihazda saklandı, bağlantı gelince gönderilecek.
class BoardingQueued extends BoardingSubmission {
  const BoardingQueued();
}

/// Kuyrukta tutulmaz; işçi yeniden okutabilir.
class BoardingRejected extends BoardingSubmission {
  const BoardingRejected(this.failure, {this.serverMessage});

  final BoardingFailure failure;
  final String? serverMessage;
}

/// İşçinin biniş okutmalarının çevrimdışı kuyruğu (#217): şantiyede çekmeyen
/// telefon binişini kaybetmesin. Okutma saklanıp hemen denenir; açılışta, öne
/// gelince ve ağ dönünce yeniden gönderilir. `replayed`/`LATE_SYNC` başarıdır;
/// ret yeniden denenmez, kullanıcı kapatana kadar kartta kalır.
class BoardingQueueProvider extends ChangeNotifier with WidgetsBindingObserver {
  BoardingQueueProvider()
    : this.withAdapters(
        store: const SharedPreferencesBoardingQueueStore(),
        gateway: TransportBoardingGateway(),
        retryTrigger: ConnectivityTimesheetRetryTrigger(),
        sessionManager: SessionManager(),
        currentUserId: _fetchCurrentUserId,
      );

  /// Çevrimdışıysa `null`; kuyruk son etkin kullanıcıya düşer.
  static Future<String?> _fetchCurrentUserId() async {
    try {
      return (await UserService().fetchCurrentUser()).id;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  BoardingQueueProvider.withAdapters({
    required this._store,
    required this._gateway,
    required TimesheetRetryTrigger retryTrigger,
    BoardingUtcNow? utcNow,
    BoardingEventIdFactory? eventIdFactory,
    this._sessionManager,
    this._currentUserId,
  }) : _utcNow = utcNow ?? DateTime.now,
       _eventIdFactory = eventIdFactory ?? newBoardingClientEventId {
    WidgetsBinding.instance.addObserver(this);
    _retrySubscription = retryTrigger.onNetworkAvailable.listen((_) {
      _schedule(flush);
    });
    _sessionManager?.addListener(_onSessionChanged);
  }

  /// Sunucu geç yüklemeyi 12 saat, cihaz saatini 72 saat geriye kabul ediyor;
  /// daha eskisi kaydedilemez, kartta sonsuza dek durmasın.
  static const Duration maxAge = Duration(hours: 72);

  final BoardingQueueStore _store;
  final BoardingGateway _gateway;
  final BoardingUtcNow _utcNow;
  final BoardingEventIdFactory _eventIdFactory;
  final SessionManager? _sessionManager;
  final BoardingUserIdResolver? _currentUserId;
  late final StreamSubscription<void> _retrySubscription;

  /// Depodaki oku-değiştir-yaz işlemleri tek zincirde; araya giren yazım
  /// birinin değişikliğini silmesin.
  Future<void> _storeTail = Future.value();

  bool _isDisposed = false;
  String? _activeUserId;
  List<PendingBoarding> _entries = const [];
  Future<void>? _flushFuture;
  bool _flushAgain = false;
  int _generation = 0;
  int _deliveryRevision = 0;

  /// İlk deneme ile arka plan boşaltması aynı kaydı iki kez yollamasın.
  final Set<String> _inFlight = {};

  String? get activeUserId => _activeUserId;

  List<PendingBoarding> get entries => List.unmodifiable(_entries);

  /// Arka planda teslim edildikçe artar; iş detayı biniş durumunu yeniden okur.
  int get deliveryRevision => _deliveryRevision;

  /// O atama ve yön için okutulanlar **ve** bağlantıdan okutulup koltuğun
  /// servisine ait olanlar.
  List<PendingBoarding> entriesFor(
    String assignmentId,
    ShuttleDirection direction, {
    String? shuttleId,
  }) {
    final shuttle = shuttleId?.toLowerCase();
    return _entries
        .where(
          (entry) => entry.assignmentId == null
              ? shuttle != null && entry.shuttleId.toLowerCase() == shuttle
              : entry.assignmentId == assignmentId &&
                    entry.direction == direction,
        )
        .toList(growable: false);
  }

  Future<void> startForUser(String userId) async {
    if (_isDisposed) return;
    final generation = ++_generation;
    _activeUserId = userId;
    await _store.setLastActiveUser(userId);
    await _reload(generation);
    await flush();
  }

  /// Hata yakalanır, PII'siz tek satır yazılır.
  Future<bool> tryStartForUser(String userId) async {
    try {
      await startForUser(userId);
      return true;
    } catch (_) {
      _reportBackgroundFailure();
      return false;
    }
  }

  Future<void> resumeLastUser() async {
    if (_isDisposed || _activeUserId != null) return;
    final userId = await _store.readLastActiveUser();
    if (_isDisposed || userId == null || _activeUserId != null) return;
    final generation = ++_generation;
    _activeUserId = userId;
    await _reload(generation);
    await flush();
  }

  /// Kayıtlar diskte kalır; aynı kullanıcı girince gönderilir.
  Future<void> pause() async {
    if (_isDisposed) return;
    _generation++;
    _activeUserId = null;
    _entries = const [];
    await _store.setLastActiveUser(null);
    if (!_isDisposed) notifyListeners();
  }

  /// Çalışan oturumu açıldı: oturum sahibinin kuyruğu açılıp boşaltılır;
  /// çevrimdışıysa son etkin kullanıcıya düşülür. [pause] son kullanıcıyı
  /// sildiği için başkasının okutmaları yanlış oturumla gönderilmez.
  Future<void> resumeForSession() async {
    if (_isDisposed || _activeUserId != null) return;
    final resolver = _currentUserId;
    final userId = resolver == null ? null : await resolver();
    if (_isDisposed || _activeUserId != null) return;
    if (userId != null) {
      await startForUser(userId);
      return;
    }
    await resumeLastUser();
  }

  /// Etkin kullanıcının okutmaları (token ve konum dahil) cihazdan silinir.
  Future<void> purgeActiveUser() async {
    final userId = _activeUserId;
    if (_isDisposed || userId == null) return;
    await _mutate(
      (stored) => stored.where((entry) => entry.userId != userId).toList(),
    );
    await _reload(_generation);
  }

  void _onSessionChanged() {
    final session = _sessionManager;
    if (_isDisposed || session == null || !session.isInitialized) return;
    if (session.isLoggedIn && session.userType == SessionManager.employeeType) {
      _schedule(resumeForSession);
      return;
    }
    _schedule(pause);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule(flush);
  }

  /// Okutmayı kaydedip hemen bir kez gönderir. Konumu çağıran, izin zaten varsa
  /// verir.
  Future<BoardingSubmission> submit({
    required BoardingToken token,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    String? assignmentId,
    ShuttleDirection? direction,
  }) async {
    assert(token.kind == BoardingTokenKind.shuttle);
    if (_isDisposed) throw StateError('Biniş kuyruğu kapatıldı.');
    final userId = _activeUserId;
    if (userId == null) {
      throw StateError('Biniş kuyruğu kullanıcı oturumu için hazır değil.');
    }
    final hasPosition = latitude != null && longitude != null;
    final entry = PendingBoarding(
      clientEventId: _eventIdFactory(),
      userId: userId,
      shuttleId: token.subjectId,
      token: token.value,
      capturedAt: (capturedAt ?? _utcNow()).toUtc(),
      latitude: hasPosition ? latitude : null,
      longitude: hasPosition ? longitude : null,
      assignmentId: assignmentId,
      direction: direction,
    );

    final generation = _generation;
    // Diske yazılmadan "uçuşta" işaretlenir; araya giren boşaltma ikinci kez
    // göndermesin.
    _inFlight.add(entry.clientEventId);
    try {
      await _mutate((stored) => [...stored, entry]);
      await _reload(generation);

      final event = await _gateway.send(entry);
      await _remove(entry.clientEventId, generation);
      return BoardingRecorded(event);
    } on ApiException catch (error) {
      final failure = BoardingFailure.classify(error);
      if (_keepsForRetry(error, failure)) return const BoardingQueued();
      await _remove(entry.clientEventId, generation);
      return BoardingRejected(failure, serverMessage: error.message);
    } finally {
      _inFlight.remove(entry.clientEventId);
    }
  }

  Future<void> dismiss(String clientEventId) =>
      _remove(clientEventId, _generation);

  /// Bütün tetikleyiciler aynı tek-uçuş yolunu kullanır.
  Future<void> flush() {
    if (_isDisposed || _activeUserId == null) return Future.value();
    _flushAgain = true;
    final running = _flushFuture;
    if (running != null) return running;

    final future = _drain();
    _flushFuture = future;
    return future.whenComplete(() {
      if (identical(_flushFuture, future)) _flushFuture = null;
    });
  }

  Future<void> _drain() async {
    while (_flushAgain && !_isDisposed) {
      _flushAgain = false;
      final generation = _generation;
      await _reload(generation);
      if (_isDisposed || generation != _generation) return;

      for (final entry in List.of(_entries)) {
        if (_isDisposed || generation != _generation) return;
        if (entry.isFailed || _inFlight.contains(entry.clientEventId)) {
          continue;
        }
        final canContinue = await _deliver(entry, generation);
        if (!canContinue) break;
      }
    }
  }

  Future<bool> _deliver(PendingBoarding entry, int generation) async {
    _inFlight.add(entry.clientEventId);
    try {
      await _gateway.send(entry);
      if (generation != _generation) return false;
      await _remove(entry.clientEventId, generation);
      _deliveryRevision++;
      if (!_isDisposed) notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (generation != _generation) return false;
      final failure = BoardingFailure.classify(error);
      if (_keepsForRetry(error, failure)) return false;
      await _replace(entry.asFailed(failure), generation);
      return true;
    } finally {
      _inFlight.remove(entry.clientEventId);
    }
  }

  /// Bağlantı, sunucu hatası, hız sınırı ve oturum yenilenememesi geçici.
  static bool _keepsForRetry(ApiException error, BoardingFailure failure) =>
      failure.isRetryable || error.type == ApiErrorType.unauthenticated;

  /// Bir halka hata verse de zincir kopmaz.
  Future<List<PendingBoarding>> _mutate(
    List<PendingBoarding> Function(List<PendingBoarding> stored) change,
  ) {
    final result = _storeTail.then((_) async {
      final stored = await _store.readAll();
      final changed = change(stored);
      if (!identical(changed, stored)) await _store.writeAll(changed);
      return changed;
    });
    _storeTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _remove(String clientEventId, int generation) async {
    await _mutate(
      (stored) => stored
          .where((entry) => entry.clientEventId != clientEventId)
          .toList(),
    );
    await _reload(generation);
  }

  Future<void> _replace(PendingBoarding updated, int generation) async {
    await _mutate(
      (stored) => [
        for (final entry in stored)
          entry.clientEventId == updated.clientEventId ? updated : entry,
      ],
    );
    await _reload(generation);
  }

  Future<void> _reload(int generation) async {
    if (_isDisposed) return;
    final userId = _activeUserId;
    final oldest = _utcNow().toUtc().subtract(maxAge);
    final fresh = await _mutate((stored) {
      final kept = stored
          .where((entry) => entry.capturedAt.isAfter(oldest))
          .toList();
      return kept.length == stored.length ? stored : kept;
    });
    if (_isDisposed || generation != _generation || userId != _activeUserId) {
      return;
    }
    _entries = fresh.where((entry) => entry.userId == userId).toList();
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
    // Hata metni token ya da konum taşıyabilir; yalnız sabit mesaj.
    debugPrint('Biniş kuyruğu arka plan işlemi tamamlanamadı.');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;
    _activeUserId = null;
    _entries = const [];
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager?.removeListener(_onSessionChanged);
    unawaited(_retrySubscription.cancel());
    super.dispose();
  }
}
