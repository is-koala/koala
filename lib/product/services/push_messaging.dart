import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:koala/product/services/push_inbox.dart';
import 'package:koala/product/services/push_notification_dedupe.dart';
import 'package:koala/product/services/push_token_lifecycle.dart';

/// Firebase ve FCM dinleyicilerinin tek giriş noktası.
///
/// [Firebase.initializeApp] `main` içinde değil splash'te çağrılır: `main`
/// senkron kalmak zorunda. Başlatma düşerse push kapalı kalır, uygulama
/// açılmaya devam eder.
class PushMessaging {
  PushMessaging._();

  static bool _initialized = false;
  static bool _listenersBound = false;
  static PushInbox? _inbox;

  static bool get isReady => _initialized;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Firebase başlatılamadı, push kapalı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> bindListeners({
    NotificationProvider? notifications,
    SessionManager? session,
    NotificationService? service,
    PushInbox? inbox,
  }) async {
    if (!_initialized || _listenersBound) return;

    final sessionManager = session ?? SessionManager();
    final feed = notifications;
    final notificationService = service ?? NotificationService();
    _inbox =
        inbox ??
        PushInbox(
          dedupe: PushNotificationDedupe(),
          sessionInitialized: () => sessionManager.isInitialized,
          notificationsRoute: () =>
              sessionManager.userType == SessionManager.businessType
              ? '/business/notifications'
              : '/notifications',
          navigate: _navigate,
          onForeground: () async {
            debugPrint('Ön plan push alındı, bildirim listesi tazeleniyor');
            await feed?.load(silent: true);
          },
          onOpened: (notificationId) async {
            try {
              await notificationService.markRead(notificationId);
            } on ApiException catch (error, stackTrace) {
              debugPrint('Push bildirimi okundu işaretlenemedi: $error');
              debugPrintStack(stackTrace: stackTrace);
            }
            await feed?.load(silent: true);
          },
        );

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_inbox!.handleForeground(_dataOf(message)));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_inbox!.handleOpened(_dataOf(message)));
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await _inbox!.handleOpened(_dataOf(initial));
    }

    _listenersBound = true;
    await _inbox!.flush();
  }

  /// Bildirim kutusuna ilk girişte sistem iznini sorar.
  ///
  /// Açılışta değil: kullanıcı bildirimi göreceği ilk anda sorulur.
  /// `permission_handler` kullanılmaz; FCM kendi Android 13+ diyaloğunu
  /// açar. Reddedilirse uygulama çalışmaya devam eder, token gitmez.
  static Future<void> requestPermissionOnInboxOpen() async {
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      await PushTokenLifecycle().syncQuietly();
    } catch (error, stackTrace) {
      debugPrint('Push izni istenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> flushPending() => _inbox?.flush() ?? Future<void>.value();

  static void _navigate(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RouterManager.router.go(route);
    });
  }

  static Map<String, String> _dataOf(RemoteMessage message) {
    return {
      for (final entry in message.data.entries)
        entry.key: entry.value.toString(),
    };
  }
}
