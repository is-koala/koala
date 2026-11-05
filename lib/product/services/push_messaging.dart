import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:koala/product/services/push_conversation_opener.dart';
import 'package:koala/product/services/push_inbox.dart';
import 'package:koala/product/services/push_notification_dedupe.dart';
import 'package:koala/product/services/push_token_lifecycle.dart';
import 'package:koala/product/services/push_work_detail_opener.dart';
import 'package:koala/product/services/firebase_messaging_push_token_source.dart';

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

  /// FCM dinleyicilerini bağlar.
  ///
  /// [users] `type=MESSAGE` dokunması için: sohbet ekranı karşı tarafı
  /// oturum sahibine göre seçiyor, kimlik `/users/me`'den geliyor.
  static Future<void> bindListeners({
    NotificationProvider? notifications,
    UserProvider? users,
    SessionManager? session,
    NotificationService? service,
    PushInbox? inbox,
  }) async {
    if (!_initialized || _listenersBound) return;

    final sessionManager = session ?? SessionManager();
    final feed = notifications;
    final notificationService = service ?? NotificationService();
    bool isBusiness() => sessionManager.userType == SessionManager.businessType;
    final conversations = PushConversationOpener(
      currentUserId: () async {
        if (users == null) return null;
        if (users.user == null) await users.load();
        return users.user?.id;
      },
      routes: () => isBusiness() ? ChatRoutes.business : ChatRoutes.employee,
      navigate: _openChat,
    );
    final workDetail = PushWorkDetailOpener(navigate: _openWorkDetail);
    _inbox =
        inbox ??
        PushInbox(
          dedupe: PushNotificationDedupe(),
          sessionInitialized: () => sessionManager.isInitialized,
          notificationsRoute: () =>
              isBusiness() ? '/business/notifications' : '/notifications',
          navigate: _navigate,
          onConversationOpened: conversations.open,
          // Ulaşım push'u yalnız işçiye gidiyor; işveren oturumunda iş
          // detayı rotası yok, bildirim ekranına düşülüyor.
          onTransportOpened: ({required assignmentId, required seatDropped}) {
            if (isBusiness()) {
              _navigate('/business/notifications');
              return Future.value();
            }
            return workDetail.open(
              assignmentId: assignmentId,
              seatDropped: seatDropped,
            );
          },
          // Biniş hatırlatması yalnız işçiye gidiyor; QR'ı doğrudan açar.
          onBoardingReminderOpened:
              ({required assignmentId, required direction}) {
                if (isBusiness()) {
                  _navigate('/business/notifications');
                } else {
                  _navigateOver(
                    PushWorkDetailOpener.jobsRoute,
                    EmployeeRoutes.boardingQrLocation(assignmentId, direction),
                  );
                }
                return Future.value();
              },
          // "Henüz binmedi" yalnız yetkililere gidiyor; biniş listesini açar.
          onNotBoardedOpened: (shuttleId) {
            if (isBusiness()) {
              _navigateOver(
                '/business/home',
                BusinessRoutes.shuttleBoardingsLocation(shuttleId),
              );
            } else {
              _navigate('/notifications');
            }
            return Future.value();
          },
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
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (!isPushDeliveryAllowed(settings.authorizationStatus)) {
        await PushTokenLifecycle().clearQuietly();
        return;
      }
      await PushTokenLifecycle().syncQuietly();
    } catch (error, stackTrace) {
      debugPrint('Push izni istenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void _navigate(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RouterManager.router.go(route);
    });
  }

  /// Önce [base]'e gider, bir sonraki karede [location]'ı üstüne iter;
  /// geri çıkınca kullanıcı listeye düşer (`openWorkDetailOn` gerekçesi).
  static void _navigateOver(String base, String location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RouterManager.router.go(base);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(RouterManager.router.push(location));
      });
    });
  }

  static void _openWorkDetail(WorkDetailArgs? args) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openWorkDetailOn(RouterManager.router, args);
    });
  }

  static void _openChat(ChatRoutes routes, Conversation? conversation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openChatOn(RouterManager.router, routes, conversation);
    });
  }

  static Map<String, String> _dataOf(RemoteMessage message) {
    return {
      for (final entry in message.data.entries)
        entry.key: entry.value.toString(),
    };
  }
}
