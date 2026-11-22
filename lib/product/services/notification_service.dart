import 'package:flutter/foundation.dart';
import 'package:koala/product/models/app_notification.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Bildirim uçları; iki uygulama aynı akışı okuyor. Akış yalnız `IN_APP`
/// kanalını döndürüyor.
class NotificationService {
  NotificationService._(this._apiClient);

  static final NotificationService _instance = NotificationService._(
    ApiClient(),
  );

  factory NotificationService() => _instance;

  @visibleForTesting
  factory NotificationService.withClient(ApiClient apiClient) {
    return NotificationService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Yeniden eskiye; okunmamış sayısı sayfayla birlikte geliyor.
  Future<NotificationFeed> fetchFeed({int page = 0, int size = 20}) {
    return _apiClient.get<NotificationFeed>(
      ApiPaths.currentUserNotifications,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => NotificationFeed.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Zaten okunmuş ya da başkasının bildiriminde sunucu sessizce geçer.
  Future<void> markRead(String notificationId) {
    return _apiClient.postWithoutData(
      ApiPaths.currentUserNotificationRead(notificationId),
    );
  }

  /// Hepsini okundu işaretler, kaç tane olduğunu döndürür.
  Future<int> markAllRead() {
    return _apiClient.post<int>(
      ApiPaths.currentUserNotificationsRead,
      parse: (data) => (data as num?)?.toInt() ?? 0,
    );
  }
}
