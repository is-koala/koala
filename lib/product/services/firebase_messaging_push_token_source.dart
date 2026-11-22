import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:koala/product/services/push_token_source.dart';

/// Sistem izni verilmeden FCM token'ı sunucuya yazılmaz.
///
/// Android `getToken`'ı `POST_NOTIFICATIONS` olmadan da döndürür; reddedilen
/// bir kullanıcıya yine de adres kaydetmek spec'i kırar. Geçici (provisional)
/// iOS izni teslimata yeter.
bool isPushDeliveryAllowed(AuthorizationStatus status) {
  return status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

/// Gerçek FCM token kaynağı.
///
/// `getToken` henüz eski değeri dönebilir; yenileme olayı [onRefresh]
/// üzerinden yaşam döngüsüne daha önce düşer. Başlatma hatası token
/// yokmuş gibi davranır — uygulamanın açılışını düşürmez.
class FirebaseMessagingPushTokenSource implements PushTokenSource {
  FirebaseMessagingPushTokenSource({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<String?> currentToken() async {
    try {
      if (!await _allowed()) return null;
      // firebase_messaging 17 `getToken`/`onTokenRefresh`'i `register()` +
      // `onRegistered` lehine eskitti; olay tabanlı yeni akışa geçiş ayrı
      // iş (yaşam döngüsü ve testler değişiyor). Eski API hâlâ çalışıyor.
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (error, stackTrace) {
      debugPrint('FCM token okunamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Stream<String> get onRefresh =>
      // ignore: deprecated_member_use
      _messaging.onTokenRefresh.asyncExpand((token) async* {
        if (await _allowed()) yield token;
      });

  Future<bool> _allowed() async {
    final settings = await _messaging.getNotificationSettings();
    return isPushDeliveryAllowed(settings.authorizationStatus);
  }
}
