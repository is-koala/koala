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

  Future<void> dispose() => _events.close();
}
