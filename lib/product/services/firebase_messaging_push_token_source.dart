import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:koala/product/services/push_token_source.dart';

/// Sistem izni yoksa token sunucuya yazılmaz; Android `getToken`'ı izinsiz de
/// döndürüyor. Geçici iOS izni yeterli.
bool isPushDeliveryAllowed(AuthorizationStatus status) {
  return status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

/// Gerçek FCM token kaynağı. Başlatma hatası token yokmuş gibi davranır,
/// açılışı düşürmez.
class FirebaseMessagingPushTokenSource implements PushTokenSource {
  FirebaseMessagingPushTokenSource({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<String?> currentToken() async {
    try {
      if (!await _allowed()) return null;
      // firebase_messaging 17 bu API'yi `register()` + `onRegistered` lehine
      // eskitti; geçiş ayrı iş, eski API çalışıyor.
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
