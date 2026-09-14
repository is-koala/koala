import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

/// Sohbet listesinin durumu: konuşmalar, çevrimiçi bilgisi ve canlı akış.
///
/// Çalışan ve işveren listeleri aynı davranışa sahip — `GET /conversations`
/// oturum sahibinin bütün sohbetlerini rolüne bakmadan döndürüyor — o yüzden
/// mantık burada tek yerde duruyor.
class ChatListController extends ChangeNotifier {
  ChatListController({ChatService? chatService, RealtimeClient? realtimeClient})
    : _chatService = chatService ?? ChatService(),
      _realtimeClient = realtimeClient ?? RealtimeClient();

  final ChatService _chatService;
  final RealtimeClient _realtimeClient;

  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;

  StreamSubscription<RealtimeEvent>? _messages;
  StreamSubscription<RealtimeConnectionEvent>? _connection;

  /// Uçuştaki sessiz tazeleme; art arda gelen tetikleyiciler (ön plana dönüş
  /// + yeniden bağlanma) aynı isteği paylaşıyor, liste iki kez kurulmuyor.
  Future<void>? _refreshing;

  /// Canlı akışta bir boşluk oluştu mu: bağlantı koptu ya da abonelik
  /// bağlantı yokken açıldı. `connected` gelince liste bir kez tazeleniyor.
  bool _needsCatchUp = false;

  /// İlk liste çekimi sürüyor; bu sırada gelen kuyruk olayları
  /// [_pendingEvents]'te bekliyor, liste gelince işleniyor.
  bool _buffering = false;
  final List<RealtimeEvent> _pendingEvents = [];

  /// Canlı kanaldan işlenen son mesaj kimlikleri. Aynı mesaj ikinci kez
  /// gelirse (yeniden abonelik, iki kanal) okunmamış sayacı bir daha
  /// artmamalı. Sınırlı tutuluyor; liste için yakın geçmiş yetiyor.
  final Set<String> _seenMessageIds = {};
  static const int _seenMessageLimit = 200;

  bool _disposed = false;

  /// Karşı taraf kimliği → presence aboneliği. Liste değiştikçe eklenip
  /// çıkarılıyor; her abonelik sunucuda bir yetki sorgusu demek, boşuna
  /// açık tutulmamalı.
  final Map<String, StreamSubscription<RealtimeEvent>> _presence = {};

  List<Conversation> get conversations => List.unmodifiable(_conversations);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// Sayfa atıldıktan sonra gelen geç yanıtlar dinleyicileri uyandırmamalı.
  ///
  /// Navbar'da sekmeler arasında hızlıca gezinirken `PageView` ekranı
  /// `load()` daha bitmeden atabiliyor; süslenmemiş `notifyListeners()`
  /// o noktada "used after being disposed" ile uygulamayı düşürüyor.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Canlı akışa bağlanır, sohbetleri çeker ve çevrimiçi bilgisini işler.
  ///
  /// Sıra bilerek böyle: **önce abone ol, sonra listeyi çek.** Tersi
  /// yapılınca liste yanıtı ile `SUBSCRIBE` arasına düşen mesaj kayboluyordu.
  /// Çekim sürerken kuyruktan gelenler [_pendingEvents]'te bekliyor; liste
  /// gelince sırayla işleniyor. Sunucu anlık görüntüsünün zaten saydığı bir
  /// mesajı ikinci kez saymamak için [_onMessageEvent] `sentAt`'i satırın
  /// `lastMessageAt`'iyle karşılaştırıyor.
  Future<void> load({required String currentUserId}) async {
    _currentUserId = currentUserId;
    _isLoading = _conversations.isEmpty;
    _errorMessage = null;
    _safeNotify();
    _listenToMessages();
    _buffering = true;

    try {
      final page = await _chatService.fetchConversations(
        currentUserId: currentUserId,
      );
      if (_disposed) return;
      _conversations = await _withPresence(page.conversations);
      _syncPresenceSubscriptions();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _buffering = false;
      _safeNotify();
      _flushPendingEvents();
    }
  }

  /// Çekim sürerken biriken kuyruk olaylarını sırayla işler.
  void _flushPendingEvents() {
    if (_disposed || _pendingEvents.isEmpty) return;
    final pending = List<RealtimeEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    pending.forEach(_onUserEvent);
  }

  /// Çevrimiçi bilgisini tek istekte alıp sohbetlere işler.
  ///
  /// Bu çağrı başarısız olursa sohbetler yine gösteriliyor: yeşil noktanın
  /// yokluğu listeyi engellememeli.
  Future<List<Conversation>> _withPresence(
    List<Conversation> conversations,
  ) async {
    if (conversations.isEmpty) return conversations;

    try {
      final ids = conversations
          .map((conversation) => conversation.counterpartId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final presence = await _chatService.fetchPresence(ids);

      return conversations
          .map(
            (conversation) => conversation.copyWith(
              isOnline: presence[conversation.counterpartId]?.online ?? false,
            ),
          )
          .toList();
    } on ApiException {
      return conversations;
    }
  }

  /// Kullanıcıya özel kuyruk: hangi sohbete gelirse gelsin yeni mesaj buradan
  /// düşüyor. Sunucu kopyayı iki tarafa da gönderiyor, yani kendi ikinci
  /// cihazından yazdığında bu liste de güncelleniyor.
  void _listenToMessages() {
    if (_disposed || _messages != null) return;

    unawaited(_realtimeClient.connect());
    _connection = _realtimeClient.connectionEvents.listen(_onConnectionEvent);
    _messages = _realtimeClient.userMessageEvents().listen(_onUserEvent);
    // Abonelik CONNECT'ten önce açıldıysa REST yanıtıyla SUBSCRIBE arasına
    // düşen mesaj kaçmış olabilir; ilk `connected` bunu kapatıyor.
    _needsCatchUp = !_realtimeClient.isConnected;
  }

  /// Bağlantı geçişleri. Kopukken gelen mesajlar canlı kanaldan asla
  /// gelmeyecek; liste sunucudan yeniden çekilerek tamamlanıyor (sunucunun
  /// son mesaj ve okunmamış sayısı doğru kaynak, çift sayım olmuyor).
  void _onConnectionEvent(RealtimeConnectionEvent event) {
    switch (event) {
      case RealtimeConnectionEvent.disconnected:
        _needsCatchUp = true;
      case RealtimeConnectionEvent.connected:
        if (!_needsCatchUp) return;
        _needsCatchUp = false;
        unawaited(refresh());
      case RealtimeConnectionEvent.resumed:
        unawaited(refresh());
    }
  }

  /// Kişisel kuyruktan gelen olaylar. Kuyruk yalnızca mesaj taşımıyor:
  /// okundu bilgisi de buradan geliyor.
  void _onUserEvent(RealtimeEvent event) {
    if (_buffering) {
      _pendingEvents.add(event);
      return;
    }
    switch (event.type) {
      case RealtimeEventType.message:
        _onMessageEvent(event);
      case RealtimeEventType.read:
        _onReadEvent(event);
      case RealtimeEventType.typing:
      case RealtimeEventType.presence:
      case RealtimeEventType.unknown:
        // Yazıyor bilgisi ve varlık listede gösterilmiyor; varlık ayrıca
        // kendi kanalından geliyor.
        break;
    }
  }

  /// Bir sohbetin okunduğu bilgisi.
  ///
  /// **Yalnızca okuyan kişi bizsek** rozet sıfırlanıyor: telefonda okunan
  /// sohbetin tablette de okunmuş sayılması için. Karşı taraf okuduğunda
  /// bizim okunmamışımız değişmiyor — o, bizim gönderdiğimiz mesajların
  /// okundu bilgisi ve listede gösterilmiyor.
  void _onReadEvent(RealtimeEvent event) {
    final conversationId = event.conversationId;
    if (conversationId == null || event.userId != _currentUserId) return;

    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index == -1) return;

    final existing = _conversations[index];
    if (existing.unreadCount == 0) return;

    _conversations = [
      for (final conversation in _conversations)
        conversation.id == conversationId
            ? conversation.copyWith(unreadCount: 0)
            : conversation,
    ];
    _safeNotify();
  }

  void _onMessageEvent(RealtimeEvent event) {
    final userId = _currentUserId;
    final conversationId = event.conversationId;
    final body = event.message;
    if (userId == null || conversationId == null || body == null) return;

    final message = Message.fromJson(
      body,
      conversationId: conversationId,
      currentUserId: userId,
    );
    if (!_remember(message.id)) return;

    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    // Yeni bir sohbetin ilk mesajı: liste onu henüz tanımıyor, tazelenmesi
    // gerekiyor.
    if (index == -1) {
      unawaited(refresh());
      return;
    }

    final existing = _conversations[index];
    // Sunucudan gelen satır bu mesajı zaten içeriyorsa (çekim sırasında
    // ya da yeniden bağlanma tamamlamasından sonra geç gelen kopya) sayaç
    // bir daha artmamalı.
    final lastMessageAt = existing.lastMessageAt;
    if (lastMessageAt != null && !message.sentAt.isAfter(lastMessageAt)) {
      return;
    }
    final updated = existing.copyWith(
      lastMessage: message.body,
      lastMessageAt: message.sentAt,
      // Kendi gönderdiğimiz mesaj okunmamış sayılmaz.
      unreadCount: message.isMe
          ? existing.unreadCount
          : existing.unreadCount + 1,
    );

    // En son konuşulan başa geliyor; sunucu da listeyi bu sıraya göre veriyor.
    _conversations = [
      updated,
      ..._conversations.where((c) => c.id != conversationId),
    ];
    _safeNotify();
  }

  /// Mesaj kimliğini kaydeder; daha önce görüldüyse `false`.
  bool _remember(String messageId) {
    if (!_seenMessageIds.add(messageId)) return false;
    if (_seenMessageIds.length > _seenMessageLimit) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }
    return true;
  }

  /// Listeyi yükleme göstergesi açmadan yeniden çeker.
  ///
  /// Çağıranları: kişisel kuyruktan tanınmayan bir sohbete mesaj düşmesi,
  /// sohbet sekmesinin yeniden görünür olması ve canlı bağlantının
  /// kopup gelmesi ya da uygulamanın ön plana dönmesi. Sekme dönüşü
  /// ödemeyle kurulan ilan grubu için: sunucu grup kurulunca canlı olay
  /// göndermiyor, grup ilk mesaja kadar ancak yeniden çekilince listeye
  /// düşüyor. İlk yükleme henüz olmadıysa (oturum sahibi bilinmiyor) hiçbir
  /// şey yapmıyor; onu [load] yapacak. Uçuşta bir tazeleme varsa yenisi
  /// açılmıyor, aynı sonuç bekleniyor.
  Future<void> refresh() {
    final userId = _currentUserId;
    if (userId == null) return Future.value();
    return _refreshing ??= _refreshNow(
      userId,
    ).whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshNow(String userId) async {
    try {
      final page = await _chatService.fetchConversations(currentUserId: userId);
      if (_disposed) return;
      _conversations = await _withPresence(page.conversations);
      _syncPresenceSubscriptions();
      _safeNotify();
    } on ApiException {
      // Yut: eldeki liste duruyor, kullanıcı elle tazeleyebilir.
    }
  }

  /// Presence abonelikleri listedeki karşı taraflarla eşitleniyor.
  ///
  /// Yalnızca paylaşılan konuşması olan kişilere abone olunabiliyor; listedeki
  /// herkes bu şartı zaten sağlıyor. Listeden düşen kişinin aboneliği
  /// bırakılıyor.
  void _syncPresenceSubscriptions() {
    if (_disposed) return;

    final wanted = _conversations
        .map((conversation) => conversation.counterpartId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final id in _presence.keys.toList()) {
      if (wanted.contains(id)) continue;
      unawaited(_presence.remove(id)?.cancel());
    }

    for (final id in wanted) {
      if (_presence.containsKey(id)) continue;
      _presence[id] = _realtimeClient
          .presenceEventsFor(id)
          .listen(_onPresenceEvent);
    }
  }

  void _onPresenceEvent(RealtimeEvent event) {
    final userId = event.userId;
    final online = event.online;
    if (userId == null || online == null) return;

    final index = _conversations.indexWhere(
      (conversation) => conversation.counterpartId == userId,
    );
    if (index == -1) return;

    _conversations = [..._conversations]
      ..[index] = _conversations[index].copyWith(isOnline: online);
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_messages?.cancel());
    unawaited(_connection?.cancel());
    for (final subscription in _presence.values) {
      unawaited(subscription.cancel());
    }
    _presence.clear();
    super.dispose();
  }
}
