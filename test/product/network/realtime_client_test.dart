import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../support/fake_api.dart';

/// Soket açmayan STOMP istemcisi. Test, `config` geri çağrılarını kendisi
/// tetikleyerek CONNECT, kopuş ve ret senaryolarını oynatıyor.
class FakeStompClient extends StompClient {
  FakeStompClient({required super.config});

  bool active = false;
  bool _connected = false;

  /// Gönderilen `SUBSCRIBE` hedefleri, sırayla; yeniden bağlanmada tekrar
  /// eklenmeli.
  final List<String> subscribed = [];
  final List<String> unsubscribed = [];

  @override
  bool get connected => _connected;

  @override
  bool get isActive => active;

  @override
  void activate() {
    active = true;
  }

  @override
  void deactivate() {
    active = false;
    _connected = false;
  }

  @override
  StompUnsubscribe subscribe({
    required String destination,
    required StompFrameCallback callback,
    Map<String, String>? headers,
  }) {
    subscribed.add(destination);
    return ({Map<String, String>? unsubscribeHeaders}) {
      unsubscribed.add(destination);
    };
  }

  @override
  void send({
    required String destination,
    Map<String, String>? headers,
    String? body,
    Uint8List? binaryBody,
  }) {}

  /// Kütüphanenin yaptığı gibi: her denemeden önce `beforeConnect`, sonra
  /// CONNECTED karesi. CONNECT başlığı o an okunuyor.
  Future<String?> completeConnect() async {
    await config.beforeConnect();
    if (!active) return null;
    _connected = true;
    config.onConnect(StompFrame(command: 'CONNECTED'));
    return config.stompConnectHeaders?['Authorization'];
  }

  void dropSocket() {
    _connected = false;
    config.onWebSocketDone();
  }

  void rejectConnect() {
    config.onStompError(StompFrame(command: 'ERROR', body: 'rejected'));
    config.onWebSocketDone();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTokenStorage tokens;
  late List<FakeStompClient> created;
  late int probes;

  FakeStompClient stomp() => created.last;

  RealtimeClient build({SessionManager? session}) {
    return RealtimeClient.forTesting(
      tokenStorage: tokens,
      sessionManager: session,
      stompClientFactory: (config) {
        final client = FakeStompClient(config: config);
        created.add(client);
        return client;
      },
      sessionProbe: () async => probes++,
    );
  }

  setUp(() {
    tokens = FakeTokenStorage(accessToken: 'token-1', refreshToken: 'r');
    created = [];
    probes = 0;
  });

  group('RealtimeClient.connect', () {
    test('token yoksa soket hiç açılmıyor', () async {
      tokens.accessToken = null;
      final client = build();

      await client.connect();

      expect(created, isEmpty);
      expect(client.isConnected, isFalse);
    });

    test('bekleyen abonelikler CONNECT sonrası kuruluyor', () async {
      final client = build();
      final sub = client.conversationEvents('c1').listen((_) {});
      final personal = client.userMessageEvents().listen((_) {});
      addTearDown(sub.cancel);
      addTearDown(personal.cancel);

      await client.connect();
      expect(stomp().subscribed, isEmpty);

      final header = await stomp().completeConnect();

      expect(header, 'Bearer token-1');
      expect(
        stomp().subscribed,
        containsAll(['/topic/conversations/c1', '/user/queue/messages']),
      );
      expect(client.isConnected, isTrue);
    });

    test('art arda iki connect tek istemci açıyor', () async {
      final client = build();

      await Future.wait([client.connect(), client.connect()]);

      expect(created, hasLength(1));
    });
  });

  group('yeniden bağlanma', () {
    test('kopan bağlantı yeniden kurulunca abonelikler yeniden gönderiliyor '
        've CONNECT güncel token ile açılıyor', () async {
      final client = build();
      final events = <RealtimeConnectionEvent>[];
      client.connectionEvents.listen(events.add);
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);

      await client.connect();
      await stomp().completeConnect();
      expect(stomp().subscribed, ['/topic/conversations/c1']);

      // AuthInterceptor token'ı yeniledi; ardından soket düştü.
      tokens.accessToken = 'token-2';
      stomp().dropSocket();
      expect(client.isConnected, isFalse);

      // Eski hâlinde abonelik kaydı silinmediği için burada ikinci bir
      // SUBSCRIBE gitmiyordu: yeniden bağlanan soket hiçbir kanalı
      // dinlemiyordu.
      final header = await stomp().completeConnect();

      expect(header, 'Bearer token-2');
      expect(stomp().subscribed, [
        '/topic/conversations/c1',
        '/topic/conversations/c1',
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events, [
        RealtimeConnectionEvent.connected,
        RealtimeConnectionEvent.disconnected,
        RealtimeConnectionEvent.connected,
      ]);
    });

    test('hiç bağlanamamış deneme kopuş duyurmuyor', () async {
      final client = build();
      final events = <RealtimeConnectionEvent>[];
      client.connectionEvents.listen(events.add);
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);

      await client.connect();
      stomp().dropSocket();
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('yeniden denemede token kalmamışsa istemci duruyor', () async {
      final client = build();
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);

      await client.connect();
      await stomp().completeConnect();
      stomp().dropSocket();
      tokens.accessToken = null;

      final header = await stomp().completeConnect();

      expect(header, isNull);
      expect(stomp().active, isFalse);
      expect(client.isConnected, isFalse);
    });

    test('CONNECT reddedilince oturum yoklanıyor, art arda değil', () async {
      final client = build();
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);

      await client.connect();
      stomp().rejectConnect();
      stomp().rejectConnect();
      await Future<void>.delayed(Duration.zero);

      expect(probes, 1);
    });

    test('kurulu bağlantıdaki hata karesi yoklama yapmıyor', () async {
      final client = build();
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);

      await client.connect();
      await stomp().completeConnect();
      stomp().config.onStompError(StompFrame(command: 'ERROR', body: 'x'));
      await Future<void>.delayed(Duration.zero);

      expect(probes, 0);
    });
  });

  group('resume', () {
    test('dinleyen yokken hiçbir şey yapmıyor', () async {
      final client = build();

      client.resume(suspectStale: true);
      await Future<void>.delayed(Duration.zero);

      expect(created, isEmpty);
    });

    test('bağlantı ayaktaysa yalnızca resumed duyuruyor', () async {
      final client = build();
      final events = <RealtimeConnectionEvent>[];
      client.connectionEvents.listen(events.add);
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);
      await client.connect();
      await stomp().completeConnect();

      client.resume();
      await Future<void>.delayed(Duration.zero);

      expect(created, hasLength(1));
      expect(events, [
        RealtimeConnectionEvent.connected,
        RealtimeConnectionEvent.resumed,
      ]);
    });

    test('soket şüpheliyse eski istemci bırakılıp yenisi kuruluyor ve '
        'abonelikler yeni istemcide açılıyor', () async {
      final client = build();
      final events = <RealtimeConnectionEvent>[];
      client.connectionEvents.listen(events.add);
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);
      await client.connect();
      await stomp().completeConnect();
      final old = stomp();

      client.resume(suspectStale: true);
      await Future<void>.delayed(Duration.zero);

      expect(old.active, isFalse);
      expect(created, hasLength(2));
      await stomp().completeConnect();
      expect(stomp().subscribed, ['/topic/conversations/c1']);
      await Future<void>.delayed(Duration.zero);
      expect(events, [
        RealtimeConnectionEvent.connected,
        RealtimeConnectionEvent.disconnected,
        RealtimeConnectionEvent.connected,
      ]);

      // Eski istemcinin geç gelen kapanışı yeni bağlantıyı etkilememeli.
      old.dropSocket();
      expect(client.isConnected, isTrue);
    });

    test('kopuk bağlantı zamanlayıcı beklenmeden yeniden kuruluyor', () async {
      final client = build();
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);
      await client.connect();
      await stomp().completeConnect();
      stomp().dropSocket();

      client.resume();
      await Future<void>.delayed(Duration.zero);

      expect(created, hasLength(2));
    });
  });

  group('oturum', () {
    late SessionManager session;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      session = SessionManager.withTokenStorage(
        TokenStorage.withStorage(
          const FlutterSecureStorage(),
          apiOrigin: 'https://test.local',
        ),
      );
      await session.load();
      await session.start(
        accessToken: 'token-1',
        refreshToken: 'r',
        isEmployer: false,
      );
    });

    tearDown(() => session.dispose());

    test('oturum bitince bağlantı bırakılıyor', () async {
      final client = build(session: session);
      final done = client.conversationEvents('c1').isEmpty;
      await client.connect();
      await stomp().completeConnect();

      await session.end();
      await Future<void>.delayed(Duration.zero);

      expect(await done, isTrue);
      expect(stomp().active, isFalse);
      expect(client.isConnected, isFalse);
    });

    test('oturum kapalıyken CONNECT reddi yoklama yapmıyor', () async {
      final client = build(session: session);
      final sub = client.conversationEvents('c1').listen((_) {});
      addTearDown(sub.cancel);
      await client.connect();

      await session.end();
      // Kapanış istemciyi durdurdu; geç gelen ret karesi eski istemciden.
      created.first.config.onStompError(
        StompFrame(command: 'ERROR', body: 'rejected'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(probes, 0);
    });
  });

  group('RealtimeClient.disconnect', () {
    test('dinleyicisi olan kanallar kapatılırken patlamıyor', () async {
      final client = build();
      final first = client.conversationEvents('a').listen((_) {});
      final second = client.conversationEvents('b').listen((_) {});
      final personal = client.userMessageEvents().listen((_) {});

      // `close()` dinleyicileri iptal ediyor, iptal `onCancel` üzerinden
      // aynı map'ten siliyor. Map üzerinde doğrudan gezinen eski hâli burada
      // `ConcurrentModificationError` fırlatıyordu ve kullanıcı çıkış
      // yapamıyordu.
      await expectLater(client.disconnect(), completes);

      await first.cancel();
      await second.cancel();
      await personal.cancel();
    });

    test('kapanan akışlar tüketiciye biter', () async {
      final client = build();
      final done = client.conversationEvents('a').isEmpty;

      await client.disconnect();

      expect(await done, isTrue);
    });

    test('kapanıştan sonra yeni abonelik açılabiliyor', () async {
      final client = build();
      client.conversationEvents('a').listen((_) {});

      await client.disconnect();

      // Map'ler boşaldığı için eski, kapanmış controller geri verilmemeli.
      final stream = client.conversationEvents('a');
      final subscription = stream.listen((_) {});
      addTearDown(subscription.cancel);

      expect(client.isConnected, isFalse);
    });

    test('boşken çağrılmak zararsız', () async {
      final client = build();

      await expectLater(client.disconnect(), completes);
      await expectLater(client.disconnect(), completes);
    });

    test(
      'açık bağlantıda abonelikler bırakılıp istemci durduruluyor',
      () async {
        final client = build();
        final sub = client.conversationEvents('c1').listen((_) {});
        addTearDown(sub.cancel);
        await client.connect();
        await stomp().completeConnect();

        await client.disconnect();

        expect(stomp().unsubscribed, ['/topic/conversations/c1']);
        expect(stomp().active, isFalse);
      },
    );
  });
}
