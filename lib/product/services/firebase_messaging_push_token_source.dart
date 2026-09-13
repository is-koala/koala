import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:koala/product/services/push_token_source.dart';

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
      return await _messaging.getToken();
    } catch (error, stackTrace) {
      debugPrint('FCM token okunamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Stream<String> get onRefresh => _messaging.onTokenRefresh;
}
