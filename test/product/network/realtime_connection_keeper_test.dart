import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_connection_keeper.dart';
import 'package:koala/product/network/realtime_event.dart';

/// Yalnızca `resume` çağrılarını kaydeden istemci.
class RecordingRealtimeClient implements RealtimeClient {
  final List<bool> resumeCalls = [];

  @override
  void resume({bool suspectStale = false}) => resumeCalls.add(suspectStale);

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  bool get isConnected => true;

  @override
  Stream<RealtimeConnectionEvent> get connectionEvents =>
      const Stream<RealtimeConnectionEvent>.empty();

  @override
  Stream<RealtimeEvent> conversationEvents(String conversationId) =>
      const Stream<RealtimeEvent>.empty();

  @override
  Stream<RealtimeEvent> presenceEventsFor(String userId) =>
      const Stream<RealtimeEvent>.empty();

  @override
  Stream<RealtimeEvent> userMessageEvents() =>
      const Stream<RealtimeEvent>.empty();

  @override
  void sendTyping(String conversationId) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingRealtimeClient client;
  late StreamController<void> network;
  late DateTime now;
  late int resumedCallbacks;
  late RealtimeConnectionKeeper keeper;

  setUp(() {
    client = RecordingRealtimeClient();
    network = StreamController<void>.broadcast();
    now = DateTime(2026, 9, 14, 12);
    resumedCallbacks = 0;
    keeper = RealtimeConnectionKeeper(
      client: client,
      networkAvailable: network.stream,
      now: () => now,
      onResumed: () => resumedCallbacks++,
    )..start();
  });

  tearDown(() async {
    keeper.stop();
    await network.close();
  });

  group('yaşam döngüsü', () {
    test('kısa ayrılıştan dönüş soketi şüpheli saymaz', () {
      keeper.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 5));
      keeper.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(client.resumeCalls, [false]);
      expect(resumedCallbacks, 1);
    });

    test('uzun ayrılıştan dönüş bağlantıyı yeniden kurdurur', () {
      keeper.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(RealtimeConnectionKeeper.staleAfter);
      keeper.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(client.resumeCalls, [true]);
    });

    // iOS `inactive` → `hidden` → `paused` sırasıyla geçiyor; ilk kayıt esas.
    test('arka plan süresi ilk geçişten sayılır', () {
      keeper.didChangeAppLifecycleState(AppLifecycleState.hidden);
      now = now.add(const Duration(seconds: 15));
      keeper.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 15));
      keeper.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(client.resumeCalls, [true]);
    });

    test('inactive geçişi tek başına dönüş üretmez', () {
      keeper.didChangeAppLifecycleState(AppLifecycleState.inactive);
      keeper.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(client.resumeCalls, isEmpty);
      expect(resumedCallbacks, 0);
    });
  });

  group('ağ', () {
    test('ağ geri gelince bağlantı yeniden kurulur', () async {
      network.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(client.resumeCalls, [true]);
    });

    test('art arda ağ olayları tek sayılır', () async {
      network.add(null);
      now = now.add(const Duration(milliseconds: 500));
      network.add(null);
      await Future<void>.delayed(Duration.zero);
      now = now.add(RealtimeConnectionKeeper.networkDebounce);
      network.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(client.resumeCalls, [true, true]);
    });

    test('durdurulduktan sonra ağ olayları dinlenmez', () async {
      keeper.stop();

      network.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(client.resumeCalls, isEmpty);
    });
  });
}
