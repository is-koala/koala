import 'package:koala/product/services/push_notification_dedupe.dart';

/// FCM olayını uygulama içi davranışa çevirir; Firebase'siz test edilebilsin
/// diye ham `data` alıyor.
///
/// - **Bildirim** (`notificationId`): ön planda liste tazelenir; dokununca
///   bildirim ekranı açılır, kayıt okundu olur.
/// - **Mesaj** (`type=MESSAGE`): ön planda hiçbir şey; mesaj STOMP'tan zaten
///   geldi. Dokununca sohbet açılır.
/// - **Ulaşım** (`type=TRANSPORT`): dokununca iş detayı; `SEAT_DROPPED`
///   "yeniden seçin" bağlamıyla.
/// - **Biniş**: `SHUTTLE_REMINDER_BOARDING` işçinin QR'ını,
///   `SHUTTLE_NOTICE_NOT_BOARDED` biniş listesini açar.
///
/// Soğuk açılışta aynı yük iki kez gelebildiği için dokunmalar `messageId` ya
/// da `notificationId` ile tekilleştiriliyor.
class PushInbox {
  PushInbox({
    required this.dedupe,
    required this.sessionInitialized,
    required this.notificationsRoute,
    required this.navigate,
    required this.onForeground,
    required this.onOpened,
    required this.onConversationOpened,
    this.onTransportOpened,
    this.onBoardingReminderOpened,
    this.onNotBoardedOpened,
  });

  static const String messageType = 'MESSAGE';

  static const String transportType = 'TRANSPORT';

  /// Diğer ulaşım olayları aynı sayfayı bağlamsız açıyor.
  static const String seatDroppedEvent = 'SEAT_DROPPED';

  static const String boardingReminderEvent = 'SHUTTLE_REMINDER_BOARDING';

  static const String notBoardedEvent = 'SHUTTLE_NOTICE_NOT_BOARDED';

  final PushNotificationDedupe dedupe;
  final bool Function() sessionInitialized;
  final String Function() notificationsRoute;
  final void Function(String route) navigate;
  final Future<void> Function() onForeground;
  final Future<void> Function(String notificationId) onOpened;

  final Future<void> Function(String conversationId) onConversationOpened;

  /// Verilmezse ulaşım push'u bildirim ekranına gider.
  final Future<void> Function({
    required String assignmentId,
    required bool seatDropped,
  })?
  onTransportOpened;

  /// [direction] `OUTBOUND` | `RETURN`.
  final Future<void> Function({
    required String assignmentId,
    required String direction,
  })?
  onBoardingReminderOpened;

  final Future<void> Function(String shuttleId)? onNotBoardedOpened;

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

    final openReminder = onBoardingReminderOpened;
    if (openReminder != null &&
        _isTransport(data) &&
        data['event'] == boardingReminderEvent) {
      await openReminder(
        assignmentId: data['jobAssignmentId']!,
        direction: _present(data['direction'])
            ? data['direction']!
            : 'OUTBOUND',
      );
      await onOpened(key);
      return;
    }

    final openNotBoarded = onNotBoardedOpened;
    if (openNotBoarded != null &&
        data['type'] == transportType &&
        data['event'] == notBoardedEvent &&
        _present(data['shuttleId'])) {
      await openNotBoarded(data['shuttleId']!);
      await onOpened(key);
      return;
    }

    final openTransport = onTransportOpened;
    if (openTransport != null && _isTransport(data)) {
      await openTransport(
        assignmentId: data['jobAssignmentId']!,
        seatDropped: data['event'] == seatDroppedEvent,
      );
      await onOpened(key);
      return;
    }

    navigate(notificationsRoute());
    await onOpened(key);
  }

  static bool _isMessage(Map<String, String> data) =>
      data['type'] == messageType && _present(data['conversationId']);

  static bool _isTransport(Map<String, String> data) =>
      data['type'] == transportType && _present(data['jobAssignmentId']);

  /// Yük tanınmıyorsa `null` ve dokunma yok sayılır.
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
