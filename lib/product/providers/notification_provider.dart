import 'package:material_ui/material_ui.dart';
import 'package:koala/product/models/app_notification.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/services/notification_service.dart';

/// Bildirim akışı; iki uygulama okuyor. Okunmamış sayısı sayfadan türemiyor,
/// sunucu ayrıca gönderiyor.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    NotificationService? service,
    SessionManager? sessionManager,
  }) : _service = service ?? NotificationService(),
       _sessionManager = sessionManager ?? SessionManager() {
    _sessionManager.addListener(_handleSessionChange);
  }

  static const int _pageSize = 20;

  final NotificationService _service;
  final SessionManager _sessionManager;

  final List<AppNotification> _notifications = [];

  int _unreadCount = 0;
  int _page = 0;
  bool _isLast = true;

  /// İlk sayfa isteği uçuyor mu; [_isLoading]'den ayrı, çünkü sessiz yükleme de
  /// tek başına uçmalı.
  bool _isFetching = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isMarkingRead = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  int _generation = 0;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _unreadCount;

  bool get hasUnread => _unreadCount > 0;

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get isMarkingRead => _isMarkingRead;

  bool get hasMore => !_isLast;

  String? get errorMessage => _errorMessage;

  /// Bir kez çekilmişse tekrar çekmez; zil her çizimde istek atmasın.
  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isFetching) return;
    await load(silent: true);
  }

  /// Daha önce çekildiyse göstergesiz yeniler; ön plana dönüşte çağrılıyor
  /// (rozet için canlı kanal yok). Hiç çekilmediyse başlatmaz, oturum yokken
  /// istek atılmasın.
  Future<void> refreshQuietly() async {
    if (!_hasLoaded || _isFetching) return;
    await load(silent: true);
  }

  /// İlk sayfayı çeker. [silent] göstergeyi açmaz.
  Future<void> load({bool silent = false}) async {
    if (_isFetching) return;

    final generation = _generation;
    _isFetching = true;
    _isLoading = !silent;
    _errorMessage = null;
    if (!silent) notifyListeners();

    try {
      final feed = await _service.fetchFeed(page: 0, size: _pageSize);
      if (generation != _generation) return;

      _notifications
        ..clear()
        ..addAll(feed.notifications);
      _unreadCount = feed.unreadCount;
      _page = feed.page;
      _isLast = feed.last;
      _hasLoaded = true;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        _isFetching = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isFetching || _isLast) return;

    final generation = _generation;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final feed = await _service.fetchFeed(page: _page + 1, size: _pageSize);
      if (generation != _generation) return;

      _notifications.addAll(feed.notifications);
      _unreadCount = feed.unreadCount;
      _page = feed.page;
      _isLast = feed.last;
    } on ApiException catch (error) {
      // Eldeki liste silinmiyor, okumaya devam edilebilsin.
      if (generation == _generation) _errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Okundu işaretler ve listeyi yerelde günceller. Çağrı düşerse rozet olduğu
  /// gibi kalır; okunmamışı okundu göstermek yanlış yöne hata olur.
  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );
    if (index == -1 || _notifications[index].isRead) return;
    final generation = _generation;

    try {
      await _service.markRead(notificationId);
    } on ApiException catch (error) {
      if (generation == _generation) {
        _errorMessage = error.message;
        notifyListeners();
      }
      return;
    }
    if (generation != _generation) return;

    // Bu arada liste yenilenmiş olabilir; hedef güncel listede yeniden
    // bulunmalı.
    final currentIndex = _notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );
    if (currentIndex == -1 || _notifications[currentIndex].isRead) return;

    _notifications[currentIndex] = _notifications[currentIndex].copyWithRead(
      DateTime.now(),
    );
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();
  }

  /// Hepsini okundu işaretler; başarılıysa `true`.
  Future<bool> markAllRead() async {
    if (_isMarkingRead || !hasUnread) return false;

    final generation = _generation;
    _isMarkingRead = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.markAllRead();
      if (generation != _generation) return false;
      await load(silent: true);
      return generation == _generation;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = error.message;
      return false;
    } finally {
      if (generation == _generation) {
        _isMarkingRead = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    _notifications.clear();
    _unreadCount = 0;
    _page = 0;
    _isLast = true;
    _isFetching = false;
    _isLoading = false;
    _isLoadingMore = false;
    _isMarkingRead = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _handleSessionChange() {
    // `SessionManager` zorunlu çıkışın da tek sınırı; çıkış durumuna bakmak
    // bütün `end` yollarını kapsıyor.
    if (!_sessionManager.isLoggedIn) clear();
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_handleSessionChange);
    super.dispose();
  }
}
