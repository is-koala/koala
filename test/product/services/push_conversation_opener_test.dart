import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/services/push_conversation_opener.dart';

import '../../support/fake_api.dart';

const _me = 'user_me';
const _other = 'user_other';

Map<String, dynamic> _conversationBody() => {
  'id': 'conv_1',
  'jobId': 'job_1',
  'jobTitle': 'Garson',
  'kind': 'DIRECT',
  'employer': {'id': _other, 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
  'worker': {'id': _me, 'firstName': 'Yakup', 'lastName': 'Kahraman'},
  'lastMessageAt': '2026-09-14T10:00:00Z',
  'lastMessageBody': 'Merhaba',
  'unreadCount': 1,
  'closed': false,
};

void main() {
  late List<(ChatRoutes, Conversation?)> navigations;
  late ChatRoutes routes;
  late String? userId;

  setUp(() {
    navigations = [];
    routes = ChatRoutes.employee;
    userId = _me;
  });

  PushConversationOpener build(FakeApi api) => PushConversationOpener(
    chatService: ChatService.withClient(api.client),
    currentUserId: () async => userId,
    routes: () => routes,
    navigate: (routes, conversation) => navigations.add((routes, conversation)),
  );

  FakeApi apiWith(FakeApiResponse response) =>
      FakeApi(handler: (_) => response);

  final found = FakeApiResponse(
    statusCode: 200,
    body: {'success': true, 'data': _conversationBody()},
  );
  const notFound = FakeApiResponse(
    statusCode: 404,
    body: {
      'success': false,
      'message': 'Konuşma bulunamadı.',
      'errorCategory': 'RESOURCE_NOT_FOUND',
    },
  );

  test('sohbet bulunursa tek sohbet okunur ve sohbet ekranı açılır', () async {
    final api = apiWith(found);

    await build(api).open('conv_1');

    expect(api.requests.single.path, '/conversations/conv_1');
    expect(api.requests.single.method, 'GET');
    final (target, conversation) = navigations.single;
    expect(target.detail, '/chat-detail');
    expect(conversation?.id, 'conv_1');
    // Karşı taraf oturum sahibine göre seçilmiş olmalı.
    expect(conversation?.counterpartId, _other);
    expect(conversation?.name, 'Ayşe Yılmaz');
  });

  // Silinmiş sohbet ya da artık taraf değilsiniz: sunucu iki hâli de aynı
  // 404 ile veriyor. Kullanıcı bir yere varmalı: liste.
  test('404 gelirse sohbet listesi açılır', () async {
    await build(apiWith(notFound)).open('conv_gone');

    final (target, conversation) = navigations.single;
    expect(target.list, '/chat');
    expect(conversation, isNull);
  });

  test('istek düşerse de liste açılır', () async {
    await build(
      apiWith(
        const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      ),
    ).open('conv_1');

    expect(navigations.single.$2, isNull);
  });

  test('oturum sahibi okunamazsa istek atılmaz, liste açılır', () async {
    userId = null;
    final api = apiWith(found);

    await build(api).open('conv_1');

    expect(api.requests, isEmpty);
    expect(navigations.single.$2, isNull);
  });

  test('işveren kabuğunda işveren rotaları kullanılır', () async {
    routes = ChatRoutes.business;
    userId = _other;

    await build(apiWith(found)).open('conv_1');

    final (target, conversation) = navigations.single;
    expect(target.list, '/business/chat');
    expect(target.detail, '/business/chat-detail');
    expect(conversation?.counterpartId, _me);
  });

  // `PushMessaging` kimliği `UserProvider`'dan okuyor: boşsa `load()`.
  // Soğuk açılışta işveren ana sayfası aynı isteği zaten başlatmış olabilir;
  // dokunma o isteğin bitmesini beklemeli, listeye düşmemeli.
  test('süren /users/me yüklemesi bitince sohbet ekranı açılır', () async {
    final meResponse = Completer<FakeApiResponse>();
    final api = FakeApi(
      handler: (options) =>
          options.path == '/users/me' ? meResponse.future : found,
    );
    final users = UserProvider(userService: UserService.withClient(api.client));
    final opener = PushConversationOpener(
      chatService: ChatService.withClient(api.client),
      currentUserId: () async {
        if (users.user == null) await users.load();
        return users.user?.id;
      },
      routes: () => ChatRoutes.employee,
      navigate: (routes, conversation) =>
          navigations.add((routes, conversation)),
    );

    // Ana sayfa isteği önce başlattı, dokunma arkasından geldi.
    final homeLoad = users.load(silent: true);
    await api.requestsReach(1);
    final opening = opener.open('conv_1');
    await Future<void>.delayed(Duration.zero);
    expect(navigations, isEmpty);

    meResponse.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'id': _me,
            'firstName': 'Yakup',
            'lastName': 'Kahraman',
            'email': 'a@b.com',
            'isEmployer': false,
          },
        },
      ),
    );
    await Future.wait([homeLoad, opening]);

    expect(api.requests.where((r) => r.path == '/users/me'), hasLength(1));
    final (target, conversation) = navigations.single;
    expect(target.detail, '/chat-detail');
    expect(conversation?.id, 'conv_1');
  });
}
