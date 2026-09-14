import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_list_controller.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';

import '../../../../../support/fake_api.dart';

const _me = 'user_me';
const _other = 'user_other';
const _conversationId = 'conv_1';

/// Gerçek soket açmadan olay besleyen sahte canlı istemci.
///
/// Presence kanalları kullanıcı başına ayrıldığı için hangi kimliklere abone
/// olunduğu da kaydediliyor — yabancıya abone olmak sunucuda 403 ve
/// bağlantıyı düşürüyor, bu yüzden testin izlemesi gereken bir şey.
class FakeRealtimeClient implements RealtimeClient {
  final _messages = StreamController<RealtimeEvent>.broadcast();
  final Map<String, StreamController<RealtimeEvent>> presenceStreams = {};
  bool connectCalled = false;

  void emitMessage(RealtimeEvent event) => _messages.add(event);

  void emitPresence(String userId, RealtimeEvent event) =>
      presenceStreams[userId]?.add(event);

  @override
  Stream<RealtimeEvent> userMessageEvents() => _messages.stream;

  @override
  Stream<RealtimeEvent> presenceEventsFor(String userId) {
    return presenceStreams
        .putIfAbsent(userId, StreamController<RealtimeEvent>.broadcast)
        .stream;
  }

  @override
  Stream<RealtimeEvent> conversationEvents(String conversationId) =>
      _messages.stream;

  @override
  Future<void> connect() async => connectCalled = true;

  @override
  void sendTyping(String conversationId) {}

  @override
  Future<void> disconnect() async {}

  @override
  bool get isConnected => connected;

  /// Abonelik anında bağlantı var mı; `false` verilirse denetleyici ilk
  /// `connected`'da boşluğu tamamlamalı.
  bool connected = true;

  final _connection = StreamController<RealtimeConnectionEvent>.broadcast();
  final List<bool> resumeCalls = [];

  void emitConnection(RealtimeConnectionEvent event) => _connection.add(event);

  @override
  Stream<RealtimeConnectionEvent> get connectionEvents => _connection.stream;

  @override
  void resume({bool suspectStale = false}) => resumeCalls.add(suspectStale);

  @override
  Future<void> reconnect() async {}
}

Map<String, dynamic> conversationBody({
  String id = _conversationId,
  String counterpart = _other,
  String lastMessageBody = 'Merhaba',
  int unreadCount = 0,
}) {
  return {
    'id': id,
    'jobId': 'job_1',
    'jobTitle': 'Garson',
    'employer': {'id': counterpart, 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
    'worker': {'id': _me, 'firstName': 'Yakup', 'lastName': 'Kahraman'},
    'lastMessageAt': '2026-03-05T10:00:00Z',
    'lastMessageBody': lastMessageBody,
    'unreadCount': unreadCount,
  };
}

RealtimeEvent messageEvent({
  String conversationId = _conversationId,
  String senderId = _other,
  String body = 'Yeni mesaj',
  String id = 'msg_new',
}) {
  return RealtimeEvent.fromJson({
    'type': 'MESSAGE',
    'conversationId': conversationId,
    'userId': senderId,
    'message': {
      'id': id,
      'senderId': senderId,
      'body': body,
      'sentAt': '2026-03-05T12:00:00Z',
    },
  });
}

void main() {
  late FakeRealtimeClient realtime;
  late FakeApi api;

  /// Sunucuya ulaşan `GET /conversations` sayısı; canlı akışın çekme yerine
  /// geçtiğini ve tamamlamanın gerçekten çektiğini bununla ölçüyoruz.
  int listFetches() =>
      api.requests.where((request) => request.path == '/conversations').length;

  /// Denetleyicinin bir sonraki `notifyListeners` çağrısı. Tamamlama sessiz
  /// bir istek olduğu için bitişini ancak dinleyiciden anlıyoruz; süreye
  /// bağlı bekleme makine yükünde yalancı kırmızı üretiyor.
  Future<void> nextNotify(ChatListController controller) {
    final completer = Completer<void>();
    late final VoidCallback listener;
    listener = () {
      if (!completer.isCompleted) completer.complete();
      controller.removeListener(listener);
    };
    controller.addListener(listener);
    return completer.future;
  }

  ChatListController build(
    List<Map<String, dynamic>> conversations, {
    bool connected = true,
  }) {
    realtime = FakeRealtimeClient()..connected = connected;
    api = FakeApi(
      handler: (options) => options.path == '/presence/lookup'
          ? const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': []},
            )
          : FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'content': conversations},
              },
            ),
    );
    return ChatListController(
      chatService: ChatService.withClient(api.client),
      realtimeClient: realtime,
    );
  }

  group('load', () {
    test('sohbetler çekilir ve canlı akışa bağlanılır', () async {
      final controller = build([conversationBody()]);

      await controller.load(currentUserId: _me);

      expect(controller.conversations.single.lastMessage, 'Merhaba');
      expect(realtime.connectCalled, isTrue);
    });

    // Yalnızca konuştuğun kişinin presence'ına abone olabiliyorsun; listedeki
    // karşı taraflar bu şartı zaten sağlıyor.
    test('her karşı taraf için presence aboneliği açılır', () async {
      final controller = build([
        conversationBody(id: 'c1', counterpart: 'u1'),
        conversationBody(id: 'c2', counterpart: 'u2'),
      ]);

      await controller.load(currentUserId: _me);

      expect(realtime.presenceStreams.keys, containsAll(['u1', 'u2']));
    });

    // Grubun tek bir karşı tarafı yok; kimseye abone olunmamalı ve toplu
    // presence isteğine grup için kimlik gitmemeli.
    test('grup sohbeti için presence aboneliği açılmaz', () async {
      final controller = build([
        {
          'id': 'crew',
          'jobId': 'job_1',
          'jobTitle': 'Garson',
          'kind': 'GROUP',
          'employer': {'id': _other, 'firstName': 'Ayşe', 'lastName': 'Y'},
          'worker': null,
          'participants': [
            {'id': _other, 'firstName': 'Ayşe', 'lastName': 'Y'},
            {'id': _me, 'firstName': 'Yakup', 'lastName': 'K'},
          ],
          'closed': false,
        },
      ]);

      await controller.load(currentUserId: _me);

      expect(controller.conversations.single.isGroup, isTrue);
      expect(controller.conversations.single.participantCount, 2);
      expect(realtime.presenceStreams, isEmpty);
    });
  });

  group('refresh', () {
    test('ilk yükleme olmadan ağa çıkmaz', () async {
      var requestCount = 0;
      final controller = ChatListController(
        chatService: ChatService.withClient(
          FakeApi(
            handler: (_) {
              requestCount++;
              return const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'content': []},
                },
              );
            },
          ).client,
        ),
        realtimeClient: FakeRealtimeClient(),
      );

      await controller.refresh();

      expect(requestCount, 0);
    });

    // Ödemeyle kurulan grup için canlı olay yok; sekmeye dönüşte yeniden
    // çekilince liste yeni satırı görmeli, yükleme göstergesi açılmamalı.
    test('listeyi yükleme göstergesi açmadan yeniden çeker', () async {
      var listRequests = 0;
      var loadingSeen = false;
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/presence/lookup') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': []},
            );
          }
          listRequests++;
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'content': [
                  conversationBody(id: 'c1'),
                  if (listRequests > 1) conversationBody(id: 'crew'),
                ],
              },
            },
          );
        },
      );
      final controller = ChatListController(
        chatService: ChatService.withClient(api.client),
        realtimeClient: FakeRealtimeClient(),
      );
      await controller.load(currentUserId: _me);
      controller.addListener(() {
        if (controller.isLoading) loadingSeen = true;
      });

      await controller.refresh();

      expect(listRequests, 2);
      expect(controller.conversations.map((c) => c.id), ['c1', 'crew']);
      expect(loadingSeen, isFalse);
    });
  });

  group('canlı mesaj', () {
    test('son mesaj ve okunmamış sayacı güncellenir', () async {
      final controller = build([conversationBody(unreadCount: 1)]);
      await controller.load(currentUserId: _me);

      realtime.emitMessage(messageEvent(body: 'Selam'));
      await Future<void>.delayed(Duration.zero);

      final conversation = controller.conversations.single;
      expect(conversation.lastMessage, 'Selam');
      expect(conversation.unreadCount, 2);
    });

    // Sunucu kopyayı iki tarafa da gönderiyor: kendi yazdığımız mesaj da
    // buradan geliyor ama okunmamış sayılmamalı.
    test('kendi mesajımız okunmamış sayacını artırmaz', () async {
      final controller = build([conversationBody(unreadCount: 3)]);
      await controller.load(currentUserId: _me);

      realtime.emitMessage(messageEvent(senderId: _me, body: 'Ben yazdım'));
      await Future<void>.delayed(Duration.zero);

      final conversation = controller.conversations.single;
      expect(conversation.lastMessage, 'Ben yazdım');
      expect(conversation.unreadCount, 3);
    });

    test('mesaj gelen sohbet listenin başına taşınır', () async {
      final controller = build([
        conversationBody(id: 'c1', counterpart: 'u1'),
        conversationBody(id: 'c2', counterpart: 'u2'),
      ]);
      await controller.load(currentUserId: _me);
      expect(controller.conversations.first.id, 'c1');

      realtime.emitMessage(messageEvent(conversationId: 'c2'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.conversations.first.id, 'c2');
      expect(controller.conversations, hasLength(2));
    });

    // Yeniden abonelik ya da iki kanal aynı mesajı ikinci kez getirebilir;
    // rozet bir mesaj için bir kez artmalı.
    test('aynı mesaj ikinci kez gelince sayaç bir daha artmaz', () async {
      final controller = build([conversationBody(unreadCount: 0)]);
      await controller.load(currentUserId: _me);

      realtime.emitMessage(messageEvent(id: 'msg_dup'));
      realtime.emitMessage(messageEvent(id: 'msg_dup'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.conversations.single.unreadCount, 1);
      expect(listFetches(), 1);
    });

    test('presence dışı olaylar listeyi bozmaz', () async {
      final controller = build([conversationBody()]);
      await controller.load(currentUserId: _me);

      realtime.emitMessage(
        RealtimeEvent.fromJson({'type': 'TYPING', 'userId': _other}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.conversations.single.lastMessage, 'Merhaba');
    });
  });

  group('bağlantı geçişleri', () {
    // Sunucunun `since` parametresi yok; kopukken gelenler listeyi yeniden
    // çekerek tamamlanıyor ve sayaç sunucunun değeriyle geliyor.
    test('kopup gelen bağlantı listeyi sunucudan tamamlar', () async {
      final conversations = [conversationBody(unreadCount: 0)];
      final controller = build(conversations);
      await controller.load(currentUserId: _me);
      expect(listFetches(), 1);

      conversations[0] = conversationBody(
        unreadCount: 2,
        lastMessageBody: 'Kopukken gelen',
      );
      final refreshed = nextNotify(controller);
      realtime.emitConnection(RealtimeConnectionEvent.disconnected);
      realtime.emitConnection(RealtimeConnectionEvent.connected);
      await refreshed;

      expect(listFetches(), 2);
      expect(controller.conversations.single.unreadCount, 2);
      expect(controller.conversations.single.lastMessage, 'Kopukken gelen');
    });

    test('kesintisiz bağlantıda connected tazeleme yapmaz', () async {
      final controller = build([conversationBody()]);
      await controller.load(currentUserId: _me);

      realtime.emitConnection(RealtimeConnectionEvent.connected);
      await Future<void>.delayed(Duration.zero);

      expect(listFetches(), 1);
    });

    // REST yanıtı ile SUBSCRIBE arasına düşen mesaj için: abonelik bağlantı
    // yokken açıldıysa ilk `connected` boşluğu kapatıyor.
    test(
      'bağlantı yokken açılan abonelik ilk connected ile tamamlanır',
      () async {
        final controller = build([conversationBody()], connected: false);
        await controller.load(currentUserId: _me);

        final refreshed = nextNotify(controller);
        realtime.emitConnection(RealtimeConnectionEvent.connected);
        await refreshed;

        expect(listFetches(), 2);
      },
    );

    test('ön plana dönüş listeyi sessizce tazeler', () async {
      final controller = build([conversationBody()]);
      await controller.load(currentUserId: _me);
      var notified = 0;
      controller.addListener(() => notified++);

      final refreshed = nextNotify(controller);
      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await refreshed;

      expect(listFetches(), 2);
      expect(controller.isLoading, isFalse);
      expect(notified, 1);
    });

    // Aynı anda gelen iki tetikleyici (dönüş + yeniden bağlanma) tek istek.
    test('uçuştaki tazeleme paylaşılır', () async {
      final controller = build([conversationBody()]);
      await controller.load(currentUserId: _me);

      final refreshed = nextNotify(controller);
      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      realtime.emitConnection(RealtimeConnectionEvent.resumed);
      await refreshed;

      expect(listFetches(), 2);
    });
  });

  group('canlı okundu bilgisi', () {
    // Telefonda okunan sohbetin rozeti tablette de inmeliydi; olay kişisel
    // kuyruğa geliyordu ama liste mesaj olmayan her şeyi eliyordu.
    test('kendi okumamız rozeti sıfırlar', () async {
      final controller = build([conversationBody(unreadCount: 4)]);
      await controller.load(currentUserId: _me);

      realtime.emitMessage(
        RealtimeEvent.fromJson({
          'type': 'READ',
          'conversationId': _conversationId,
          'userId': _me,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.conversations.single.unreadCount, 0);
    });

    // Karşı tarafın okuması bizim okunmamışımızı değiştirmiyor: o, bizim
    // gönderdiğimiz mesajların okundu bilgisi.
    test('karşı tarafın okuması rozete dokunmaz', () async {
      final controller = build([conversationBody(unreadCount: 4)]);
      await controller.load(currentUserId: _me);

      realtime.emitMessage(
        RealtimeEvent.fromJson({
          'type': 'READ',
          'conversationId': _conversationId,
          'userId': _other,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.conversations.single.unreadCount, 4);
    });

    test('tanınmayan sohbetin okundu bilgisi listeyi bozmaz', () async {
      final controller = build([conversationBody(unreadCount: 2)]);
      await controller.load(currentUserId: _me);

      realtime.emitMessage(
        RealtimeEvent.fromJson({
          'type': 'READ',
          'conversationId': 'baska_sohbet',
          'userId': _me,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.conversations.single.unreadCount, 2);
    });
  });

  group('canlı presence', () {
    test('çevrimiçi bilgisi güncellenir', () async {
      final controller = build([conversationBody()]);
      await controller.load(currentUserId: _me);
      expect(controller.conversations.single.isOnline, isFalse);

      realtime.emitPresence(
        _other,
        RealtimeEvent.fromJson({
          'type': 'PRESENCE',
          'userId': _other,
          'online': true,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.conversations.single.isOnline, isTrue);
    });
  });

  group('dispose', () {
    // Navbar'da sekmeler arasında hızlıca gezinirken sayfa, istek daha
    // dönmeden atılıyor. Geç gelen yanıt "used after being disposed" ile
    // uygulamayı düşürmemeli.
    test('yükleme bitmeden atılırsa çökmez', () async {
      final controller = build([conversationBody()]);

      final pending = controller.load(currentUserId: _me);
      controller.dispose();

      await expectLater(pending, completes);
      // Atılmış denetleyici artık soket açmamalı; aboneliğin iptali yok.
      expect(realtime.connectCalled, isFalse);
      expect(realtime.presenceStreams, isEmpty);
    });
  });
}
