import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

/// Sohbet listesinin durumu; `GET /conversations` rolden bağımsız olduğu için
/// iki taraf ortak.
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

  /// Art arda tetikleyiciler aynı isteği paylaşır.
  Future<void>? _refreshing;

  /// Canlı akışta boşluk oluştu mu; `connected` gelince liste bir kez
  /// tazelenir.
  bool _needsCatchUp = false;

  /// İlk çekim sürerken gelen olaylar [_pendingEvents]'te bekler.
  bool _buffering = false;
  final List<RealtimeEvent> _pendingEvents = [];

  /// Aynı mesaj ikinci kez gelirse sayaç bir daha artmasın; sınırlı tutuluyor.
  final Set<String> _seenMessageIds = {};
  static const int _seenMessageLimit = 200;

  bool _disposed = false;

  /// Her abonelik sunucuda bir yetki sorgusu; boşuna açık tutulmuyor.
  final Map<String, StreamSubscription<RealtimeEvent>> _presence = {};

  List<Conversation> get conversations => List.unmodifiable(_conversations);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// Hızlı sekme geçişinde `PageView` ekranı `load()` bitmeden atabiliyor; düz
  /// `notifyListeners()` "used after being disposed" ile düşürürdü.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Canlı akışa bağlanır, sohbetleri çeker. **Önce abone ol, sonra çek:**
  /// tersinde aradaki mesaj kayboluyor. Çekim sırasında gelenler bekletilir;
  /// anlık görüntünün saydığı mesaj `lastMessageAt` karşılaştırmasıyla ikinci
  /// kez sayılmaz.
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

  void _flushPendingEvents() {
    if (_disposed || _pendingEvents.isEmpty) return;
    final pending = List<RealtimeEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    pending.forEach(_onUserEvent);
  }

  /// Çevrimiçi bilgisi düşerse sohbetler yine gösterilir.
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

  /// Kullanıcıya özel kuyruk; kendi ikinci cihazından yazılan da buradan gelir.
  void _listenToMessages() {
    if (_disposed || _messages != null) return;

    unawaited(_realtimeClient.connect());
    _connection = _realtimeClient.connectionEvents.listen(_onConnectionEvent);
    _messages = _realtimeClient.userMessageEvents().listen(_onUserEvent);
    // Abonelik CONNECT'ten önce açıldıysa aradaki mesaj kaçmış olabilir; ilk
    // `connected` bunu kapatır.
    _needsCatchUp = !_realtimeClient.isConnected;
  }

  /// Kopukken gelenler canlı kanaldan gelmeyecek; liste sunucudan yeniden
  /// çekilir.
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

  /// Kuyrukta okundu bilgisi de geliyor.
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
        break;
    }
  }

  /// Rozet **yalnız okuyan bizsek** sıfırlanır: başka cihazda okunan sohbet
  /// burada da okunmuş sayılsın. Karşı tarafın okuması bizim sayacı
  /// değiştirmez.
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
    // Yeni sohbetin ilk mesajı; liste tazelenmeli.
    if (index == -1) {
      unawaited(refresh());
      return;
    }

    final existing = _conversations[index];
    // Satır bu mesajı zaten içeriyorsa (geç gelen kopya) sayaç artmaz.
    final lastMessageAt = existing.lastMessageAt;
    if (lastMessageAt != null && !message.sentAt.isAfter(lastMessageAt)) {
      return;
    }
    final updated = existing.copyWith(
      lastMessage: message.body,
      lastMessageAt: message.sentAt,
      unreadCount: message.isMe
          ? existing.unreadCount
          : existing.unreadCount + 1,
    );

    _conversations = [
      updated,
      ..._conversations.where((c) => c.id != conversationId),
    ];
    _safeNotify();
  }

  bool _remember(String messageId) {
    if (!_seenMessageIds.add(messageId)) return false;
    if (_seenMessageIds.length > _seenMessageLimit) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }
    return true;
  }

  /// Göstergesiz yeniden çeker: tanınmayan sohbete mesaj, sekmeye dönüş (grup
  /// için canlı olay yok), yeniden bağlanma ya da ön plana dönüş. İlk yükleme
  /// olmadıysa bir şey yapmaz; uçan tazeleme paylaşılır.
  Future<void> refresh() {
    final userId = _currentUserId;
    if (userId == null) return Future.value();
    return _refreshing ??= _refreshNow(userId)
        .whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshNow(String userId) async {
    try {
      final page = await _chatService.fetchConversations(currentUserId: userId);
      if (_disposed) return;
      _conversations = await _withPresence(page.conversations);
      _syncPresenceSubscriptions();
      _safeNotify();
    } on ApiException {
      // Eldeki liste kalır; kullanıcı elle tazeleyebilir.
    }
  }

  /// Presence abonelikleri listedeki karşı taraflarla eşitlenir; listeden düşen
  /// bırakılır.
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
