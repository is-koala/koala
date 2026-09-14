import 'package:koala/product/services/push_notification_dedupe.dart';

/// FCM olayını uygulama içi davranışa çevirir.
///
/// Firebase bu sınıfta yok: ön plan tazeleme, dokunma ve dedupe burada
/// sınanır; eklenti sarmalayıcısı yalnız ham `data` haritasını buraya bırakır.
///
/// İki tür yük var:
///
/// - **Bildirim** (`notificationId`): ön planda bildirim listesi tazelenir;
///   dokununca bildirim ekranı açılır ve kayıt okundu işaretlenir.
/// - **Sohbet mesajı** (`type=MESSAGE`, `conversationId`, `messageId`,
///   `notificationId`): ön planda **hiçbir şey yapılmaz** — açık sohbet ve
///   liste aynı mesajı STOMP'tan zaten aldı, ikinci bir sayaç artışı ya da
///   yerel bildirim olmamalı. Dokununca ilgili sohbet açılır
///   ([onConversationOpened]); bildirim ekranı ve `markRead` bu yolda yok,
///   çünkü mesaj push'ının `IN_APP` satırı yok ve sohbeti açmak zaten
///   sohbeti okundu işaretliyor.
///
/// Dokunma dedupe anahtarı mesaj için `messageId`, yoksa `notificationId`:
/// soğuk açılışta `getInitialMessage` ile `onMessageOpenedApp` aynı yükü
/// iki kez verebiliyor.
class PushInbox {
  PushInbox({
    required this.dedupe,
    required this.sessionInitialized,
    required this.notificationsRoute,
    required this.navigate,
    required this.onForeground,
    required this.onOpened,
    required this.onConversationOpened,
  });

  /// Sohbet mesajı push'ının `data.type` değeri
  /// (`ActivityNotificationManager.messageSent`).
  static const String messageType = 'MESSAGE';

  final PushNotificationDedupe dedupe;
  final bool Function() sessionInitialized;
  final String Function() notificationsRoute;
  final void Function(String route) navigate;
  final Future<void> Function() onForeground;
  final Future<void> Function(String notificationId) onOpened;

  /// `type=MESSAGE` dokunması: sohbeti getirip açmak çağıranın işi.
  final Future<void> Function(String conversationId) onConversationOpened;

  Map<String, String>? _pendingOpen;

  Future<void> handleForeground(Map<String, String> data) async {
    if (_isMessage(data)) return;

    final notificationId = data['notificationId'];
    if (notificationId != null && notificationId.isNotEmpty) {
      if (!await dedupe.claim(notificationId)) return;
    }
    await onForeground();
  }

  Future<void> handleOpened(Map<String, String> data) async {
    if (_openKeyOf(data) == null) return;

    if (!sessionInitialized()) {
      _pendingOpen = Map.of(data);
      return;
    }

    await _open(data);
  }

  Future<void> flush() async {
    if (!sessionInitialized()) return;

    final data = _pendingOpen;
    if (data == null) return;
    _pendingOpen = null;
    await _open(data);
  }

  Future<void> _open(Map<String, String> data) async {
    final key = _openKeyOf(data);
    if (key == null || !await dedupe.claim(key)) return;

    if (_isMessage(data)) {
      await onConversationOpened(data['conversationId']!);
      return;
    }

    navigate(notificationsRoute());
    await onOpened(key);
  }

  static bool _isMessage(Map<String, String> data) =>
      data['type'] == messageType && _present(data['conversationId']);

  /// Dokunmanın dedupe anahtarı; yük tanınmıyorsa `null` ve dokunma yok
  /// sayılır.
  static String? _openKeyOf(Map<String, String> data) {
    final notificationId = data['notificationId'];
    if (_isMessage(data)) {
      final messageId = data['messageId'];
      if (_present(messageId)) return messageId;
    }
    return _present(notificationId) ? notificationId : null;
  }

  static bool _present(String? value) => value != null && value.isNotEmpty;
}
