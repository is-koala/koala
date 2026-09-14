import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fake_realtime.dart';

const _me = 'user_me';
const _other = 'user_other';
const _conversationId = 'conv_1';

/// Gerçek soket açmadan olay besleyen sahte canlı istemci.
class FakeRealtimeClient extends FakeSilentRealtimeClient {
  final _controller = StreamController<RealtimeEvent>.broadcast();
  final List<String> typingSentFor = [];

  void emit(RealtimeEvent event) => _controller.add(event);

  bool get hasListener => _controller.hasListener;

  @override
  Stream<RealtimeEvent> conversationEvents(String conversationId) =>
      _controller.stream;

  @override
  void sendTyping(String conversationId) => typingSentFor.add(conversationId);

  @override
  Future<void> dispose() async {
    await _controller.close();
    await super.dispose();
  }
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

  ChatThreadController build(FakeApi api, {bool connected = true}) {
    realtime = FakeRealtimeClient()..connected = connected;
    addTearDown(realtime.dispose);
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

    /// Mesaj çekimlerinin `after` sorgu parametreleri, sırayla.
    List<Object?> afterParams(FakeApi api) => api.requests
        .where(
          (r) =>
              r.method == 'GET' &&
              r.path == '/conversations/$_conversationId/messages',
        )
        .map((r) => r.queryParameters['after'])
        .toList();

    // Tamamlama artımlı: eldeki en yeni mesaj çapa olur ve sunucudan yalnız
    // ondan sonrakiler istenir. Kopukken gelen eklenir, eldeki tekrar
    // eklenmez; `after` kipinde `sort` gönderilmez (sunucu 400 verir).
    test('kopup gelen bağlantı kaçanları after= ile tamamlar', () async {
      final messages = [
        messageBody(id: 'm1', body: 'Merhaba'),
        messageBody(
          id: 'm2',
          senderId: _me,
          body: 'Selam',
          sentAt: '2026-03-05T10:01:00Z',
        ),
      ];
      final api = FakeApi(
        handler: (options) {
          if (options.method != 'GET') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true},
            );
          }
          final after = options.queryParameters['after'];
          final content = after == null
              ? messages.reversed.toList()
              : after == 'm2'
              ? [
                  messageBody(
                    id: 'm3',
                    body: 'Kopukken yazdım',
                    sentAt: '2026-03-05T10:05:00Z',
                  ),
                ]
              : <Map<String, dynamic>>[];
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {'content': content, 'last': true},
            },
          );
        },
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);
      expect(thread.messages, hasLength(2));

      final caughtUp = nextNotify(thread);
      realtime.emitConnection(RealtimeConnectionEvent.disconnected);
      realtime.emitConnection(RealtimeConnectionEvent.connected);
      await caughtUp;

      expect(messageFetches(api), 2);
      expect(afterParams(api), [null, 'm2']);
      final catchUpRequest = api.requests.last;
      expect(catchUpRequest.queryParameters.containsKey('sort'), isFalse);
      expect(thread.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
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

    // Çapa sunucuda bilinmiyorsa (silinmiş ya da başka sohbetin mesajı)
    // sunucu 400 MESSAGING_AFTER_UNKNOWN veriyor; liste baştan çekilir ve
    // kimlikle birleştirilir, aynı mesaj iki kez durmaz.
    test('400 MESSAGING_AFTER_UNKNOWN gelirse liste baştan çekilir', () async {
      final api = FakeApi(
        handler: (options) {
          if (options.method != 'GET') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true},
            );
          }
          if (options.queryParameters.containsKey('after')) {
            return const FakeApiResponse(
              statusCode: 400,
              body: {
                'success': false,
                'message':
                    'after ile verilen mesaj bu konuşmada bulunamadı; '
                    'listeyi baştan çekin.',
                'errorCode': 'MESSAGING_AFTER_UNKNOWN',
                'errorCategory': 'VALIDATION_FAILED',
              },
            );
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'content': [
                  messageBody(
                    id: 'm3',
                    body: 'Yeni',
                    sentAt: '2026-03-05T10:05:00Z',
                  ),
                  messageBody(id: 'm1', body: 'Merhaba'),
                ],
                'last': true,
              },
            },
          );
        },
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);
      expect(thread.messages.map((m) => m.id), ['m1', 'm3']);

      // Silinmiş bir çapa: eldeki en yeni mesaj sunucuda artık yok.
      realtime.emit(
        RealtimeEvent.fromJson({
          'type': 'MESSAGE',
          'conversationId': _conversationId,
          'userId': _other,
          'message': messageBody(
            id: 'm-silinen',
            body: 'Silinecek',
            sentAt: '2026-03-05T10:06:00Z',
          ),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // İstekler: sayfa, okundu, canlı mesajın okundusu, after (400), tam.
      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await api.requestsReach(5);
      await Future<void>.delayed(Duration.zero);

      expect(afterParams(api), [null, 'm-silinen', null]);
      expect(thread.messages.map((m) => m.id), ['m1', 'm3', 'm-silinen']);
      expect(thread.messages.where((m) => m.id == 'm3'), hasLength(1));
    });

    // after= dışındaki bir hata eldeki listeyi bozmaz ve yedek yola düşmez.
    test(
      'after çekiminde başka bir hata gelirse liste olduğu gibi kalır',
      () async {
        final api = FakeApi(
          handler: (options) {
            if (options.method != 'GET') {
              return const FakeApiResponse(
                statusCode: 200,
                body: {'success': true},
              );
            }
            if (options.queryParameters.containsKey('after')) {
              return const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Sunucu hatası'},
              );
            }
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [messageBody(id: 'm1')],
                },
              },
            );
          },
        );
        final thread = build(api);
        await thread.load(currentUserId: _me);

        realtime.emitConnection(RealtimeConnectionEvent.resumed);
        await api.requestsReach(3);
        await Future<void>.delayed(Duration.zero);

        expect(messageFetches(api), 2);
        expect(thread.messages.map((m) => m.id), ['m1']);
        expect(thread.errorMessage, isNull);
      },
    );

    // Abonelik sayfa çekiminden önce açılıyor; sayfa yanıtı beklenirken
    // kanaldan gelen mesaj sayfada olsun ya da olmasın listede bir kez durur.
    test(
      'sayfa beklenirken kanaldan gelen mesaj kaybolmaz ve çift olmaz',
      () async {
        final pageResponse = Completer<FakeApiResponse>();
        final api = FakeApi(
          handler: (options) => options.method == 'GET'
              ? pageResponse.future
              : const FakeApiResponse(statusCode: 200, body: {'success': true}),
        );
        final thread = build(api);
        final loading = thread.load(currentUserId: _me);
        await api.requestsReach(1);
        expect(realtime.connectCalled, isTrue);

        realtime.emit(
          RealtimeEvent.fromJson({
            'type': 'MESSAGE',
            'conversationId': _conversationId,
            'userId': _other,
            'message': messageBody(
              id: 'm-race',
              body: 'Arada geldi',
              sentAt: '2026-03-05T10:01:00Z',
            ),
          }),
        );
        realtime.emit(
          RealtimeEvent.fromJson({
            'type': 'MESSAGE',
            'conversationId': _conversationId,
            'userId': _other,
            'message': messageBody(
              id: 'm-late',
              body: 'Sayfadan sonra',
              sentAt: '2026-03-05T10:02:00Z',
            ),
          }),
        );
        await Future<void>.delayed(Duration.zero);

        // Sunucu sayfası ilkini zaten içeriyor, ikincisini içermiyor.
        pageResponse.complete(
          FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'content': [
                  messageBody(
                    id: 'm-race',
                    body: 'Arada geldi',
                    sentAt: '2026-03-05T10:01:00Z',
                  ),
                  messageBody(id: 'm1'),
                ],
              },
            },
          ),
        );
        await loading;

        expect(thread.messages.map((m) => m.id), ['m1', 'm-race', 'm-late']);
      },
    );

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

    // after= sayfalı: ilk sayfa `last` değilse aynı çapayla sonraki sayfa
    // istenir; sunucu artan sırada veriyor.
    test('after tamamlaması son sayfaya kadar ilerler', () async {
      Map<String, dynamic> at(String id, int minute) =>
          messageBody(id: id, sentAt: '2026-03-05T10:0$minute:00Z');
      final afterPages = <int, List<Map<String, dynamic>>>{
        0: [at('m2', 2), at('m3', 3)],
        1: [at('m4', 4)],
      };
      final api = FakeApi(
        handler: (options) {
          if (options.method != 'GET') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true},
            );
          }
          final page = options.queryParameters['page'] as int? ?? 0;
          if (options.queryParameters['after'] != 'm1') {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [at('m1', 1)],
                  'last': true,
                },
              },
            );
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {'content': afterPages[page]!, 'last': page >= 1},
            },
          );
        },
      );
      final thread = build(api);
      await thread.load(currentUserId: _me);
      expect(thread.messages.map((m) => m.id), ['m1']);

      final caughtUp = nextNotify(thread);
      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await caughtUp;

      expect(thread.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4']);
      expect(afterParams(api), [null, 'm1', 'm1']);
    });

    // Kopukluk sayfa sınırından uzun sürdüyse after= yolu tamamlanamaz;
    // eski yol devreye girer: en yeni sayfadan bilinen mesaja kadar geriye.
    test(
      'after sayfa sınırını aşarsa en yeni sayfalardan tamamlanır',
      () async {
        Map<String, dynamic> at(String id, int minute) =>
            messageBody(id: id, sentAt: '2026-03-05T10:0$minute:00Z');
        final newestFirst = <int, List<Map<String, dynamic>>>{
          0: [at('m5', 5), at('m4', 4)],
          1: [at('m3', 3), at('m2', 2)],
          2: [at('m1', 1)],
        };
        var loaded = false;
        final api = FakeApi(
          handler: (options) {
            if (options.method != 'GET') {
              return const FakeApiResponse(
                statusCode: 200,
                body: {'success': true},
              );
            }
            final page = options.queryParameters['page'] as int? ?? 0;
            if (options.queryParameters.containsKey('after')) {
              // Hiç bitmeyen artımlı sayfalar.
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [at('m$page', 2)],
                    'last': false,
                  },
                },
              );
            }
            final content = loaded ? newestFirst[page]! : newestFirst[2]!;
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
        loaded = true;

        final caughtUp = nextNotify(thread);
        realtime.emitConnection(RealtimeConnectionEvent.resumed);
        await caughtUp;

        expect(thread.messages.map((m) => m.id), [
          'm1',
          'm2',
          'm3',
          'm4',
          'm5',
        ]);
        // Üç after sayfası + geriye doğru üç sayfa.
        expect(afterParams(api), [null, 'm1', 'm1', 'm1', null, null, null]);
      },
    );

    // Elde mesaj yokken çapa yok: en yeni sayfa çekilir.
    test('boş sohbette tamamlama after göndermez', () async {
      final messages = <Map<String, dynamic>>[];
      final api = apiWith(messages);
      final thread = build(api);
      await thread.load(currentUserId: _me);

      messages.add(messageBody(id: 'm1'));
      final caughtUp = nextNotify(thread);
      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await caughtUp;

      expect(afterParams(api), [null, null]);
      expect(thread.messages.map((m) => m.id), ['m1']);
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
      // Abonelik çekimden önce açılıyor; atılınca bırakılmış olmalı.
      expect(realtime.hasListener, isFalse);
    });
  });
}
