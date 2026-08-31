import 'package:flutter/material.dart';
import 'package:koala/product/models/app_notification.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/notification_service.dart';

/// Bildirim akışı. İki uygulama da aynı sağlayıcıyı okuyor.
///
/// Akışın kendisi sayfalı; okunmamış sayısı sayfadan **türetilmiyor**,
/// sunucu ayrıca gönderiyor. İlk sayfada okunmamış görünmese bile rozette
/// sayı olabilir.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? service})
    : _service = service ?? NotificationService();

  /// Sayfa başına kayıt. Sunucunun varsayılanıyla aynı.
  static const int _pageSize = 20;

  final NotificationService _service;

  final List<AppNotification> _notifications = [];

  int _unreadCount = 0;
  int _page = 0;
  bool _isLast = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isMarkingRead = false;
  bool _hasLoaded = false;
  String? _errorMessage;

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
    if (_hasLoaded || _isLoading) return;
    await load(silent: true);
  }

  /// İlk sayfayı çeker; yenilemede de bu çağrılıyor.
  ///
  /// [silent] verildiğinde yükleniyor göstergesi açılmıyor — ekrana her
  /// dönüşte listenin boşalıp yeniden dolması göz yoruyor.
  Future<void> load({bool silent = false}) async {
    if (_isLoading) return;

    _isLoading = !silent;
    _errorMessage = null;
    if (!silent) notifyListeners();

    try {
      final feed = await _service.fetchFeed(page: 0, size: _pageSize);

      _notifications
        ..clear()
        ..addAll(feed.notifications);
      _unreadCount = feed.unreadCount;
      _page = feed.page;
      _isLast = feed.last;
      _hasLoaded = true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sonraki sayfayı listenin sonuna ekler.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || _isLast) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final feed = await _service.fetchFeed(page: _page + 1, size: _pageSize);

      _notifications.addAll(feed.notifications);
      _unreadCount = feed.unreadCount;
      _page = feed.page;
      _isLast = feed.last;
    } on ApiException catch (error) {
      // Sayfa eklenemedi diye eldeki liste silinmiyor; kullanıcı okumaya
      // devam edebilsin.
      _errorMessage = error.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Hepsini okundu işaretler. Başarılıysa `true` döner.
  ///
  /// Sunucuda tek bir bildirimi işaretleyen uç yok, yalnızca toptan
  /// işaretleme var. Yanıt kaç kaydın işaretlendiğini söylüyor; sıfır
  /// dönmesi hata değil, "zaten hepsi okunmuştu" demek.
  Future<bool> markAllRead() async {
    if (_isMarkingRead || !hasUnread) return false;

    _isMarkingRead = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.markAllRead();
      await load(silent: true);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isMarkingRead = false;
      notifyListeners();
    }
  }
}
