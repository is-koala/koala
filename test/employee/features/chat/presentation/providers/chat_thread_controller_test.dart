import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

import '../../../../../support/fake_api.dart';

const _me = 'user_me';
const _other = 'user_other';
const _conversationId = 'conv_1';

/// Gerçek soket açmadan olay besleyen sahte canlı istemci.
class FakeRealtimeClient implements RealtimeClient {
  final _controller = StreamController<RealtimeEvent>.broadcast();
  final List<String> typingSentFor = [];
  bool connectCalled = false;

  void emit(RealtimeEvent event) => _controller.add(event);

  @override
  Stream<RealtimeEvent> conversationEvents(String conversationId) =>
      _controller.stream;

  @override
  Stream<RealtimeEvent> presenceEventsFor(String userId) => _controller.stream;

  @override
  Stream<RealtimeEvent> userMessageEvents() => _controller.stream;

  @override
  Future<void> connect() async => connectCalled = true;

  @override
  void sendTyping(String conversationId) => typingSentFor.add(conversationId);

  @override
  Future<void> disconnect() async {}

  @override
  bool get isConnected => connected;

  /// Abonelik anında bağlantı var mı; `false` verilirse denetleyici ilk
  /// `connected`'da boşluğu tamamlamalı.
  bool connected = true;

  final _connection = StreamController<RealtimeConnectionEvent>.broadcast();

  void emitConnection(RealtimeConnectionEvent event) => _connection.add(event);

  @override
  Stream<RealtimeConnectionEvent> get connectionEvents => _connection.stream;

  @override
  void resume({bool suspectStale = false}) {}

  @override
  Future<void> reconnect() async {}
}

Map<String, dynamic> messageBody({
  String id = 'msg_1',
  String senderId = _other,
  String body = 'Merhaba',
  String sentAt = '2026-03-05T10:00:00Z',
  String? readAt,
}) {
  return {
    'id': id,
    'senderId': senderId,
    'body': body,
    'sentAt': sentAt,
    'readAt': readAt,
  };
}

void main() {
  late FakeRealtimeClient realtime;

  ChatThreadController build(FakeApi api) {
    realtime = FakeRealtimeClient();
    return ChatThreadController(
      conversationId: _conversationId,
      chatService: ChatService.withClient(api.client),
      realtimeClient: realtime,
    );
  }

  FakeApi apiWith(List<Map<String, dynamic>> messages) {
    return FakeApi(
      handler: (options) => options.method == 'GET'
          ? FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'content': messages},
              },
            )
          : const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
  }

  group('load', () {
    test('mesajlar çekilir ve okundu işaretlenir', () async {
      final api = apiWith([messageBody()]);
      final thread = build(api);

      await thread.load(currentUserId: _me);

      expect(thread.messages.single.body, 'Merhaba');
      expect(thread.isLoading, isFalse);
      expect(
        api.requests.map((r) => r.path),
        contains('/conversations/$_conversationId/read'),
      );
      expect(realtime.connectCalled, isTrue);
    });

    test('okundu işaretleme patlarsa mesajlar yine gösterilir', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'GET'
            ? FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [messageBody()],
                  },
                },
              )
            : const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Sunucu hatası'},
              ),
      );
      final thread = build(api);

      await thread.load(currentUserId: _me);

      expect(thread.messages, hasLength(1));
      expect(thread.errorMessage, isNull);
    });
  });

  group('canlı mesaj', () {
    test('karşı taraftan gelen mesaj listeye eklenir', () async {
      final thread = build(apiWith(const []));
      await thread.load(currentUserId: _me);

      realtime.emit(
        RealtimeEvent.fromJson({
          'type': 'MESSAGE',
          'conversationId': _conversationId,
          'userId': _other,
          'message': messageBody(id: 'yeni', body: 'Selam'),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(thread.messages.single.body, 'Selam');
      expect(thread.messages.single.isMe, isFalse);
    });

    // Gönderdiğimiz mesaj hem POST yanıtından hem canlı kanaldan geliyor.
    test('aynı mesaj iki kez eklenmiyor', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'GET'
            ? const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'content': []},
                },
              )
            : FakeApiResponse(
                statusCode: 201,
                body: {
                  'success': true,
                  'data': messageBody(id: 'msg_9', senderId: _me, body: 'Ok'),
                },
              ),
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);

      await thread.send('Ok');
      realtime.emit(
        RealtimeEvent.fromJson({
          'type': 'MESSAGE',
          'conversationId': _conversationId,
          'userId': _me,
          'message': messageBody(id: 'msg_9', senderId: _me, body: 'Ok'),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(thread.messages, hasLength(1));
    });
  });

  group('bağlantı geçişleri', () {
    /// Denetleyicinin bir sonraki `notifyListeners` çağrısı; tamamlama sessiz
    /// olduğu için bitişi ancak buradan anlaşılıyor.
    Future<void> nextNotify(ChatThreadController thread) {
      final completer = Completer<void>();
      late final VoidCallback listener;
      listener = () {
        if (!completer.isCompleted) completer.complete();
        thread.removeListener(listener);
      };
      thread.addListener(listener);
      return completer.future;
    }

    int messageFetches(FakeApi api) => api.requests
        .where(
          (r) =>
              r.method == 'GET' &&
              r.path == '/conversations/$_conversationId/messages',
        )
        .length;

    // Sunucunun `since` parametresi yok: en yeni sayfa çekilip kimlikle
    // birleştiriliyor. Kopukken gelen eklenir, eldeki tekrar eklenmez, kopuk
    // sırada okunan kendi mesajımızın `readAt`'i sunucudan gelir.
    test('kopup gelen bağlantı kaçan mesajları kimlikle tamamlar', () async {
      final messages = [
        messageBody(id: 'm1', body: 'Merhaba'),
        messageBody(id: 'm2', senderId: _me, body: 'Selam'),
      ];
      final api = apiWith(messages);
      final thread = build(api);
      await thread.load(currentUserId: _me);
      expect(thread.messages, hasLength(2));

      // Sunucu en yeniden eskiye veriyor.
      messages
        ..clear()
        ..addAll([
          messageBody(
            id: 'm3',
            body: 'Kopukken yazdım',
            sentAt: '2026-03-05T10:05:00Z',
          ),
          messageBody(
            id: 'm2',
            senderId: _me,
            body: 'Selam',
            readAt: '2026-03-05T10:04:00Z',
          ),
          messageBody(id: 'm1', body: 'Merhaba'),
        ]);
      final caughtUp = nextNotify(thread);
      realtime.emitConnection(RealtimeConnectionEvent.disconnected);
      realtime.emitConnection(RealtimeConnectionEvent.connected);
      await caughtUp;

      expect(messageFetches(api), 2);
      expect(thread.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(thread.messages[1].readAt, isNotNull);
      expect(thread.messages.last.body, 'Kopukken yazdım');
      // Ekran açık: karşı tarafın kaçan mesajı okundu işaretlenir.
      await api.requestsReach(4);
      expect(
        api.requests
            .where((r) => r.path == '/conversations/$_conversationId/read')
            .length,
        2,
      );
    });

    test('kesintisiz bağlantıda connected çekme yapmaz', () async {
      final api = apiWith([messageBody()]);
      final thread = build(api);
      await thread.load(currentUserId: _me);

      realtime.emitConnection(RealtimeConnectionEvent.connected);
      await Future<void>.delayed(Duration.zero);

      expect(messageFetches(api), 1);
    });

    test(
      'bağlantı yokken açılan abonelik ilk connected ile tamamlanır',
      () async {
        final messages = [messageBody(id: 'm1')];
        final api = apiWith(messages);
        realtime = FakeRealtimeClient()..connected = false;
        final thread = ChatThreadController(
          conversationId: _conversationId,
          chatService: ChatService.withClient(api.client),
          realtimeClient: realtime,
        );
        await thread.load(currentUserId: _me);

        messages.insert(0, messageBody(id: 'm2', body: 'Arada gelen'));
        final caughtUp = nextNotify(thread);
        realtime.emitConnection(RealtimeConnectionEvent.connected);
        await caughtUp;

        expect(thread.messages.map((m) => m.id), ['m1', 'm2']);
      },
    );

    test('değişiklik yoksa dinleyici uyandırılmaz', () async {
      final api = apiWith([messageBody(id: 'm1')]);
      final thread = build(api);
      await thread.load(currentUserId: _me);
      var notified = 0;
      thread.addListener(() => notified++);

      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await api.requestsReach(3);
      await Future<void>.delayed(Duration.zero);

      expect(messageFetches(api), 2);
      expect(notified, 0);
      expect(thread.messages, hasLength(1));
    });

    // Aynı mesaj hem canlı kanaldan hem tamamlamadan gelirse bir kez durur.
    test('canlı gelen mesaj tamamlamada ikinci kez eklenmez', () async {
      final messages = [messageBody(id: 'm1')];
      final api = apiWith(messages);
      final thread = build(api);
      await thread.load(currentUserId: _me);

      messages.insert(0, messageBody(id: 'm2', body: 'Yeni'));
      realtime.emit(
        RealtimeEvent.fromJson({
          'type': 'MESSAGE',
          'conversationId': _conversationId,
          'userId': _other,
          'message': messageBody(id: 'm2', body: 'Yeni'),
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(thread.messages, hasLength(2));

      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await api.requestsReach(4);
      await Future<void>.delayed(Duration.zero);

      expect(thread.messages.map((m) => m.id), ['m1', 'm2']);
    });

    // Kopukluk bir sayfadan uzun sürdüyse bilinen bir mesaja rastlayana
    // kadar geriye gidilir; sınır üç sayfa.
    test('tamamlama bilinen mesaja kadar sayfalar', () async {
      Map<String, dynamic> at(String id, int minute) =>
          messageBody(id: id, sentAt: '2026-03-05T10:0$minute:00Z');
      final pages = <int, List<Map<String, dynamic>>>{
        0: [at('m5', 5), at('m4', 4)],
        1: [at('m3', 3), at('m2', 2)],
        2: [at('m1', 1)],
      };
      var served = pages[2]!;
      final api = FakeApi(
        handler: (options) {
          if (options.method != 'GET') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true},
            );
          }
          final page = options.queryParameters['page'] as int? ?? 0;
          final content = served == pages[2]! ? served : pages[page]!;
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {'content': content, 'last': page >= 2},
            },
          );
        },
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);
      expect(thread.messages.map((m) => m.id), ['m1']);

      served = pages[0]!;
      final caughtUp = nextNotify(thread);
      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await caughtUp;

      expect(thread.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4', 'm5']);
      expect(messageFetches(api), 4);
    });
  });

  group('yazıyor', () {
    test('karşı tarafın olayı göstergeyi yakar', () async {
      final thread = build(apiWith(const []));
      await thread.load(currentUserId: _me);

      realtime.emit(
        RealtimeEvent.fromJson({'type': 'TYPING', 'userId': _other}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(thread.isCounterpartTyping, isTrue);
    });

    // Kendi yazdığımızın yankısı ekranda görünmemeli.
    test('kendi yazma olayımız yok sayılır', () async {
      final thread = build(apiWith(const []));
      await thread.load(currentUserId: _me);

      realtime.emit(RealtimeEvent.fromJson({'type': 'TYPING', 'userId': _me}));
      await Future<void>.delayed(Duration.zero);

      expect(thread.isCounterpartTyping, isFalse);
    });

    test('notifyTyping kısıtlanıyor, her çağrıda gönderilmiyor', () async {
      final thread = build(apiWith(const []));
      await thread.load(currentUserId: _me);

      thread.notifyTyping();
      thread.notifyTyping();
      thread.notifyTyping();

      expect(realtime.typingSentFor, [_conversationId]);
    });
  });

  group('okundu', () {
    test('karşı taraf okuyunca kendi mesajlarımız okundu olur', () async {
      final thread = build(apiWith([messageBody(id: 'benim', senderId: _me)]));
      await thread.load(currentUserId: _me);
      expect(thread.messages.single.readAt, isNull);

      realtime.emit(
        RealtimeEvent.fromJson({
          'type': 'READ',
          'userId': _other,
          'at': '2026-03-05T11:00:00Z',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(thread.messages.single.readAt, isNotNull);
    });

    test('karşı tarafın mesajları etkilenmez', () async {
      final thread = build(apiWith([messageBody(senderId: _other)]));
      await thread.load(currentUserId: _me);

      realtime.emit(RealtimeEvent.fromJson({'type': 'READ', 'userId': _other}));
      await Future<void>.delayed(Duration.zero);

      expect(thread.messages.single.readAt, isNull);
    });
  });

  group('bilinmeyen olay', () {
    test('uygulamayı düşürmez', () async {
      final thread = build(apiWith(const []));
      await thread.load(currentUserId: _me);

      realtime.emit(RealtimeEvent.fromJson({'type': 'UZAYLI'}));
      await Future<void>.delayed(Duration.zero);

      expect(thread.messages, isEmpty);
    });
  });

  group('send', () {
    test('hata durumunda false döner ve mesaj eklenmez', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'GET'
            ? const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'content': []},
                },
              )
            : const FakeApiResponse(
                statusCode: 400,
                body: {'success': false, 'message': 'Mesaj boş olamaz'},
              ),
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);

      final sent = await thread.send('x');

      expect(sent, isFalse);
      expect(thread.errorMessage, 'Mesaj boş olamaz');
      expect(thread.messages, isEmpty);
    });

    test('boş metin gönderilmez', () async {
      final thread = build(apiWith(const []));
      await thread.load(currentUserId: _me);

      expect(await thread.send('   '), isFalse);
    });
  });

  group('engelli sohbet', () {
    /// Sunucu engelli sohbette `403` ve kendi Türkçe mesajını döndürüyor
    /// (`messages_tr.properties:319`).
    const blocked = FakeApiResponse(
      statusCode: 403,
      body: {'success': false, 'message': 'Bu kullanıcıyla mesajlaşamazsınız.'},
    );

    test('mesaj gönderirken gelen 403 sohbeti kilitliyor', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'GET'
            ? const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'content': []},
                },
              )
            : blocked,
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);

      final sent = await thread.send('Merhaba');

      expect(sent, isFalse);
      // Sunucunun kendi metni gösterilmeli; "yetkin yok" gibi genel bir
      // metne çevrilmemeli.
      expect(thread.blockedMessage, 'Bu kullanıcıyla mesajlaşamazsınız.');
    });

    test('sohbeti açarken gelen 403 de kilitliyor', () async {
      final thread = build(FakeApi(handler: (_) => blocked));

      await thread.load(currentUserId: _me);

      expect(thread.blockedMessage, 'Bu kullanıcıyla mesajlaşamazsınız.');
    });

    test('başarılı tekrar deneme geçmiş engeli ve hatayı temizler', () async {
      var messageRequestCount = 0;
      final thread = build(
        FakeApi(
          handler: (options) {
            if (options.method != 'GET') {
              return const FakeApiResponse(
                statusCode: 200,
                body: {'success': true},
              );
            }

            messageRequestCount++;
            if (messageRequestCount == 1) return blocked;

            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'content': []},
              },
            );
          },
        ),
      );

      await thread.load(currentUserId: _me);
      expect(thread.blockedMessage, isNotNull);
      expect(thread.errorMessage, isNotNull);

      await thread.load(currentUserId: _me);

      expect(thread.blockedMessage, isNull);
      expect(thread.errorMessage, isNull);
    });

    test(
      'tekrar deneme tamamlanana kadar engel ve hata birlikte kalır',
      () async {
        final retryResponse = Completer<FakeApiResponse>();
        var messageRequestCount = 0;
        final thread = build(
          FakeApi(
            handler: (options) {
              if (options.method != 'GET') {
                return const FakeApiResponse(
                  statusCode: 200,
                  body: {'success': true},
                );
              }

              messageRequestCount++;
              return messageRequestCount == 1 ? blocked : retryResponse.future;
            },
          ),
        );
        await thread.load(currentUserId: _me);

        final retry = thread.load(currentUserId: _me);

        expect(thread.blockedMessage, isNotNull);
        expect(thread.errorMessage, isNotNull);

        retryResponse.complete(
          const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {'content': []},
            },
          ),
        );
        await retry;

        expect(thread.blockedMessage, isNull);
        expect(thread.errorMessage, isNull);
      },
    );

    test('tekrar denemede 403 sürüyorsa engel korunur', () async {
      final thread = build(FakeApi(handler: (_) => blocked));

      await thread.load(currentUserId: _me);
      await thread.load(currentUserId: _me);

      expect(thread.blockedMessage, 'Bu kullanıcıyla mesajlaşamazsınız.');
      expect(thread.errorMessage, 'Bu kullanıcıyla mesajlaşamazsınız.');
    });

    test('geç kalan eski istek yeni başarılı durumu bozamaz', () async {
      final staleResponse = Completer<FakeApiResponse>();
      var messageRequestCount = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.method != 'GET') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true},
            );
          }

          messageRequestCount++;
          if (messageRequestCount == 1) return staleResponse.future;

          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'content': [messageBody(id: 'guncel', body: 'Güncel mesaj')],
              },
            },
          );
        },
      );
      final thread = build(api);

      final staleLoad = thread.load(currentUserId: _me);
      await api.requestsReach(1);
      await thread.load(currentUserId: _me);

      staleResponse.complete(blocked);
      await staleLoad;

      expect(thread.messages.single.body, 'Güncel mesaj');
      expect(thread.blockedMessage, isNull);
      expect(thread.errorMessage, isNull);
      expect(thread.isLoading, isFalse);
    });

    // Engelin `statusCode` yerine kategoriden tanındığını ölçen tek test
    // aşağıdaki. Bir ara "ACCESS_DENIED kategorisi sohbeti kilitliyor" diye
    // ikinci bir test daha vardı; `403` + `ACCESS_DENIED` kuruyordu, yani
    // üstündeki iki `403` testinin kopyasıydı — `403` tek başına zaten
    // `forbidden` üretiyor, kategori satırı sonucu hiç değiştirmiyordu.
    // Ölçüldü: `_captureBlock` `statusCode == 403`'e geri çevrildiğinde o
    // test yeşil kalıyor, yalnızca bu kırmızıya dönüyordu. Kaldırıldı;
    // ayırt edici gücü olmayan bir test, kapsamı olduğundan geniş gösterir.
    //
    // Kategoriyle durum kodunun **çeliştiği** yönün diğer yarısı
    // (`401` + `ACCESS_DENIED` → `forbidden`) sınıflandırmanın kendi
    // testinde: `api_client_error_category_test.dart`.
    test('403 taşıyan TOKEN_EXPIRED engel sayılmıyor', () async {
      final thread = build(
        FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 403,
            body: {
              'success': false,
              'message': 'Oturum süresi doldu.',
              'errorCategory': 'TOKEN_EXPIRED',
            },
          ),
        ),
      );

      await thread.load(currentUserId: _me);

      expect(thread.blockedMessage, isNull);
      expect(thread.errorMessage, 'Oturum süresi doldu.');
    });

    test('401 engel sayılmıyor', () async {
      // `401` artık `unauthenticated`, `403` ise `forbidden`. Süresi dolmuş
      // oturum mesaj kutusunu kilitlememeli: kullanıcının yapması gereken
      // yeniden giriş, sohbeti terk etmek değil.
      final thread = build(
        FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 401,
            body: {'success': false, 'message': 'Oturum süresi doldu.'},
          ),
        ),
      );

      await thread.load(currentUserId: _me);

      expect(thread.blockedMessage, isNull);
      expect(thread.errorMessage, 'Oturum süresi doldu.');
    });
  });

  // Ödeme kapısı da engel gibi 403 + ACCESS_DENIED geliyor; ikisini yalnız
  // `errorCode` ayırıyor. Kapı `gate`'e düşmeli, `blockedMessage` boş kalmalı
  // ki ekran kırmızı engel şeridi değil ödeme açıklaması çizsin.
  group('mesajlaşma kapısı', () {
    const paymentRequired = FakeApiResponse(
      statusCode: 403,
      body: {
        'success': false,
        'message': 'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
        'errorCode': 'MESSAGING_PAYMENT_REQUIRED',
        'errorCategory': 'ACCESS_DENIED',
      },
    );
    const windowClosed = FakeApiResponse(
      statusCode: 409,
      body: {
        'success': false,
        'message': 'Bu iş için mesajlaşma süresi doldu.',
        'errorCode': 'MESSAGING_WINDOW_CLOSED',
        'errorCategory': 'DATA_CONFLICT',
      },
    );
    const emptyPage = FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'content': []},
      },
    );

    test('gönderirken 403 MESSAGING_PAYMENT_REQUIRED kapıyı kapatır', () async {
      final api = FakeApi(
        handler: (options) =>
            options.method == 'GET' ? emptyPage : paymentRequired,
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);

      final sent = await thread.send('Merhaba');

      expect(sent, isFalse);
      expect(thread.gate, isNotNull);
      expect(thread.gate!.needsPayment, isTrue);
      // Kapı hata değil: boş liste hata durumuna düşmemeli.
      expect(thread.errorMessage, isNull);
      expect(
        thread.gate!.noteFor(asEmployer: false),
        'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
      );
      expect(
        thread.gate!.noteFor(asEmployer: true),
        'Ödemeyi tamamlayınca ekip sohbeti açılır.',
      );
      // Engel değil: engel şeridi çizilmemeli.
      expect(thread.blockedMessage, isNull);
    });

    test('gönderirken 409 MESSAGING_WINDOW_CLOSED kapıyı kapatır', () async {
      final api = FakeApi(
        handler: (options) =>
            options.method == 'GET' ? emptyPage : windowClosed,
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);

      final sent = await thread.send('Merhaba');

      expect(sent, isFalse);
      expect(thread.gate!.isClosed, isTrue);
      expect(thread.gate!.noteFor(asEmployer: false), 'Bu sohbet kapandı');
      expect(thread.blockedMessage, isNull);
    });

    test('sohbeti açarken gelen kapı hatası da yakalanır', () async {
      final thread = build(FakeApi(handler: (_) => paymentRequired));

      await thread.load(currentUserId: _me);

      expect(thread.gate!.needsPayment, isTrue);
      expect(thread.errorMessage, isNotNull);
      expect(thread.blockedMessage, isNull);
    });

    // Ödeme geldiyse ekran yeniden açılınca kutu geri gelmeli.
    test('başarılı yükleme kapıyı temizler', () async {
      var getCount = 0;
      final thread = build(
        FakeApi(
          handler: (options) {
            if (options.method != 'GET') return paymentRequired;
            getCount++;
            return getCount == 1 ? paymentRequired : emptyPage;
          },
        ),
      );

      await thread.load(currentUserId: _me);
      expect(thread.gate, isNotNull);

      await thread.load(currentUserId: _me);

      expect(thread.gate, isNull);
      expect(thread.errorMessage, isNull);
    });

    test('kodsuz 403 hâlâ engel sayılır', () async {
      const blocked = FakeApiResponse(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'Bu kullanıcıyla mesajlaşamazsınız.',
        },
      );
      final thread = build(FakeApi(handler: (_) => blocked));

      await thread.load(currentUserId: _me);

      expect(thread.gate, isNull);
      expect(thread.blockedMessage, 'Bu kullanıcıyla mesajlaşamazsınız.');
    });
  });

  group('dispose', () {
    // Sohbetten hızlıca çıkıldığında geç gelen yanıt "used after being
    // disposed" ile uygulamayı düşürmemeli.
    test('yükleme bitmeden atılırsa çökmez', () async {
      final controller = build(apiWith([]));

      final pending = controller.load(currentUserId: _me);
      controller.dispose();

      await expectLater(pending, completes);
      expect(realtime.connectCalled, isFalse);
    });
  });
}
