import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

/// Tek bir sohbetin durumu: mesajlar, gönderim ve canlı olaylar.
///
/// Çalışan ve işveren sohbet ekranları aynı davranışa sahip; mantık burada
/// tek yerde duruyor. Sayfa yalnızca çiziyor.
class ChatThreadController extends ChangeNotifier {
  ChatThreadController({
    required this.conversationId,
    ChatService? chatService,
    RealtimeClient? realtimeClient,
  }) : _chatService = chatService ?? ChatService(),
       _realtimeClient = realtimeClient ?? RealtimeClient();

  final String conversationId;
  final ChatService _chatService;
  final RealtimeClient _realtimeClient;

  /// Backend'in `realtime.typingTimeout` varsayılanıyla aynı: bu süre içinde
  /// yeni bir olay gelmezse gösterge sönüyor.
  static const Duration _typingTimeout = Duration(seconds: 5);

  /// Kullanıcı yazarken sunucuya en fazla bu sıklıkla haber veriliyor; her
  /// tuşta kare göndermenin anlamı yok.
  static const Duration _typingThrottle = Duration(seconds: 2);

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isCounterpartTyping = false;
  String? _errorMessage;
  String? _currentUserId;

  StreamSubscription<RealtimeEvent>? _events;
  Timer? _typingReset;
  DateTime? _lastTypingSentAt;

  bool _disposed = false;

  List<Message> get messages => List.unmodifiable(_messages);

  bool get isLoading => _isLoading;

  bool get isSending => _isSending;

  /// Karşı taraf şu an yazıyor mu.
  bool get isCounterpartTyping => _isCounterpartTyping;

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

  /// Mesajları çeker, sohbeti okundu işaretler ve canlı akışa bağlanır.
  Future<void> load({required String currentUserId}) async {
    _currentUserId = currentUserId;
    _isLoading = _messages.isEmpty;
    _errorMessage = null;
    _safeNotify();

    try {
      final page = await _chatService.fetchMessages(
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
      if (_disposed) return;
      _messages = page.messages;
      _listenToRealtime();

      // Okundu işaretlemek listedeki sayacı sıfırlıyor; başarısız olması
      // mesajları göstermeyi engellememeli.
      try {
        await _chatService.markRead(conversationId);
      } on ApiException {
        // Yut: bir sonraki açılışta tekrar denenecek.
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Mesaj gönderir. Başarılıysa `true` döner.
  ///
  /// Hata durumunda mesaj listeye eklenmiyor ve çağıran taraf metin alanını
  /// temizlemiyor: kullanıcı yazdığını kaybetmemeli.
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
      _errorMessage = error.message;
      return false;
    } finally {
      _isSending = false;
      _safeNotify();
    }
  }

  /// Karşı tarafa "yazıyor" bilgisi gönderir.
  ///
  /// Kısıtlanıyor: her tuş vuruşunda değil, en fazla [_typingThrottle]'da bir.
  void notifyTyping() {
    final now = DateTime.now();
    final last = _lastTypingSentAt;
    if (last != null && now.difference(last) < _typingThrottle) return;

    _lastTypingSentAt = now;
    _realtimeClient.sendTyping(conversationId);
  }

  void _listenToRealtime() {
    if (_disposed || _events != null) return;

    // Bağlantı kurulamazsa akış hiç olay üretmiyor; ekran REST'ten gelen
    // mesajlarla çalışmaya devam ediyor.
    unawaited(_realtimeClient.connect());

    _events = _realtimeClient
        .conversationEvents(conversationId)
        .listen(_onEvent);
  }

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

        // Ekran açıkken gelen mesaj anında okunmuş sayılıyor.
        unawaited(_markReadQuietly());

      case RealtimeEventType.typing:
        // Kendi yazdığımızın yankısı gösterilmemeli.
        if (event.userId == userId) return;
        _setTyping();

      case RealtimeEventType.read:
        if (event.userId == userId) return;
        _markOwnMessagesRead(event.at ?? DateTime.now());

      case RealtimeEventType.presence:
      case RealtimeEventType.unknown:
        return;
    }
  }

  /// Aynı mesajı iki kez eklemeyi önler: gönderdiğimiz mesaj hem `POST`
  /// yanıtından hem canlı kanaldan geliyor.
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
      // Yut: okundu bilgisi kritik değil.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _typingReset?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }
}
