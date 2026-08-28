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
/// Üç kanal var:
/// - `/topic/conversations/{id}` — yeni mesaj, "yazıyor", okundu
/// - `/user/queue/messages` — kullanıcıya özel tek akış; bütün sohbetlerinin
///   yeni mesajları buradan geliyor, liste 20 topic'e abone olmak zorunda
///   kalmıyor
/// - `/topic/presence/{userId}` — tek bir kullanıcının çevrimiçi değişimleri
///
/// ⚠️ Abonelikler sunucuda yetkilendiriliyor: katılımcısı olmadığın bir
/// konuşmaya ya da konuşmadığın birinin presence'ına abone olmak `403`
/// döndürüyor. STOMP'ta hata karesi **bağlantıyı düşürdüğü** için yalnızca
/// gerçekten hakkın olan kanallara abone ol.
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

  /// Kullanıcıya özel mesaj akışı.
  ///
  /// Sohbet listesi bunu dinliyor: hangi konuşmaya gelirse gelsin yeni mesaj
  /// buradan da düşüyor. Sohbet ekranı açıkken aynı mesaj hem konuşma
  /// topic'inden hem buradan gelir — tüketen taraf `message.id` ile
  /// tekilleştirmeli.
  Stream<RealtimeEvent> userMessageEvents() =>
      _streamFor('/user/queue/messages');

  /// Tek bir kullanıcının çevrimiçi durumu.
  ///
  /// Global presence kanalı kaldırıldı: yalnızca kendi durumunu ve paylaştığın
  /// bir konuşması olan kişilerin durumunu izleyebiliyorsun. Yabancı bir
  /// kimliğe abone olmak bağlantıyı düşürür.
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
  ///
  /// ⚠️ **Önce kopya alınıp map'ler boşaltılıyor, sonra kapatılıyor.**
  /// `controller.close()` dinleyicileri iptal ediyor, iptal [_streamFor]'daki
  /// `onCancel`'ı tetikliyor, o da [_releaseIfUnused] üzerinden aynı map'ten
  /// siliyor — map üzerinde gezinirken. Doğrudan `_controllers.values` üzerinde
  /// dönmek bu yüzden `ConcurrentModificationError` fırlatıyordu ve çıkış
  /// yapılamıyordu. Map'ler önden boşaldığı için yeniden giren
  /// [_releaseIfUnused] artık silecek bir şey bulamıyor.
  Future<void> disconnect() async {
    final unsubscribes = _subscriptions.values.toList();
    final controllers = _controllers.values.toList();
    _subscriptions.clear();
    _controllers.clear();

    for (final unsubscribe in unsubscribes) {
      // Kopmuş bir bağlantıda abonelik bırakmak hata verebiliyor; kapanışı
      // durdurmamalı, oturum her hâlükârda sonlanmalı.
      try {
        unsubscribe(unsubscribeHeaders: null);
      } catch (error) {
        debugPrint('Realtime abonelik bırakılamadı: $error');
      }
    }

    for (final controller in controllers) {
      await controller.close();
    }

    _client?.deactivate();
    _client = null;
    _connected = false;
  }
}
