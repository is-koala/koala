import 'package:koala/product/services/push_notification_dedupe.dart';

/// FCM olayını uygulama içi bildirim kutusuna çevirir.
///
/// Firebase bu sınıfta yok: ön plan tazeleme, dokunma ve dedupe burada
/// sınanır; eklenti sarmalayıcısı yalnız ham mesajı buraya bırakır.
class PushInbox {
  PushInbox({
    required this.dedupe,
    required this.sessionInitialized,
    required this.notificationsRoute,
    required this.navigate,
    required this.onForeground,
    required this.onOpened,
  });

  final PushNotificationDedupe dedupe;
  final bool Function() sessionInitialized;
  final String Function() notificationsRoute;
  final void Function(String route) navigate;
  final Future<void> Function() onForeground;
  final Future<void> Function(String notificationId) onOpened;

  String? _pendingNotificationId;

  Future<void> handleForeground(Map<String, String> data) async {
    final notificationId = data['notificationId'];
    if (notificationId == null || notificationId.isEmpty) return;
    if (!await dedupe.claim(notificationId)) return;
    await onForeground();
  }

  Future<void> handleOpened(Map<String, String> data) async {
    final notificationId = data['notificationId'];
    if (notificationId == null || notificationId.isEmpty) return;

    if (!sessionInitialized()) {
      _pendingNotificationId = notificationId;
      return;
    }

    await _open(notificationId);
  }

  Future<void> flush() async {
    if (!sessionInitialized()) return;

    final notificationId = _pendingNotificationId;
    if (notificationId == null) return;
    _pendingNotificationId = null;
    await _open(notificationId);
  }

  Future<void> _open(String notificationId) async {
    if (!await dedupe.claim(notificationId)) return;
    navigate(notificationsRoute());
    await onOpened(notificationId);
  }
}
