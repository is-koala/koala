import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/chat/models/conversation_page.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/chat/models/messaging_gate_error_codes.dart';
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
  String? _blockedMessage;
  MessagingAvailability? _gate;
  String? _currentUserId;

  StreamSubscription<RealtimeEvent>? _events;
  StreamSubscription<RealtimeConnectionEvent>? _connection;
  Timer? _typingReset;
  DateTime? _lastTypingSentAt;

  bool _disposed = false;
  int _loadGeneration = 0;

  /// Canlı akışta boşluk oluştu mu: bağlantı koptu ya da abonelik bağlantı
  /// yokken açıldı. `connected` gelince kaçanlar REST'ten tamamlanıyor.
  bool _needsCatchUp = false;

  /// Uçuştaki tamamlama; art arda tetikleyiciler aynı isteği paylaşıyor.
  Future<void>? _catchingUp;

  /// Tamamlamada en fazla kaç sayfa çekileceği: `after=` kipinde ileriye,
  /// yedek yolda geriye. Sunucu sayfa başına 30 mesaj veriyor; kopukluk
  /// süresince bundan fazlası geldiyse en yeni sayfalar esas alınır, en
  /// eskiler sayfalama açıldığında zaten gelecek.
  static const int _catchUpPageLimit = 3;

  List<Message> get messages => List.unmodifiable(_messages);

  bool get isLoading => _isLoading;

  bool get isSending => _isSending;

  /// Karşı taraf şu an yazıyor mu.
  bool get isCounterpartTyping => _isCounterpartTyping;

  String? get errorMessage => _errorMessage;

  /// Sohbet engelli olduğu için kapandıysa sunucunun kendi açıklaması,
  /// değilse `null`.
  ///
  /// Engel iki yönlü: iki taraftan biri diğerini engellediyse ikisi de
  /// yazamıyor. Sunucu kuralı iki yerde uyguluyor — sohbeti açarken ve mesaj
  /// gönderirken — ve ikisinde de `403` döndürüyor.
  ///
  /// Ekranlar bunu görünce mesaj kutusunu kilitliyor. Metni yeniden
  /// yazmıyoruz: sunucu `Accept-Language: tr` ile zaten "Bu kullanıcıyla
  /// mesajlaşamazsınız." diyor ve sebebini bilen taraf o.
  String? get blockedMessage => _blockedMessage;

  /// Sunucunun mesajlaşma kapısı sohbeti kapattıysa sebebi, değilse `null`.
  ///
  /// `403 MESSAGING_PAYMENT_REQUIRED` (işveren ödemeyi tamamlamadı) ve
  /// `409 MESSAGING_WINDOW_CLOSED` (iptal/ret/iade ya da 7 günlük pencere
  /// doldu). Engelden ayrı tutuluyor: engelin metni sunucudan geliyor ve
  /// kırmızı; kapının metni tarafa göre değişiyor ve bir hata değil, akışın
  /// beklenen bir durağı. Metni sayfa seçiyor
  /// (`MessagingAvailability.noteFor`), çünkü işveren mi çalışan mı
  /// olduğunu bilen o.
  ///
  /// Başarılı bir yükleme kapıyı temizliyor: ödeme geldiyse ekran yeniden
  /// açılınca kutu geri gelmeli.
  MessagingAvailability? get gate => _gate;

  /// Sayfa atıldıktan sonra gelen geç yanıtlar dinleyicileri uyandırmamalı.
  ///
  /// Navbar'da sekmeler arasında hızlıca gezinirken `PageView` ekranı
  /// `load()` daha bitmeden atabiliyor; süslenmemiş `notifyListeners()`
  /// o noktada "used after being disposed" ile uygulamayı düşürüyor.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Canlı akışa bağlanır, mesajları çeker ve sohbeti okundu işaretler.
  ///
  /// Sıra bilerek böyle: **önce abone ol, sonra sayfayı çek.** Tersi
  /// yapılınca sayfa yanıtı ile `SUBSCRIBE` arasına düşen mesaj ne sayfada
  /// ne kanalda oluyordu. Çekim sürerken kanaldan gelenler [_appendMessage]
  /// ile listeye düşüyor; sayfa gelince [_mergeIntoPage] ikisini kimlikle
  /// birleştiriyor, aynı mesaj iki kez durmuyor.
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

      // Okundu işaretlemek listedeki sayacı sıfırlıyor; başarısız olması
      // mesajları göstermeyi engellememeli.
      try {
        await _chatService.markRead(conversationId);
      } on ApiException {
        // Yut: bir sonraki açılışta tekrar denenecek.
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

  /// Sunucu sayfasını eldeki mesajlarla birleştirir: sayfa esas, sayfada
  /// olmayanlar (çekim sırasında kanaldan gelenler) kimlikle eklenir.
  List<Message> _mergeIntoPage(List<Message> page) {
    if (_messages.isEmpty) return page;

    final inPage = {for (final message in page) message.id};
    final extra = _messages.where((message) => !inPage.contains(message.id));
    if (extra.isEmpty) return page;

    return [...page, ...extra]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  /// Mesaj kutusunu kilitleyen hataları yakalar: önce kapı, sonra engel.
  ///
  /// **Kapı `errorCode` ile tanınıyor**, kategoriyle değil: ödeme kapısı da
  /// engel de `403` + `ACCESS_DENIED` olarak geliyor ve ikisini ayıran tek
  /// alan kod. Kapı kodu geldiyse [gate] doluyor, [blockedMessage] boş
  /// kalıyor; ekran ödeme/pencere metnini yazıyor ve kırmızı engel şeridini
  /// çizmiyor.
  ///
  /// Kapı değilse engel ayrımı önemli: [ApiErrorType.unauthenticated]
  /// oturumun bitmesi demek, `AuthInterceptor` onu yenilemeye çalışıyor ve
  /// başaramazsa oturumu kapatıyor; [ApiErrorType.forbidden] ise engel —
  /// kullanıcı oturumdan atılmamalı, mesaj kutusu kilitlenmeli. Tipe
  /// bakılıyor, `statusCode`'a değil: ayrımın kaynağı sunucunun
  /// `errorCategory` alanı, durum kodu yalnızca yedek.
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
      final gate = MessagingAvailability.fromErrorCode(error.errorCode);
      if (gate != null) {
        // Kapı bir hata değil, kutunun kapanma sebebi: mesaj listesi hata
        // durumuna düşmemeli, kutunun yerine açıklama gelmeli.
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

    _connection = _realtimeClient.connectionEvents.listen(_onConnectionEvent);
    _events = _realtimeClient
        .conversationEvents(conversationId)
        .listen(_onEvent);
    // Abonelik CONNECT'ten önce açıldıysa REST yanıtıyla SUBSCRIBE arasına
    // düşen mesaj kaçmış olabilir; ilk `connected` bunu kapatıyor.
    _needsCatchUp = !_realtimeClient.isConnected;
  }

  /// Bağlantı geçişleri. Kopukken gönderilen mesaj canlı kanaldan bir daha
  /// gelmeyecek; boşluk [catchUp] ile kapanıyor.
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

  /// Kopukken gelenleri sunucudan tamamlar.
  ///
  /// Elde mesaj varsa en yenisinin kimliği çapa olur ve sunucudan yalnız
  /// ondan sonrakiler istenir (`after=<id>`, artan sırada). Çapa sunucuda
  /// bilinmiyorsa — başka sohbetin mesajı ya da silinmiş, `400
  /// MESSAGING_AFTER_UNKNOWN` — ya da kopukluk [_catchUpPageLimit] sayfadan
  /// uzun sürdüyse eski yol devreye girer: en yeni sayfa(lar) çekilir ve
  /// bilinen bir mesaja rastlanana kadar geriye gidilir. Artımlı yol
  /// okunmamış kendi mesajımız varken en yeni sayfayı da bir kez okur ki
  /// kopukken okunanların `readAt`'i gelsin. İki yolda da
  /// gelenler eldekiyle **kimlik** üzerinden birleşir: bilinmeyenler
  /// eklenir, bilinenler sunucudaki hâliyle değiştirilir, aynı kimlik
  /// ikinci kez eklenmez. Yeni gelen karşı taraf mesajı varsa sohbet açık
  /// olduğu için okundu işaretlenir. Hata olursa eldeki liste durur; bir
  /// sonraki tetikleyici yine dener.
  Future<void> catchUp() {
    final userId = _currentUserId;
    if (userId == null || _isLoading) return Future.value();
    return _catchingUp ??= _catchUpNow(
      userId,
    ).whenComplete(() => _catchingUp = null);
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
  }

  /// Eldeki en yeni mesajın kimliği; liste boşsa `null`.
  String? _newestKnownId() {
    Message? newest;
    for (final message in _messages) {
      if (newest == null || message.sentAt.isAfter(newest.sentAt)) {
        newest = message;
      }
    }
    return newest?.id;
  }

  /// `after=` ile artımlı çekim. Tamamlanamazsa `null`: çapa bilinmiyor ya
  /// da sayfa sınırı doldu; çağıran eski yola düşer.
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

  /// `after=` yalnız yeni mesajları taşıyor; kopukken karşı tarafın okuduğu
  /// **kendi** mesajlarımızın `readAt`'i ondan gelmez (READ olayı da kopukken
  /// kaçtı). Okunmamış kendi mesajımız varsa en yeni sayfa bir kez daha
  /// okunur ve [_mergeFetched] bilinenleri sunucudaki hâliyle değiştirir.
  /// Hepsi okunmuşsa ya da hiç yoksa ağa çıkılmaz.
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

  /// En yeni sayfadan geriye, bilinen bir mesaja rastlayana ya da
  /// [_catchUpPageLimit] dolana kadar.
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
    unawaited(_connection?.cancel());
    super.dispose();
  }
}
