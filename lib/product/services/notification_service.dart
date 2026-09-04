import 'package:flutter/foundation.dart';
import 'package:koala/product/models/app_notification.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Bildirim uçları.
///
/// İki uygulama da aynı akışı okuyor — çalışanın başvurusu cevaplandığında
/// da, işverene aday geldiğinde de kayıt aynı yere düşüyor. Bu yüzden
/// servis `product/` altında.
///
/// Akış yalnızca `IN_APP` kanalını döndürüyor; e-posta ve push kayıtları
/// sunucuda gönderim kaydı olarak duruyor ama listeye girmiyor. Push'u
/// cihaza düşürmek ayrı bir iş ve bugün sunucuda da yapılandırılmamış.
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

  /// Bildirim akışı, yeniden eskiye.
  ///
  /// Okunmamış sayısı sayfayla birlikte geliyor, ayrı bir çağrı gerekmiyor.
  Future<NotificationFeed> fetchFeed({int page = 0, int size = 20}) {
    return _apiClient.get<NotificationFeed>(
      ApiPaths.currentUserNotifications,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => NotificationFeed.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Tek bir bildirimi okundu işaretler.
  ///
  /// Zaten okunmuş ya da başkasına ait bir bildirimde sunucu sessizce
  /// geçiyor — hata dönmüyor, yani çağıran ayrı bir durum ele almıyor.
  Future<void> markRead(String notificationId) {
    return _apiClient.postWithoutData(
      ApiPaths.currentUserNotificationRead(notificationId),
    );
  }

  /// Bütün bildirimleri okundu işaretler ve kaç tanesinin işaretlendiğini
  /// döndürür.
  ///
  /// Tek tek işaretleyen bir uç **yok**; sunucu yalnızca toptan işaretlemeyi
  /// destekliyor. Zaten hepsi okunmuşsa `0` dönüyor, hata değil.
  Future<int> markAllRead() {
    return _apiClient.post<int>(
      ApiPaths.currentUserNotificationsRead,
      parse: (data) => (data as num?)?.toInt() ?? 0,
    );
  }
}
