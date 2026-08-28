import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/network/realtime_event.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// Sunucuyla canlı bağlantı (STOMP over WebSocket).
///
/// Backend `/ws` üzerinde STOMP konuşuyor, SockJS yok. Kimlik doğrulama
/// CONNECT karesindeki `Authorization` başlığıyla yapılıyor — soket el
/// sıkışmasındaki başlıkla değil; `StompAuthChannelInterceptor` bu başlığı
/// okuyor.
///
/// Abone olunabilen iki kanal var:
/// - `/topic/conversations/{id}` — yeni mesaj, "yazıyor", okundu
/// - `/topic/presence` — çevrimiçi/çevrimdışı değişimleri
///
/// Bağlantı **isteğe bağlı**: kurulamazsa uygulama REST üzerinden çalışmaya
/// devam ediyor, yalnızca güncellemeler anlık gelmiyor.
class RealtimeClient {
  RealtimeClient._({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage();

  static final RealtimeClient _instance = RealtimeClient._();

  factory RealtimeClient() => _instance;

  @visibleForTesting
  factory RealtimeClient.forTesting({TokenStorage? tokenStorage}) {
    return RealtimeClient._(tokenStorage: tokenStorage);
  }

  final TokenStorage _tokenStorage;

  StompClient? _client;
  bool _connected = false;

  /// Bağlantı kurulmadan yapılan abonelikler burada bekliyor; CONNECT
  /// tamamlanınca hepsi sırayla kuruluyor.
  final Map<String, StreamController<RealtimeEvent>> _controllers = {};
  final Map<String, StompUnsubscribe> _subscriptions = {};

  /// Sunucuyla bağlantı kurulu mu.
  bool get isConnected => _connected;

  /// Bağlantıyı açar. Zaten açıksa hiçbir şey yapmıyor.
  ///
  /// Oturum yoksa (token okunamıyorsa) sessizce vazgeçiyor: sohbet ekranı
  /// REST ile zaten çalışıyor, kullanıcıya gösterilecek bir hata yok.
  Future<void> connect() async {
    if (_client != null) return;

    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) return;

    final client = StompClient(
      config: StompConfig(
        url: ApiConfig.websocketUrl,
        // Başlık STOMP CONNECT karesine giriyor; sunucu oturumu buradan
        // çözüyor. Yeniden bağlanmada güncel token okunsun diye
        // `beforeConnect` içinde tazeleniyor.
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: _onConnect,
        onDisconnect: (_) => _connected = false,
        onWebSocketDone: () => _connected = false,
        onStompError: (frame) =>
            debugPrint('Realtime STOMP hatası: ${frame.body}'),
        onWebSocketError: (error) =>
            debugPrint('Realtime soket hatası: $error'),
        // Kopan bağlantı kendiliğinden toparlansın; mobilde şebeke sık
        // değişiyor.
        reconnectDelay: const Duration(seconds: 5),
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    _client = client;
    client.activate();
  }

  void _onConnect(StompFrame frame) {
    _connected = true;
    // Bekleyen abonelikler ve yeniden bağlanma sonrası eskiler yeniden
    // kuruluyor: STOMP abonelikleri bağlantıyla birlikte düşüyor.
    for (final destination in _controllers.keys) {
      _subscribe(destination);
    }
  }

  /// Bir sohbetin olay akışı: yeni mesaj, "yazıyor", okundu.
  Stream<RealtimeEvent> conversationEvents(String conversationId) {
    return _streamFor('/topic/conversations/$conversationId');
  }

  /// Çevrimiçi durumu değişimleri. Herkese açık kanal.
  Stream<RealtimeEvent> presenceEvents() => _streamFor('/topic/presence');

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

  /// Dinleyicisi kalmayan kanalın aboneliği bırakılıyor; sunucuya boşuna
  /// olay yollatmamak için.
  void _releaseIfUnused(String destination) {
    final controller = _controllers[destination];
    if (controller == null || controller.hasListener) return;

    _subscriptions.remove(destination)?.call(unsubscribeHeaders: null);
    _controllers.remove(destination);
    controller.close();
  }

  /// Karşı tarafa "yazıyor" bilgisi gönderir.
  ///
  /// Bağlantı yoksa sessizce yok sayılıyor: yazma göstergesi kritik değil.
  void sendTyping(String conversationId) {
    final client = _client;
    if (client == null || !_connected) return;

    client.send(destination: '/app/conversations/$conversationId/typing');
  }

  /// Bağlantıyı kapatır ve bütün abonelikleri bırakır. Çıkışta çağrılıyor.
  Future<void> disconnect() async {
    for (final unsubscribe in _subscriptions.values) {
      unsubscribe(unsubscribeHeaders: null);
    }
    _subscriptions.clear();

    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();

    _client?.deactivate();
    _client = null;
    _connected = false;
  }
}
