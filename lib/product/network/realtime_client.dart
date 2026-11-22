import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/realtime_event.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// Bağlantının durum değişimleri; tüketiciler kopukken kaçırdıklarını REST'ten
/// tamamlıyor.
enum RealtimeConnectionEvent {
  /// CONNECT tamamlandı ve abonelikler yeniden kuruldu; her bağlanmada gelir.
  connected,

  disconnected,

  /// Uygulama ön plana döndü ve bağlantı görünüşte ayakta. Ölü bir soketi kalp
  /// atışı ancak on saniyeler sonra fark ediyor; bu sinyalde REST'ten
  /// tamamlamak o pencereyi kapatıyor.
  resumed,
}

typedef StompClientFactory = StompClient Function(StompConfig config);

/// Sunucuyla canlı bağlantı (STOMP over WebSocket, SockJS yok).
///
/// Kimlik CONNECT karesindeki `Authorization` başlığıyla doğrulanıyor, el
/// sıkışmasındakiyle değil. Kanallar:
/// - `/topic/conversations/{id}`: yeni mesaj, "yazıyor", okundu
/// - `/user/queue/messages`: bütün sohbetlerin yeni mesajları tek akışta
/// - `/topic/presence/{userId}`: tek kullanıcının çevrimiçi durumu
///
/// ⚠️ Abonelikler sunucuda yetkilendiriliyor ve STOMP'ta hata karesi
/// **bağlantıyı düşürüyor**: yalnız hakkın olan kanallara abone ol.
///
/// Bağlantı isteğe bağlı; kurulamazsa uygulama REST ile çalışır. Yeniden
/// bağlanırken token CONNECT anında okunur, eski abonelik kayıtları silinir ve
/// geçiş [connectionEvents]'ten duyurulur.
class RealtimeClient {
  RealtimeClient._({
    TokenStorage? tokenStorage,
    this._sessionManager,
    StompClientFactory? stompClientFactory,
    Future<void> Function()? sessionProbe,
    DateTime Function()? now,
  }) : _tokenStorage = tokenStorage ?? TokenStorage(),
       _stompClientFactory = stompClientFactory ?? _defaultStompClientFactory,
       _sessionProbe = sessionProbe ?? _defaultSessionProbe,
       _now = now ?? DateTime.now {
    _sessionManager?.addListener(_onSessionChanged);
  }

  static final RealtimeClient _instance = RealtimeClient._(
    sessionManager: SessionManager(),
  );

  factory RealtimeClient() => _instance;

  /// Testler için: Keychain'e, oturuma ve sokete gitmeyen örnek. [now] yoklama
  /// aralığının saati.
  @visibleForTesting
  factory RealtimeClient.forTesting({
    TokenStorage? tokenStorage,
    SessionManager? sessionManager,
    StompClientFactory? stompClientFactory,
    Future<void> Function()? sessionProbe,
    DateTime Function()? now,
  }) {
    return RealtimeClient._(
      tokenStorage: tokenStorage,
      sessionManager: sessionManager,
      stompClientFactory: stompClientFactory,
      sessionProbe: sessionProbe,
      now: now,
    );
  }

  /// CONNECT reddinden sonra oturum yoklamaları arasındaki en kısa süre. Ret
  /// genelde dolmuş token demek ve yoklama yenilemeyi tetikliyor; ret başka
  /// sebeptense her denemede `/users/me` çekilmesin.
  static const Duration _sessionProbeInterval = Duration(seconds: 30);

  static const Duration _reconnectDelay = Duration(seconds: 5);

  final TokenStorage _tokenStorage;
  final SessionManager? _sessionManager;
  final StompClientFactory _stompClientFactory;
  final Future<void> Function() _sessionProbe;
  final DateTime Function() _now;

  StompClient? _client;
  Future<void>? _connecting;
  bool _connected = false;
  DateTime? _lastSessionProbeAt;

  /// CONNECT başlıkları. `StompConfig` haritayı referansla tutuyor;
  /// [_refreshConnectHeaders] her denemeden önce güncel token'ı yazıyor.
  final Map<String, String> _connectHeaders = {};

  /// Bağlantıdan önce açılan abonelikler; CONNECT gelince kuruluyor.
  final Map<String, StreamController<RealtimeEvent>> _controllers = {};
  final Map<String, StompUnsubscribe> _subscriptions = {};

  final StreamController<RealtimeConnectionEvent> _connectionEvents =
      StreamController<RealtimeConnectionEvent>.broadcast();

  bool get isConnected => _connected;

  Stream<RealtimeConnectionEvent> get connectionEvents =>
      _connectionEvents.stream;

  static StompClient _defaultStompClientFactory(StompConfig config) =>
      StompClient(config: config);

  /// Oturumu REST'ten yoklar; amaç `401` ile `AuthInterceptor`'ın token'ı
  /// yenilemesi. Yenileme de tutmazsa oturum kapanır ve bağlantı bırakılır.
  static Future<void> _defaultSessionProbe() async {
    try {
      await ApiClient().get<void>(ApiPaths.currentUser, parse: (_) {});
    } on ApiException {
      // Sonuç değil yan etki (yenileme) önemli.
    }
  }

  /// Bağlantıyı açar; zaten açıksa bir şey yapmaz. Oturum yoksa sessizce
  /// vazgeçer, çünkü ekranlar REST ile zaten çalışıyor.
  Future<void> connect() {
    if (_client != null) return Future.value();
    return _connecting ??= _openClient().whenComplete(() => _connecting = null);
  }

  Future<void> _openClient() async {
    if (!await _refreshConnectHeaders()) return;
    if (_client != null) return;

    late final StompClient client;
    client = _stompClientFactory(
      StompConfig(
        url: ApiConfig.websocketUrl,
        stompConnectHeaders: _connectHeaders,
        beforeConnect: () => _beforeConnect(client),
        onConnect: (frame) => _onConnect(client),
        onDisconnect: (_) => _onDisconnected(client),
        onWebSocketDone: () => _onDisconnected(client),
        onStompError: (frame) => _onStompError(client, frame),
        onWebSocketError: (error) =>
            debugPrint('Realtime soket hatası: $error'),
        reconnectDelay: _reconnectDelay,
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    _client = client;
    client.activate();
  }

  Future<bool> _refreshConnectHeaders() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      _connectHeaders.remove('Authorization');
      return false;
    }
    _connectHeaders['Authorization'] = 'Bearer $token';
    return true;
  }

  /// Her bağlantı denemesinden önce çalışır; token burada tazelendiği için
  /// yeniden bağlanma yenilenmiş token'la açılıyor. Token yoksa istemci durur
  /// ki giriş ekranında reddedilen CONNECT tekrar tekrar denenmesin.
  Future<void> _beforeConnect(StompClient client) async {
    if (!identical(client, _client)) return;
    if (await _refreshConnectHeaders()) return;
    _teardownClient();
  }

  void _onConnect(StompClient client) {
    if (!identical(client, _client)) return;
    _connected = true;
    // STOMP abonelikleri bağlantıyla birlikte düştüğü için yeniden kuruluyor.
    for (final destination in _controllers.keys.toList()) {
      _subscribe(destination);
    }
    _connectionEvents.add(RealtimeConnectionEvent.connected);
  }

  /// Soket kapandı. Abonelik kayıtları burada siliniyor: kalırsa [_subscribe]
  /// "zaten abone" sanıp yeniden `SUBSCRIBE` göndermez.
  void _onDisconnected(StompClient client) {
    if (!identical(client, _client)) return;
    _subscriptions.clear();
    if (!_connected) return;
    _connected = false;
    _connectionEvents.add(RealtimeConnectionEvent.disconnected);
  }

  /// Bağlantıdan önce gelen hata karesi CONNECT reddi; büyük olasılıkla dolmuş
  /// token, o yüzden oturum yoklanıyor.
  void _onStompError(StompClient client, StompFrame frame) {
    debugPrint('Realtime STOMP hatası: ${frame.body}');
    if (!identical(client, _client) || _connected) return;

    final now = _now();
    final last = _lastSessionProbeAt;
    if (last != null && now.difference(last) < _sessionProbeInterval) return;
    _lastSessionProbeAt = now;
    unawaited(_sessionProbe());
  }

  void _onSessionChanged() {
    if (_sessionManager?.isLoggedIn ?? true) return;
    unawaited(disconnect());
  }

  /// Uygulama ön plana döndü ya da ağ geri geldi. Dinleyen yoksa bir şey
  /// yapmaz. Bağlantı yoksa ya da [suspectStale] ise hemen yeniden bağlanır;
  /// ayaktaysa yalnız [RealtimeConnectionEvent.resumed] duyurulur.
  void resume({bool suspectStale = false}) {
    if (_controllers.isEmpty) return;
    if (_client == null || !_connected || suspectStale) {
      unawaited(reconnect());
      return;
    }
    _connectionEvents.add(RealtimeConnectionEvent.resumed);
  }

  /// Bağlantıyı bırakıp yenisini kurar; abonelikler yeniden açılır.
  Future<void> reconnect() {
    final wasConnected = _connected;
    _teardownClient();
    if (wasConnected) {
      _connectionEvents.add(RealtimeConnectionEvent.disconnected);
    }
    return connect();
  }

  /// İstemciyi durdurur; abonelik akışları açık kalır.
  void _teardownClient() {
    final client = _client;
    _client = null;
    _connected = false;
    _subscriptions.clear();
    try {
      client?.deactivate();
    } catch (error) {
      debugPrint('Realtime istemci kapatılamadı: $error');
    }
  }

  Stream<RealtimeEvent> conversationEvents(String conversationId) {
    return _streamFor('/topic/conversations/$conversationId');
  }

  /// Kullanıcıya özel mesaj akışı. Sohbet açıkken aynı mesaj konuşma
  /// topic'inden de gelir; tüketen `message.id` ile tekilleştirmeli.
  Stream<RealtimeEvent> userMessageEvents() =>
      _streamFor('/user/queue/messages');

  /// Tek kullanıcının çevrimiçi durumu. Yalnız kendin ve konuşman olan kişiler
  /// izlenebilir; yabancı bir kimliğe abone olmak bağlantıyı düşürür.
  Stream<RealtimeEvent> presenceEventsFor(String userId) =>
      _streamFor('/topic/presence/$userId');

  Stream<RealtimeEvent> _streamFor(String destination) {
    final existing = _controllers[destination];
    if (existing != null) return existing.stream;

    final controller = StreamController<RealtimeEvent>.broadcast(
      onCancel: () => _releaseIfUnused(destination),
    );
    _controllers[destination] = controller;

    if (_connected) _subscribe(destination);

    return controller.stream;
  }

  void _subscribe(String destination) {
    if (_subscriptions.containsKey(destination)) return;

    final client = _client;
    if (client == null || !_connected) return;

    _subscriptions[destination] = client.subscribe(
      destination: destination,
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;

        try {
          final decoded = jsonDecode(body);
          if (decoded is! Map<String, dynamic>) return;
          _controllers[destination]?.add(RealtimeEvent.fromJson(decoded));
        } on FormatException catch (error) {
          debugPrint('Realtime olayı çözülemedi: $error');
        }
      },
    );
  }

  /// Dinleyicisi kalmayan kanal bırakılıyor ki sunucu boşuna olay yollamasın.
  void _releaseIfUnused(String destination) {
    final controller = _controllers[destination];
    if (controller == null || controller.hasListener) return;

    _subscriptions.remove(destination)?.call(unsubscribeHeaders: null);
    _controllers.remove(destination);
    controller.close();
  }

  /// "Yazıyor" bilgisi gönderir; bağlantı yoksa sessizce geçer.
  void sendTyping(String conversationId) {
    final client = _client;
    if (client == null || !_connected) return;

    client.send(destination: '/app/conversations/$conversationId/typing');
  }

  /// Bağlantıyı kapatır ve abonelikleri bırakır.
  ///
  /// ⚠️ Map'ler kapatmadan **önce** boşaltılıyor: `controller.close()`
  /// [_releaseIfUnused] üzerinden aynı map'ten siliyor, üzerinde gezinirken
  /// `ConcurrentModificationError` fırlar.
  Future<void> disconnect() async {
    final unsubscribes = _subscriptions.values.toList();
    final controllers = _controllers.values.toList();
    _subscriptions.clear();
    _controllers.clear();

    for (final unsubscribe in unsubscribes) {
      // Kopmuş bağlantıda abonelik bırakmak hata verebilir; oturum yine de
      // sonlanmalı.
      try {
        unsubscribe(unsubscribeHeaders: null);
      } catch (error) {
        debugPrint('Realtime abonelik bırakılamadı: $error');
      }
    }

    // Eşzamanlı bırakılıyor: bundan sonra eski soketin karesi kimlik
    // kontrolünden geçemez.
    _teardownClient();

    for (final controller in controllers) {
      await controller.close();
    }
  }
}
