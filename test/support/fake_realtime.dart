import 'dart:async';

import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

/// Widget testlerinde gerçek WebSocket açmadan sessiz kalan canlı istemci.
class FakeSilentRealtimeClient implements RealtimeClient {
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> conversationEvents(String conversationId) =>
      _events.stream;

  @override
  Stream<RealtimeEvent> presenceEventsFor(String userId) => _events.stream;

  @override
  Stream<RealtimeEvent> userMessageEvents() => _events.stream;

  @override
  Future<void> connect() async {}

  @override
  void sendTyping(String conversationId) {}

  @override
  Future<void> disconnect() async {}

  @override
  bool get isConnected => true;

  @override
  Stream<RealtimeConnectionEvent> get connectionEvents =>
      const Stream<RealtimeConnectionEvent>.empty();

  @override
  void resume({bool suspectStale = false}) {}

  @override
  Future<void> reconnect() async {}

  Future<void> dispose() => _events.close();
}

/// Widget testlerinde kişisel kuyruğa olay basabilen canlı istemci.
///
/// İki kabuğun sohbet listesinin aynı denetleyici üzerinden, çekme yapmadan
/// canlı mesaj aldığını göstermek için var: [emitUserEvent] ile basılan olay
/// `/user/queue/messages` dinleyicisine düşüyor.
class FakeLiveRealtimeClient extends FakeSilentRealtimeClient {
  final StreamController<RealtimeEvent> _userEvents =
      StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> userMessageEvents() => _userEvents.stream;

  void emitUserEvent(RealtimeEvent event) => _userEvents.add(event);

  @override
  Future<void> dispose() async {
    await _userEvents.close();
    await super.dispose();
  }
}
