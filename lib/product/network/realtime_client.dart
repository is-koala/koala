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

/// Bağlantının durum değişimleri. Tüketiciler bunlara bakarak kopukken
/// kaçırdıklarını REST'ten tamamlıyor.
enum RealtimeConnectionEvent {
  /// CONNECT tamamlandı ve bekleyen abonelikler yeniden kuruldu.
  ///
  /// İlk bağlantıda da, her yeniden bağlanmada da gelir. Aradaki fark
  /// tüketicinin bilgisi: daha önce [disconnected] gördüyse ya da aboneliğini
  /// bağlantı yokken açtıysa aradaki boşluğu tamamlaması gerekiyor.
  connected,

  /// Kurulu bağlantı koptu; abonelikler onunla birlikte düştü.
  disconnected,

  /// Uygulama ön plana döndü ve bağlantı görünüşte ayakta.
  ///
  /// Askıdaki bir soket ölmüş olsa bile kalp atışı bekçisi bunu ancak
  /// birkaç on saniye sonra anlıyor; tüketici bu sinyalde bir kez REST'ten
  /// tamamlarsa o pencerede gelenler kaçmıyor.
  resumed,
}

/// STOMP istemcisini kuran fabrika; testler sahte bir istemci veriyor.
typedef StompClientFactory = StompClient Function(StompConfig config);

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
///
/// **Yeniden bağlanma üç şeyi birlikte yapıyor**, üçü de bir zamanlar eksikti:
/// token CONNECT anında okunuyor (`beforeConnect`), böylece `AuthInterceptor`
/// erişim token'ını yenilemişse yeni bağlantı yenisiyle açılıyor; kopan
/// bağlantının abonelik kayıtları siliniyor, böylece [_onConnect] gerçekten
/// yeniden `SUBSCRIBE` gönderiyor (eski hâlinde kayıt silinmediği için
/// yeniden bağlanan soket hiçbir kanala abone olmuyordu); ve her geçiş
/// [connectionEvents] üzerinden duyuruluyor, böylece sohbet ekranları
/// kopukken gelenleri REST'ten tamamlıyor.
class RealtimeClient {
  RealtimeClient._({
    TokenStorage? tokenStorage,
    SessionManager? sessionManager,
    StompClientFactory? stompClientFactory,
    Future<void> Function()? sessionProbe,
    DateTime Function()? now,
  }) : _tokenStorage = tokenStorage ?? TokenStorage(),
       _sessionManager = sessionManager,
       _stompClientFactory = stompClientFactory ?? _defaultStompClientFactory,
       _sessionProbe = sessionProbe ?? _defaultSessionProbe,
       _now = now ?? DateTime.now {
    _sessionManager?.addListener(_onSessionChanged);
  }

  static final RealtimeClient _instance = RealtimeClient._(
    sessionManager: SessionManager(),
  );

  factory RealtimeClient() => _instance;

  /// Testler için: gerçek Keychain'e, oturum yöneticisine ve sokete gitmeyen
  /// bir örnek.
  ///
  /// [stompClientFactory] verilmezse `connect()` gerçek bir soket açmaya
  /// çalışır; birim testleri sahte bir `StompClient` geçiriyor ve
  /// `StompConfig` geri çağrılarını kendisi tetikliyor. [now] yoklama
  /// aralığının saati; testler ilerletiyor.
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

  /// CONNECT reddedildikten sonra oturumu yoklamalar arasındaki en kısa süre.
  ///
  /// Ret genelde süresi dolmuş erişim token'ı demek; yoklama
  /// `AuthInterceptor`'ın yenileme yolunu tetikliyor ve bir sonraki deneme
  /// yeni token'la açılıyor. Ret başka bir sebeptense (sunucu canlı katmanı
  /// kapattı) her 5 saniyelik denemede `/users/me` çekmemek için aralık var.
  static const Duration _sessionProbeInterval = Duration(seconds: 30);

  /// Kopan bağlantının yeniden denenme aralığı; mobilde şebeke sık
  /// değişiyor, aralık kısa.
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

  /// CONNECT karesine giden başlıklar. `StompConfig` haritayı referansla
  /// tutuyor ve kareyi gönderirken okuyor; [_refreshConnectHeaders] her
  /// bağlantı denemesinden önce güncel token'ı buraya yazıyor.
  final Map<String, String> _connectHeaders = {};

  /// Bağlantı kurulmadan yapılan abonelikler burada bekliyor; CONNECT
  /// tamamlanınca hepsi sırayla kuruluyor.
  final Map<String, StreamController<RealtimeEvent>> _controllers = {};
  final Map<String, StompUnsubscribe> _subscriptions = {};

  final StreamController<RealtimeConnectionEvent> _connectionEvents =
      StreamController<RealtimeConnectionEvent>.broadcast();

  /// Sunucuyla bağlantı kurulu mu.
  bool get isConnected => _connected;

  /// Bağlantının durum geçişleri; bkz. [RealtimeConnectionEvent].
  Stream<RealtimeConnectionEvent> get connectionEvents =>
      _connectionEvents.stream;

  static StompClient _defaultStompClientFactory(StompConfig config) =>
      StompClient(config: config);

  /// Oturumu REST üzerinden yoklar; amaç isteğin kendisi değil, `401`
  /// alınca `AuthInterceptor`'ın token'ı yenilemesi. Yenileme de tutmazsa
  /// interceptor oturumu kapatıyor ve [_onSessionChanged] bağlantıyı
  /// bırakıyor.
  static Future<void> _defaultSessionProbe() async {
    try {
      await ApiClient().get<void>(ApiPaths.currentUser, parse: (_) {});
    } on ApiException {
      // Yut: yoklamanın sonucu değil yan etkisi (yenileme) önemli.
    }
  }

  /// Bağlantıyı açar. Zaten açıksa hiçbir şey yapmıyor.
  ///
  /// Oturum yoksa (token okunamıyorsa) sessizce vazgeçiyor: sohbet ekranı
  /// REST ile zaten çalışıyor, kullanıcıya gösterilecek bir hata yok.
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

  /// Güncel erişim token'ını CONNECT başlığına yazar; token yoksa `false`.
  Future<bool> _refreshConnectHeaders() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      _connectHeaders.remove('Authorization');
      return false;
    }
    _connectHeaders['Authorization'] = 'Bearer $token';
    return true;
  }

  /// Her bağlantı denemesinden önce çalışıyor: ilkinde de, kütüphanenin
  /// kendi yeniden denemelerinde de. Token'ı burada tazelemek yeniden
  /// bağlanmanın yenilenmiş token'la açılmasını sağlıyor.
  ///
  /// Token kalmadıysa oturum kapanmış demektir; istemci durduruluyor ki
  /// giriş ekranında beş saniyede bir reddedilen CONNECT denenmesin.
  Future<void> _beforeConnect(StompClient client) async {
    if (!identical(client, _client)) return;
    if (await _refreshConnectHeaders()) return;
    _teardownClient();
  }

  void _onConnect(StompClient client) {
    if (!identical(client, _client)) return;
    _connected = true;
    // Bekleyen abonelikler ve yeniden bağlanma sonrası eskiler yeniden
    // kuruluyor: STOMP abonelikleri bağlantıyla birlikte düşüyor.
    for (final destination in _controllers.keys.toList()) {
      _subscribe(destination);
    }
    _connectionEvents.add(RealtimeConnectionEvent.connected);
  }

  /// Soket kapandı ya da sunucu DISCONNECT'i onayladı.
  ///
  /// Abonelik kayıtları burada siliniyor: kütüphane her denemede yeni bir
  /// bağlantı kurduğu için eski `unsubscribe` işlevleri ölü; kayıt kalırsa
  /// [_subscribe] "zaten abone" sanıp yeniden `SUBSCRIBE` göndermiyor.
  /// Hiç bağlanamamış bir deneme de buraya düşüyor; o zaman duyurulacak
  /// bir kopuş yok.
  void _onDisconnected(StompClient client) {
    if (!identical(client, _client)) return;
    _subscriptions.clear();
    if (!_connected) return;
    _connected = false;
    _connectionEvents.add(RealtimeConnectionEvent.disconnected);
  }

  /// Bağlantı kurulmadan gelen hata karesi CONNECT'in reddi demek; sunucu
  /// ardından soketi kapatıyor ve kütüphane yeniden deniyor. Ret büyük
  /// olasılıkla süresi dolmuş token; oturum yoklanınca token yenileniyor ve
  /// bir sonraki deneme onu okuyor. Oturum bittiyse [disconnect] istemciyi
  /// çoktan bırakmıştır; eski istemcinin geç karesi kimlik kontrolünden
  /// geçemez, ayrıca oturum bakmaya gerek yok.
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

  /// Uygulama ön plana döndü ya da ağ geri geldi.
  ///
  /// Dinleyen kimse yoksa hiçbir şey yapmıyor: bağlantıyı açan ekranlar,
  /// boş yere soket tutulmuyor. Bağlantı yoksa ya da çağıran soketin ölmüş
  /// olabileceğini söylüyorsa ([suspectStale]: uzun süre arka planda kalma,
  /// ağ değişimi) kütüphanenin zamanlayıcısı beklenmeden hemen yeni bir
  /// bağlantı kuruluyor. Bağlantı ayaktaysa yalnızca
  /// [RealtimeConnectionEvent.resumed] duyuruluyor.
  void resume({bool suspectStale = false}) {
    if (_controllers.isEmpty) return;
    if (_client == null || !_connected || suspectStale) {
      unawaited(reconnect());
      return;
    }
    _connectionEvents.add(RealtimeConnectionEvent.resumed);
  }

  /// Mevcut bağlantıyı bırakıp yenisini kurar; abonelikler yeni bağlantıda
  /// yeniden açılıyor. Kopuş duyurulduğu için tüketiciler aradaki boşluğu
  /// [RealtimeConnectionEvent.connected] gelince tamamlıyor.
  Future<void> reconnect() {
    final wasConnected = _connected;
    _teardownClient();
    if (wasConnected) {
      _connectionEvents.add(RealtimeConnectionEvent.disconnected);
    }
    return connect();
  }

  /// İstemciyi durdurur; abonelik akışları açık kalıyor, yeni bağlantıda
  /// yeniden kurulacaklar.
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

  /// Bağlantıyı kapatır ve bütün abonelikleri bırakır. Çıkışta çağrılıyor;
  /// oturum başka bir yoldan bittiğinde de [_onSessionChanged] çağırıyor.
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

    // İstemci akışlar kapanmadan, eşzamanlı olarak bırakılıyor: bu noktadan
    // sonra eski soketten gelen hiçbir kare kimlik kontrolünden geçemez.
    _teardownClient();

    for (final controller in controllers) {
      await controller.close();
    }
  }
}
