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

/// Oturum sahibinin kimliği; bulunamazsa `null`.
typedef BoardingUserIdResolver = Future<String?> Function();

/// Okutmanın ilk gönderim sonucu.
sealed class BoardingSubmission {
  const BoardingSubmission();
}

/// Sunucu kaydetti (ya da kayıt zaten vardı: `replayed`).
class BoardingRecorded extends BoardingSubmission {
  const BoardingRecorded(this.event);

  final BoardingEvent event;
}

/// Sunucuya ulaşılamadı; okutma cihazda saklandı, bağlantı gelince
/// gönderilecek.
class BoardingQueued extends BoardingSubmission {
  const BoardingQueued();
}

/// Sunucu reddetti; kuyrukta tutulmuyor, ekran nedenini söyler ve işçi
/// yeniden okutabilir.
class BoardingRejected extends BoardingSubmission {
  const BoardingRejected(this.failure, {this.serverMessage});

  final BoardingFailure failure;
  final String? serverMessage;
}

/// İşçinin servis QR'ı okutmalarının çevrimdışı kuyruğu (is-koala/koala#217).
///
/// Şantiyede çekmeyen telefon binişini kaybetmesin diye: okutma
/// `clientEventId` + `capturedAt` ile saklanır, hemen bir kez denenir;
/// bağlantı yoksa açılışta, uygulama öne gelince ve ağ dönünce yeniden
/// gönderilir. Sunucu `replayed` ve `LATE_SYNC` ile döndüğünde de başarıdır.
/// Ret bir daha denenmez: kayıt "işverenden işaretlemesini isteyin" diye
/// kartta kalır, kullanıcı kapatınca silinir.
///
/// Mesai kuyruğuyla ([TimesheetQueueProvider]) aynı kalıp: `lazy: false`
/// kayıtlı, oturum değişince son kullanıcıyı açıyor ya da duraklıyor.
class BoardingQueueProvider extends ChangeNotifier with WidgetsBindingObserver {
  BoardingQueueProvider()
    : this.withAdapters(
        store: const SharedPreferencesBoardingQueueStore(),
        gateway: TransportBoardingGateway(),
        retryTrigger: ConnectivityTimesheetRetryTrigger(),
        sessionManager: SessionManager(),
        currentUserId: _fetchCurrentUserId,
      );

  /// Yeniden girişte oturum sahibini `/users/me`'den okur; çevrimdışıysa
  /// `null` ve kuyruk son etkin kullanıcıya düşer.
  static Future<String?> _fetchCurrentUserId() async {
    try {
      return (await UserService().fetchCurrentUser()).id;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  BoardingQueueProvider.withAdapters({
    required BoardingQueueStore store,
    required BoardingGateway gateway,
    required TimesheetRetryTrigger retryTrigger,
    BoardingUtcNow? utcNow,
    BoardingEventIdFactory? eventIdFactory,
    SessionManager? sessionManager,
    BoardingUserIdResolver? currentUserId,
  }) : _store = store,
       _gateway = gateway,
       _utcNow = utcNow ?? DateTime.now,
       _eventIdFactory = eventIdFactory ?? newBoardingClientEventId,
       _sessionManager = sessionManager,
       _currentUserId = currentUserId {
    WidgetsBinding.instance.addObserver(this);
    _retrySubscription = retryTrigger.onNetworkAvailable.listen((_) {
      _schedule(flush);
    });
    _sessionManager?.addListener(_onSessionChanged);
  }

  /// Bu yaştan eski kayıt açılışta atılır: sunucu geç yüklemeyi en fazla 12
  /// saat, cihaz saatini en fazla 72 saat geriye kabul ediyor; daha eskisi
  /// hiçbir koşulda kaydedilemez, kartta sonsuza dek durmasın.
  static const Duration maxAge = Duration(hours: 72);

  final BoardingQueueStore _store;
  final BoardingGateway _gateway;
  final BoardingUtcNow _utcNow;
  final BoardingEventIdFactory _eventIdFactory;
  final SessionManager? _sessionManager;
  final BoardingUserIdResolver? _currentUserId;
  late final StreamSubscription<void> _retrySubscription;

  /// Depodaki oku-değiştir-yaz işlemlerinin sırası. Okutma, teslim, ret
  /// ve kapatma aynı listeyi yazıyor; araya giren ikinci yazım birinin
  /// değişikliğini silmesin diye hepsi bu zincirin ucuna ekleniyor.
  Future<void> _storeTail = Future.value();

  bool _isDisposed = false;
  String? _activeUserId;
  List<PendingBoarding> _entries = const [];
  Future<void>? _flushFuture;
  bool _flushAgain = false;
  int _generation = 0;
  int _deliveryRevision = 0;

  /// Şu an gönderilmekte olan kayıtlar; [submit]'in ilk denemesi ile arka
  /// plan boşaltması aynı kaydı iki kez yollamasın.
  final Set<String> _inFlight = {};

  String? get activeUserId => _activeUserId;

  /// Etkin kullanıcının kayıtları.
  List<PendingBoarding> get entries => List.unmodifiable(_entries);

  /// Arka planda bir kayıt teslim edildikçe artar; iş detayı biniş
  /// durumunu yeniden okumak için buna bakar.
  int get deliveryRevision => _deliveryRevision;

  /// Kartın gösterdiği kayıtlar: iş detayından o atama ve yön için
  /// okutulanlar **ve** telefon kamerasıyla (bağlantıdan) okutulup atamayı
  /// bilmeyen, ama koltuğun servisine ([shuttleId]) ait olanlar.
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

  /// Arka plan başlatması: hata yakalanır, PII'siz tek satır yazılır.
  Future<bool> tryStartForUser(String userId) async {
    try {
      await startForUser(userId);
      return true;
    } catch (_) {
      _reportBackgroundFailure();
      return false;
    }
  }

  /// Profil isteği çevrimdışıyken de önceki oturumun kuyruğunu açar.
  Future<void> resumeLastUser() async {
    if (_isDisposed || _activeUserId != null) return;
    final userId = await _store.readLastActiveUser();
    if (_isDisposed || userId == null || _activeUserId != null) return;
    final generation = ++_generation;
    _activeUserId = userId;
    await _reload(generation);
    await flush();
  }

  /// Oturum kapandı: bellekteki görünüm boşalır. Kayıtlar diskte kalır;
  /// aynı kullanıcı yeniden girince gönderilir.
  Future<void> pause() async {
    if (_isDisposed) return;
    _generation++;
    _activeUserId = null;
    _entries = const [];
    await _store.setLastActiveUser(null);
    if (!_isDisposed) notifyListeners();
  }

  /// Çalışan oturumu açıldı (açılış ya da yeniden giriş): oturum sahibi
  /// okunabiliyorsa onun kuyruğu açılır ve boşaltılır; okunamıyorsa
  /// (çevrimdışı açılış) son etkin kullanıcıya düşülür. Çıkışta [pause]
  /// son kullanıcıyı sildiği için başka biri girdiğinde önceki kişinin
  /// okutmaları onun oturumuyla gönderilmez.
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

  /// Hesap silme talebi: etkin kullanıcının bekleyen ve reddedilmiş
  /// okutmaları (token ve konum dahil) cihazdan silinir.
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

  /// İşçinin okuttuğu servis QR'ını kaydeder ve hemen bir kez gönderir.
  ///
  /// [capturedAt] okutma anı; verilmezse şimdi. Konumu çağıran, izin zaten
  /// varsa veriyor.
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
    // Kayıt diske yazılmadan önce "uçuşta" işaretleniyor: araya giren bir
    // boşaltma onu görüp ikinci kez göndermesin.
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

  /// Reddedilmiş kaydı kullanıcı kapattı.
  Future<void> dismiss(String clientEventId) =>
      _remove(clientEventId, _generation);

  /// Açılış, resume, ağ dönüşü ve yeni okutma aynı tek-uçuş yolunu
  /// kullanır.
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
        // Bağlantı yoksa sıradakileri denemenin anlamı yok.
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

  /// Bağlantı, sunucu hatası, hız sınırı ve oturumun yenilenememesi geçici:
  /// okutma kuyrukta kalır.
  static bool _keepsForRetry(ApiException error, BoardingFailure failure) =>
      failure.isRetryable || error.type == ApiErrorType.unauthenticated;

  /// Depodaki listeyi sıraya girerek okur, [change] ile değiştirip yazar
  /// ve yazılan listeyi döndürür. Bir halka hata verirse zincir kopmaz.
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

  /// Etkin kullanıcının kayıtlarını diskten okur; [maxAge]'den eskileri
  /// atar.
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
