import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

const _me = 'user_me';
const _other = 'user_other';

Map<String, dynamic> conversationBody({
  String lastMessageBody = 'Merhaba',
  int unreadCount = 2,
}) {
  return {
    'id': 'conv_1',
    'jobId': 'job_1',
    'jobTitle': 'Garson',
    'employer': {'id': _other, 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
    'worker': {'id': _me, 'firstName': 'Yakup', 'lastName': 'Kahraman'},
    'lastMessageAt': '2026-03-05T10:00:00Z',
    'lastMessageBody': lastMessageBody,
    'unreadCount': unreadCount,
  };
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
  group('ChatService.fetchConversations', () {
    test('sohbetler modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [conversationBody()],
              'last': true,
            },
          },
        ),
      );

      final page = await ChatService.withClient(
        api.client,
      ).fetchConversations(currentUserId: _me);

      expect(api.requests.single.path, '/conversations');
      final conversation = page.conversations.single;
      expect(conversation.lastMessage, 'Merhaba');
      expect(conversation.unreadCount, 2);
    });

    // Sunucu "karşı taraf" diye bir alan döndürmüyor: iki katılımcıdan
    // oturum sahibi olmayan seçiliyor.
    test('karşı taraf oturum sahibine göre belirlenir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [conversationBody()],
            },
          },
        ),
      );
      final service = ChatService.withClient(api.client);

      final asWorker = await service.fetchConversations(currentUserId: _me);
      expect(asWorker.conversations.single.name, 'Ayşe Yılmaz');
      expect(asWorker.conversations.single.counterpartId, _other);

      final asEmployer = await service.fetchConversations(
        currentUserId: _other,
      );
      expect(asEmployer.conversations.single.name, 'Yakup Kahraman');
      expect(asEmployer.conversations.single.counterpartId, _me);
    });
  });

  group('ChatService.fetchMessages', () {
    test('mesajlar eskiden yeniye sıralanır', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              // Sunucu en yeniyi başta döndürüyor.
              'content': [
                messageBody(id: 'yeni', sentAt: '2026-03-05T12:00:00Z'),
                messageBody(id: 'eski', sentAt: '2026-03-05T09:00:00Z'),
              ],
            },
          },
        ),
      );

      final page = await ChatService.withClient(
        api.client,
      ).fetchMessages(conversationId: 'conv_1', currentUserId: _me);

      expect(api.requests.single.path, '/conversations/conv_1/messages');
      expect(page.messages.map((m) => m.id), ['eski', 'yeni']);
    });

    test('gönderen oturum sahibiyse isMe true', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                messageBody(id: 'benim', senderId: _me),
                messageBody(id: 'onun', senderId: _other),
              ],
            },
          },
        ),
      );

      final page = await ChatService.withClient(
        api.client,
      ).fetchMessages(conversationId: 'conv_1', currentUserId: _me);

      final byId = {for (final m in page.messages) m.id: m};
      expect(byId['benim']!.isMe, isTrue);
      expect(byId['onun']!.isMe, isFalse);
    });
  });

  group('ChatService.sendMessage', () {
    test('metin gövdeye konur ve yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': messageBody(id: 'msg_2', senderId: _me, body: 'Selam'),
          },
        ),
      );

      final message = await ChatService.withClient(api.client).sendMessage(
        conversationId: 'conv_1',
        currentUserId: _me,
        body: 'Selam',
      );

      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.data, {'body': 'Selam'});
      expect(message.body, 'Selam');
      expect(message.isMe, isTrue);
    });

    test('sunucu reddederse ApiException', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {'success': false, 'message': 'Mesaj boş olamaz'},
        ),
      );

      expect(
        () => ChatService.withClient(
          api.client,
        ).sendMessage(conversationId: 'conv_1', currentUserId: _me, body: ''),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ChatService.markRead', () {
    test('okundu ucuna POST atar', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await ChatService.withClient(api.client).markRead('conv_1');

      expect(api.requests.single.path, '/conversations/conv_1/read');
      expect(api.requests.single.method, 'POST');
    });
  });

  group('ChatService.openConversationForJob', () {
    test('ilan üzerinden sohbet açar', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': conversationBody()},
        ),
      );

      await ChatService.withClient(
        api.client,
      ).openConversationForJob(jobId: 'job_1', currentUserId: _me);

      expect(api.requests.single.path, '/jobs/job_1/conversation');
      expect(api.requests.single.queryParameters, isEmpty);
    });

    test('işveren tarafı workerId geçiyor', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': conversationBody()},
        ),
      );

      await ChatService.withClient(api.client).openConversationForJob(
        jobId: 'job_1',
        currentUserId: _other,
        workerId: _me,
      );

      expect(api.requests.single.queryParameters, {'workerId': _me});
    });
  });

  group('ChatService.fetchPresence', () {
    test('kimliklere göre eşlenir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'userId': 'a', 'online': true},
              {'userId': 'b', 'online': false},
            ],
          },
        ),
      );

      final presence = await ChatService.withClient(
        api.client,
      ).fetchPresence(['a', 'b']);

      expect(api.requests.single.path, '/presence/lookup');
      expect(api.requests.single.data, ['a', 'b']);
      expect(presence['a']?.online, isTrue);
      expect(presence['b']?.online, isFalse);
    });

    // Boş listeyle ağa çıkmanın anlamı yok.
    test('boş listede istek atılmaz', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(statusCode: 200),
      );

      final presence = await ChatService.withClient(
        api.client,
      ).fetchPresence(const []);

      expect(presence, isEmpty);
      expect(api.requests, isEmpty);
    });
  });
}
