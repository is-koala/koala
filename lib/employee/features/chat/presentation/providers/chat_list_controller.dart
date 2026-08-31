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

  /// Sohbetleri çeker, çevrimiçi bilgisini işler ve canlı akışa bağlanır.
  Future<void> load({required String currentUserId}) async {
    _currentUserId = currentUserId;
    _isLoading = _conversations.isEmpty;
    _errorMessage = null;
    _safeNotify();

    try {
      final page = await _chatService.fetchConversations(
        currentUserId: currentUserId,
      );
      if (_disposed) return;
      _conversations = await _withPresence(page.conversations);
      _listenToMessages();
      _syncPresenceSubscriptions();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
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
    _messages = _realtimeClient.userMessageEvents().listen(_onUserEvent);
  }

  /// Kişisel kuyruktan gelen olaylar. Kuyruk yalnızca mesaj taşımıyor:
  /// okundu bilgisi de buradan geliyor.
  void _onUserEvent(RealtimeEvent event) {
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

    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    // Yeni bir sohbetin ilk mesajı: liste onu henüz tanımıyor, tazelenmesi
    // gerekiyor.
    if (index == -1) {
      unawaited(_reloadQuietly());
      return;
    }

    final message = Message.fromJson(
      body,
      conversationId: conversationId,
      currentUserId: userId,
    );

    final existing = _conversations[index];
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

  Future<void> _reloadQuietly() async {
    final userId = _currentUserId;
    if (userId == null) return;

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
    for (final subscription in _presence.values) {
      unawaited(subscription.cancel());
    }
    _presence.clear();
    super.dispose();
  }
}
