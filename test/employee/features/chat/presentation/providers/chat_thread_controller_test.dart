import 'dart:async';

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
  bool get isConnected => true;
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
