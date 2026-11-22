import 'dart:async';

import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

/// Sessiz canlı istemci; denetleyici sahteleri bunu genişletir ki yeni üye tek
/// yerde karşılansın.
class FakeSilentRealtimeClient implements RealtimeClient {
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<RealtimeConnectionEvent> _connection =
      StreamController<RealtimeConnectionEvent>.broadcast();

  /// Abonelik anında bağlantı var mı; `false` verilirse denetleyici ilk
  /// `connected`'da boşluğu tamamlamalı.
  bool connected = true;

  bool connectCalled = false;

  /// `resume` çağrılarındaki `suspectStale` değerleri, sırayla.
  final List<bool> resumeCalls = [];

  @override
  Stream<RealtimeEvent> conversationEvents(String conversationId) =>
      _events.stream;

  @override
  Stream<RealtimeEvent> presenceEventsFor(String userId) => _events.stream;

  @override
  Stream<RealtimeEvent> userMessageEvents() => _events.stream;

  @override
  Stream<RealtimeConnectionEvent> get connectionEvents => _connection.stream;

  void emitConnection(RealtimeConnectionEvent event) => _connection.add(event);

  @override
  Future<void> connect() async => connectCalled = true;

  @override
  Future<void> reconnect() async {}

  @override
  void resume({bool suspectStale = false}) => resumeCalls.add(suspectStale);

  @override
  void sendTyping(String conversationId) {}

  @override
  Future<void> disconnect() async {}

  @override
  bool get isConnected => connected;

  Future<void> dispose() async {
    await _events.close();
    await _connection.close();
  }
}

/// İki kabuğun aynı denetleyiciyle canlı mesaj aldığını göstermek için.
class FakeLiveRealtimeClient extends FakeSilentRealtimeClient {
  final StreamController<RealtimeEvent> _userEvents =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<RealtimeEvent> _conversationEvents =
      StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> userMessageEvents() => _userEvents.stream;

  @override
  Stream<RealtimeEvent> conversationEvents(String conversationId) =>
      _conversationEvents.stream;

  /// `/user/queue/messages` dinleyicisine düşer.
  void emitUserEvent(RealtimeEvent event) => _userEvents.add(event);

  /// `/topic/conversations/{id}` dinleyicisine düşer.
  void emitConversationEvent(RealtimeEvent event) =>
      _conversationEvents.add(event);

  @override
  Future<void> dispose() async {
    await _userEvents.close();
    await _conversationEvents.close();
    await super.dispose();
  }
}
