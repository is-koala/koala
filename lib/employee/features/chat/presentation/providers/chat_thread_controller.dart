import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/conversation_page.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/message_sender.dart';
import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/chat/models/messaging_gate_error_codes.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

/// Tek sohbetin durumu: mesajlar, gönderim, canlı olaylar; iki taraf ortak.
class ChatThreadController extends ChangeNotifier {
  ChatThreadController({
    required this.conversationId,
    List<ChatParticipant> participants = const [],
    ChatService? chatService,
    RealtimeClient? realtimeClient,
  }) : _participants = List.unmodifiable(participants),
       _chatService = chatService ?? ChatService(),
       _realtimeClient = realtimeClient ?? RealtimeClient();

  final String conversationId;
  final ChatService _chatService;
  final RealtimeClient _realtimeClient;

  /// Listeden gelen anlık görüntüyle başlar, `READ` olayları `lastReadAt`'i
  /// canlı tutar; grup için ayrı katılımcı ucu yok.
  List<ChatParticipant> _participants;

  /// Backend'in `realtime.typingTimeout`'uyla aynı.
  static const Duration _typingTimeout = Duration(seconds: 5);

  /// Her tuşta kare göndermenin anlamı yok.
  static const Duration _typingThrottle = Duration(seconds: 2);

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isCounterpartTyping = false;
  String? _errorMessage;
  String? _blockedMessage;
  MessagingAvailability? _gate;
  String? _currentUserId;

  StreamSubscription<RealtimeEvent>? _events;
  StreamSubscription<RealtimeConnectionEvent>? _connection;
  Timer? _typingReset;
  DateTime? _lastTypingSentAt;

  bool _disposed = false;
  int _loadGeneration = 0;

  /// Canlı akışta boşluk oluştu mu; `connected` gelince REST'ten tamamlanır.
  bool _needsCatchUp = false;

  Future<void>? _catchingUp;

  /// Sayfa başına 30 mesaj; daha uzun kopuklukta en yeni sayfalar esas.
  static const int _catchUpPageLimit = 3;

  List<Message> get messages => List.unmodifiable(_messages);

  /// İkili sohbette ve eski sunucuda boş olabilir.
  List<ChatParticipant> get participants => _participants;

  bool get isLoading => _isLoading;

  bool get isSending => _isSending;

  bool get isCounterpartTyping => _isCounterpartTyping;

  String? get errorMessage => _errorMessage;

  /// Engel yüzünden kapandıysa sunucunun açıklaması. Engel iki yönlü; sunucu
  /// sohbeti açarken de gönderirken de `403` döndürüyor. Metin sunucudan olduğu
  /// gibi.
  String? get blockedMessage => _blockedMessage;

  /// Mesajlaşma kapısı kapattıysa sebebi (`403 MESSAGING_PAYMENT_REQUIRED`,
  /// `409 MESSAGING_WINDOW_CLOSED`). Engelden ayrı: kapı hata değil, metni
  /// tarafa göre sayfa seçiyor. Başarılı yükleme kapıyı temizler.
  MessagingAvailability? get gate => _gate;

  /// Hızlı sekme geçişinde ekran `load()` bitmeden atılabiliyor; düz
  /// `notifyListeners()` "used after being disposed" ile düşürürdü.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  MessageSender senderOf(Message message) =>
      MessageSender.resolve(message, _participants);

  /// [message]'ı görenler: oturum sahibi dışında `lastReadAt`'i gönderimden
  /// geri olmayanlar (ayrılanlar dâhil). Eski sunucuda liste boş, görüldü
  /// gizli.
  List<ChatParticipant> readersOf(Message message) {
    return List.unmodifiable(
      _participants.where(
        (participant) =>
            participant.id != _currentUserId &&
            participant.hasReadSince(message.sentAt),
      ),
    );
  }

  /// Canlı akışa bağlanır, mesajları çeker, okundu işaretler. **Önce abone ol,
  /// sonra çek**; çekim sırasında gelenler [_mergeIntoPage] ile kimlikten
  /// birleşir.
  Future<void> load({required String currentUserId}) async {
    final generation = ++_loadGeneration;
    _currentUserId = currentUserId;
    _isLoading = _messages.isEmpty;
    _safeNotify();
    _listenToRealtime();

    try {
      final page = await _chatService.fetchMessages(
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
      if (_disposed || generation != _loadGeneration) return;
      _messages = _mergeIntoPage(page.messages);
      _errorMessage = null;
      _blockedMessage = null;
      _gate = null;

      // Okundu işareti düşse de mesajlar gösterilir.
      try {
        await _chatService.markRead(conversationId);
      } on ApiException {
        // Bir sonraki açılışta tekrar denenir.
      }
    } on ApiException catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      _errorMessage = error.message;
      _captureLock(error);
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  List<Message> _mergeIntoPage(List<Message> page) {
    if (_messages.isEmpty) return page;

    final inPage = {for (final message in page) message.id};
    final extra = _messages.where((message) => !inPage.contains(message.id));
    if (extra.isEmpty) return page;

    return [...page, ...extra]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  /// Kutuyu kilitleyen hataları yakalar: önce kapı, sonra engel. **Kapı
  /// `errorCode` ile tanınıyor**: kapı da engel de `403 ACCESS_DENIED`.
  /// [ApiErrorType.unauthenticated] oturum sonu, [ApiErrorType.forbidden]
  /// engel; kullanıcı atılmaz, kutu kilitlenir.
  void _captureLock(ApiException error) {
    final gate = MessagingAvailability.fromErrorCode(error.errorCode);
    if (gate != null) {
      _gate = gate;
      return;
    }
    _captureBlock(error);
  }

  void _captureBlock(ApiException error) {
    if (error.type != ApiErrorType.forbidden) return;
    _blockedMessage = error.message;
  }

  /// Başarılıysa `true`. Hatada mesaj eklenmez, metin temizlenmez.
  Future<bool> send(String body) async {
    final trimmed = body.trim();
    final userId = _currentUserId;
    if (trimmed.isEmpty || userId == null || _isSending) return false;

    _isSending = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final message = await _chatService.sendMessage(
        conversationId: conversationId,
        currentUserId: userId,
        body: trimmed,
      );
      _appendMessage(message);
      return true;
    } on ApiException catch (error) {
      final gate = MessagingAvailability.fromErrorCode(error.errorCode);
      if (gate != null) {
        // Kapı hata değil: liste hata durumuna düşmez, kutunun yerine açıklama
        // gelir.
        _gate = gate;
      } else {
        _errorMessage = error.message;
        _captureBlock(error);
      }
      return false;
    } finally {
      _isSending = false;
      _safeNotify();
    }
  }

  /// En fazla [_typingThrottle]'da bir.
  void notifyTyping() {
    final now = DateTime.now();
    final last = _lastTypingSentAt;
    if (last != null && now.difference(last) < _typingThrottle) return;

    _lastTypingSentAt = now;
    _realtimeClient.sendTyping(conversationId);
  }

  void _listenToRealtime() {
    if (_disposed || _events != null) return;

    // Bağlantı kurulamazsa ekran REST ile çalışır.
    unawaited(_realtimeClient.connect());

    _connection = _realtimeClient.connectionEvents.listen(_onConnectionEvent);
    _events = _realtimeClient
        .conversationEvents(conversationId)
        .listen(_onEvent);
    // Abonelik CONNECT'ten önce açıldıysa aradaki mesaj kaçmış olabilir; ilk
    // `connected` bunu kapatır.
    _needsCatchUp = !_realtimeClient.isConnected;
  }

  void _onConnectionEvent(RealtimeConnectionEvent event) {
    switch (event) {
      case RealtimeConnectionEvent.disconnected:
        _needsCatchUp = true;
      case RealtimeConnectionEvent.connected:
        if (!_needsCatchUp) return;
        _needsCatchUp = false;
        unawaited(catchUp());
      case RealtimeConnectionEvent.resumed:
        unawaited(catchUp());
    }
  }

  /// Kopukken gelenleri tamamlar.
  ///
  /// En yeni mesaj çapa olur ve yalnız sonrakiler istenir (`after=<id>`). Çapa
  /// bilinmiyorsa (`MESSAGING_AFTER_UNKNOWN`) ya da kopukluk
  /// [_catchUpPageLimit]'ten uzunsa en yeni sayfalardan geriye gidilir.
  /// Gelenler **kimlikle** birleşir. Grupta katılımcı damgaları da tazelenir
  /// (kaçan `READ` bir daha gelmez). Hata olursa eldeki liste kalır.
  Future<void> catchUp() {
    final userId = _currentUserId;
    if (userId == null || _isLoading) return Future.value();
    return _catchingUp ??= _catchUpNow(userId)
        .whenComplete(() => _catchingUp = null);
  }

  Future<void> _catchUpNow(String userId) async {
    final generation = _loadGeneration;
    final anchor = _newestKnownId();

    final List<Message> fetched;
    try {
      if (anchor == null) {
        fetched = await _fetchNewestPages(userId, generation);
      } else {
        final incremental = await _fetchAfter(userId, generation, anchor);
        fetched = incremental == null
            ? await _fetchNewestPages(userId, generation)
            : [
                ...incremental,
                ...await _fetchReadReceiptsIfNeeded(userId, generation),
              ];
      }
    } on ApiException {
      return;
    }

    _mergeFetched(fetched);
    await _refreshParticipants(userId, generation);
  }

  /// Katılımcıları yeniler (yalnız grupta). Üyelikte sunucu esas; okundu
  /// damgası **monoton**, geri alınmaz. Hata yutulur.
  Future<void> _refreshParticipants(String userId, int generation) async {
    if (_participants.isEmpty) return;

    final Conversation conversation;
    try {
      conversation = await _chatService.fetchConversation(
        conversationId: conversationId,
        currentUserId: userId,
      );
    } on ApiException {
      return;
    }
    if (_disposed || generation != _loadGeneration) return;
    if (conversation.participants.isEmpty) return;

    final known = {for (final p in _participants) p.id: p};
    var changed = false;
    final merged = conversation.participants.map((fresh) {
      final current = known[fresh.id];
      final currentStamp = current?.lastReadAt;
      final freshStamp = fresh.lastReadAt;
      final keepsNewer =
          currentStamp != null &&
          (freshStamp == null || freshStamp.isBefore(currentStamp));
      final next = keepsNewer
          ? fresh.copyWith(lastReadAt: currentStamp)
          : fresh;
      if (current == null || !_sameParticipant(current, next)) changed = true;
      return next;
    }).toList();
    if (merged.length != _participants.length) changed = true;
    if (!changed) return;

    _participants = List.unmodifiable(merged);
    _safeNotify();
  }

  bool _sameParticipant(ChatParticipant a, ChatParticipant b) =>
      a.lastReadAt == b.lastReadAt &&
      a.left == b.left &&
      a.fullName == b.fullName &&
      a.role == b.role;

  String? _newestKnownId() {
    Message? newest;
    for (final message in _messages) {
      if (newest == null || message.sentAt.isAfter(newest.sentAt)) {
        newest = message;
      }
    }
    return newest?.id;
  }

  /// Tamamlanamazsa `null`; çağıran eski yola düşer.
  Future<List<Message>?> _fetchAfter(
    String userId,
    int generation,
    String anchor,
  ) async {
    final fetched = <Message>[];
    for (var page = 0; page < _catchUpPageLimit; page++) {
      final MessagePage result;
      try {
        result = await _chatService.fetchMessages(
          conversationId: conversationId,
          currentUserId: userId,
          page: page,
          after: anchor,
        );
      } on ApiException catch (error) {
        if (error.errorCode == MessagingHistoryErrorCodes.afterUnknown) {
          return null;
        }
        rethrow;
      }
      if (_disposed || generation != _loadGeneration) return const [];
      fetched.addAll(result.messages);
      if (result.last || result.messages.isEmpty) return fetched;
    }
    return null;
  }

  /// `after=` kendi mesajlarımızın `readAt`'ini getirmez; okunmamış kendi
  /// mesajımız varsa en yeni sayfa bir kez daha okunur.
  Future<List<Message>> _fetchReadReceiptsIfNeeded(
    String userId,
    int generation,
  ) async {
    final awaitingReceipt = _messages.any(
      (message) => message.isMe && message.readAt == null,
    );
    if (!awaitingReceipt) return const [];

    final result = await _chatService.fetchMessages(
      conversationId: conversationId,
      currentUserId: userId,
    );
    if (_disposed || generation != _loadGeneration) return const [];
    return result.messages;
  }

  Future<List<Message>> _fetchNewestPages(String userId, int generation) async {
    final known = {for (final message in _messages) message.id};
    final fetched = <Message>[];
    for (var page = 0; page < _catchUpPageLimit; page++) {
      final result = await _chatService.fetchMessages(
        conversationId: conversationId,
        currentUserId: userId,
        page: page,
      );
      if (_disposed || generation != _loadGeneration) return const [];
      fetched.addAll(result.messages);

      final reachedKnown = result.messages.any(known.contains);
      if (reachedKnown || result.last || result.messages.isEmpty) break;
    }
    return fetched;
  }

  void _mergeFetched(List<Message> fetched) {
    if (fetched.isEmpty) return;

    final byId = {for (final message in fetched) message.id: message};
    var changed = false;
    var unreadFromCounterpart = false;

    final merged = <Message>[];
    for (final existing in _messages) {
      final fresh = byId[existing.id];
      if (fresh == null || _sameState(existing, fresh)) {
        merged.add(existing);
        continue;
      }
      merged.add(fresh);
      changed = true;
    }

    final present = {for (final message in merged) message.id};
    for (final message in fetched) {
      if (!present.add(message.id)) continue;
      merged.add(message);
      changed = true;
      if (!message.isMe) unreadFromCounterpart = true;
    }

    if (!changed) return;

    merged.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    _messages = merged;
    _safeNotify();

    if (unreadFromCounterpart) unawaited(_markReadQuietly());
  }

  bool _sameState(Message existing, Message fresh) =>
      existing.readAt == fresh.readAt && existing.body == fresh.body;

  void _onEvent(RealtimeEvent event) {
    final userId = _currentUserId;
    if (userId == null) return;

    switch (event.type) {
      case RealtimeEventType.message:
        final body = event.message;
        if (body == null) return;

        _appendMessage(
          Message.fromJson(
            body,
            conversationId: conversationId,
            currentUserId: userId,
          ),
        );

        unawaited(_markReadQuietly());

      case RealtimeEventType.typing:
        if (event.userId == userId) return;
        _setTyping();

      case RealtimeEventType.read:
        if (event.userId == userId) return;
        final readAt = event.lastReadAt ?? event.at ?? DateTime.now();
        _markParticipantRead(event.userId, readAt);
        _markOwnMessagesRead(readAt);

      case RealtimeEventType.presence:
      case RealtimeEventType.unknown:
        return;
    }
  }

  /// Gönderilen mesaj hem `POST` yanıtından hem canlı kanaldan geliyor.
  void _appendMessage(Message message) {
    if (_messages.any((existing) => existing.id == message.id)) return;

    _messages = [..._messages, message];
    _safeNotify();
  }

  void _setTyping() {
    _isCounterpartTyping = true;
    _safeNotify();

    _typingReset?.cancel();
    _typingReset = Timer(_typingTimeout, () {
      _isCounterpartTyping = false;
      _safeNotify();
    });
  }

  /// Damgayı ileri alır, geri almaz; listede olmayan okuyanı yok sayar.
  void _markParticipantRead(String? readerId, DateTime readAt) {
    if (readerId == null) return;

    var changed = false;
    _participants = List.unmodifiable(
      _participants.map((participant) {
        if (participant.id != readerId) return participant;
        final current = participant.lastReadAt;
        if (current != null && !current.isBefore(readAt)) return participant;
        changed = true;
        return participant.copyWith(lastReadAt: readAt);
      }),
    );

    if (changed) _safeNotify();
  }

  void _markOwnMessagesRead(DateTime readAt) {
    var changed = false;

    _messages = _messages.map((message) {
      if (!message.isMe || message.readAt != null) return message;
      changed = true;
      return message.copyWith(readAt: readAt, status: MessageStatus.read);
    }).toList();

    if (changed) _safeNotify();
  }

  Future<void> _markReadQuietly() async {
    try {
      await _chatService.markRead(conversationId);
    } on ApiException {
      // Okundu bilgisi kritik değil.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _typingReset?.cancel();
    unawaited(_events?.cancel());
    unawaited(_connection?.cancel());
    super.dispose();
  }
}
