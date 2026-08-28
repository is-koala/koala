import 'dart:async';

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
  bool get isConnected => true;
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

  ChatListController build(List<Map<String, dynamic>> conversations) {
    realtime = FakeRealtimeClient();
    final api = FakeApi(
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
