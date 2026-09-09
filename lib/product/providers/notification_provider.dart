import 'package:flutter/material.dart';
import 'package:koala/product/models/app_notification.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/services/notification_service.dart';

/// Bildirim akışı. İki uygulama da aynı sağlayıcıyı okuyor.
///
/// Akışın kendisi sayfalı; okunmamış sayısı sayfadan **türetilmiyor**,
/// sunucu ayrıca gönderiyor. İlk sayfada okunmamış görünmese bile rozette
/// sayı olabilir.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    NotificationService? service,
    SessionManager? sessionManager,
  }) : _service = service ?? NotificationService(),
       _sessionManager = sessionManager ?? SessionManager() {
    _sessionManager.addListener(_handleSessionChange);
  }

  /// Sayfa başına kayıt. Sunucunun varsayılanıyla aynı.
  static const int _pageSize = 20;

  final NotificationService _service;
  final SessionManager _sessionManager;

  final List<AppNotification> _notifications = [];

  int _unreadCount = 0;
  int _page = 0;
  bool _isLast = true;

  /// Bir ilk-sayfa isteği uçuyor mu. [_isLoading]'den ayrı tutuluyor:
  /// sessiz yükleme göstergeyi açmıyor ama yine de tek başına uçmalı.
  /// İkisini tek bayrakta toplayınca sessiz yol korumasız kalıyor ve iki
  /// yükleme listeyi birlikte yeniden kuruyordu.
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

  /// Akış bir kez çekilmişse tekrar çekmez.
  ///
  /// Zil rozetinin sayıyı bilmesi için akışın okunmuş olması gerekiyor, ama
  /// zil her ekran çiziminde istek atmamalı — okunmamış sayısı bildirim
  /// ekranı açılıp kapandığında zaten tazeleniyor.
  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isFetching) return;
    await load(silent: true);
  }

  /// İlk sayfayı çeker; yenilemede de bu çağrılıyor.
  ///
  /// [silent] verildiğinde yükleniyor göstergesi açılmıyor — ekrana her
  /// dönüşte listenin boşalıp yeniden dolması göz yoruyor.
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

  /// Sonraki sayfayı listenin sonuna ekler.
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
      // Sayfa eklenemedi diye eldeki liste silinmiyor; kullanıcı okumaya
      // devam edebilsin.
      if (generation == _generation) _errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Tek bir bildirimi okundu işaretler.
  ///
  /// Liste **elde** güncelleniyor, yeniden çekilmiyor: kullanıcı satıra
  /// dokunup gidiyor, dönüşte listenin baştan kurulması için beklemesin.
  /// Çağrı düşerse rozet olduğu gibi kalıyor; okunmamışı okundu göstermek
  /// yanlış tarafa hata yapmak olurdu.
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

    // İşaretleme uçuşurken ilk sayfa yenilenmiş olabilir. Eski sayısal indeks
    // artık başka bir bildirime ait olabilir; hedefi güncel listede yeniden
    // bulmadan hiçbir satıra ve sayaca dokunma.
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

  /// Hepsini okundu işaretler. Başarılıysa `true` döner.
  ///
  /// Tek tek işaretlemek için [markRead] var; bu, listedeki her şeyi
  /// birden kapatıyor. Yanıt kaç kaydın işaretlendiğini söylüyor; sıfır
  /// dönmesi hata değil, "zaten hepsi okunmuştu" demek.
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

  /// Çıkışta önceki hesabın bildirimleri sonraki oturumda görünmesin.
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
    // SessionManager, ApiClient'in zorunlu oturum sonlandırmasının da tek
    // sınırı. `start` router'ı erken tetiklememek için bildirim atmadığından
    // burada yalnız çıkış durumuna bakmak, bütün end yollarını kapsıyor.
    if (!_sessionManager.isLoggedIn) clear();
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_handleSessionChange);
    super.dispose();
  }
}
