import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/network/realtime_event.dart';
import 'package:provider/provider.dart';

import 'chat_page_retry_harness.dart';
import 'fake_api.dart';
import 'fake_realtime.dart';
import 'pump.dart';

const _counterpart = 'user_other';

const _chat = Conversation(
  id: 'conv_1',
  jobId: 'job_1',
  jobTitle: 'Garson',
  counterpartId: _counterpart,
  name: 'Ayşe Yılmaz',
  avatar: 'AY',
);

/// Açık sohbet ekranının canlı teslimini iki kabuk için aynı şekilde
/// doğrular: konuşma topic'inden düşen mesaj, ekran yeniden çekim yapmadan
/// balon olarak görünür (is-koala/koala#157).
void registerChatPageRealtimeTests({
  required String role,
  required String currentUserId,
  required bool isEmployer,
  required ChatPageBuilder buildPage,
}) {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    testWidgets(
      '$role canlı mesajı çekme yapmadan gösterir ($themeName tema)',
      (tester) async {
        final api = FakeApi(
          handler: (options) => options.method == 'GET'
              ? FakeApiResponse(
                  statusCode: 200,
                  body: {
                    'success': true,
                    'data': {
                      'content': [
                        {
                          'id': 'm1',
                          'senderId': _counterpart,
                          'body': 'Merhaba',
                          'sentAt': '2026-09-14T09:00:00Z',
                        },
                      ],
                    },
                  },
                )
              : const FakeApiResponse(statusCode: 200, body: {'success': true}),
        );
        final realtime = FakeLiveRealtimeClient();
        final thread = ChatThreadController(
          conversationId: _chat.id,
          chatService: ChatService.withClient(api.client),
          realtimeClient: realtime,
        );
        final userProvider = (await tester.runAsync(
          () => _loadedUserProvider(
            currentUserId: currentUserId,
            isEmployer: isEmployer,
          ),
        ))!;
        addTearDown(realtime.dispose);
        addTearDown(thread.dispose);
        addTearDown(userProvider.dispose);

        await pumpInApp(
          tester,
          ChangeNotifierProvider.value(
            value: userProvider,
            child: buildPage(_chat, thread),
          ),
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        expect(find.text('Merhaba'), findsOneWidget);
        int fetches() => api.requests
            .where((r) => r.method == 'GET' && r.path.endsWith('/messages'))
            .length;
        final fetchesBefore = fetches();

        realtime.emitConversationEvent(
          RealtimeEvent.fromJson({
            'type': 'MESSAGE',
            'conversationId': _chat.id,
            'userId': _counterpart,
            'message': {
              'id': 'm-live',
              'senderId': _counterpart,
              'body': 'Canlı geldi',
              'sentAt': '2026-09-14T10:00:00Z',
            },
          }),
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(MessageBubble, 'Canlı geldi'),
          findsOneWidget,
        );
        expect(find.byType(MessageBubble), findsNWidgets(2));
        expect(fetches(), fetchesBefore);
      },
    );
  }
}

Future<UserProvider> _loadedUserProvider({
  required String currentUserId,
  required bool isEmployer,
}) async {
  final api = FakeApi(
    handler: (_) => FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': currentUserId,
          'firstName': isEmployer ? 'İşveren' : 'Yakup',
          'lastName': isEmployer ? 'Kullanıcı' : 'Kahraman',
          'email': isEmployer ? 'isveren@example.com' : 'yakup@example.com',
          'isEmployer': isEmployer,
        },
      },
    ),
  );
  final provider = UserProvider(
    userService: UserService.withClient(api.client),
  );
  await provider.load();
  return provider;
}
