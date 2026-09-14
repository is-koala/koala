import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';

import 'chat_page_retry_harness.dart';
import 'fake_api.dart';
import 'fake_realtime.dart';
import 'keyboard.dart';
import 'pump.dart';

const _chat = Conversation(
  id: 'conv_1',
  jobId: 'job_1',
  jobTitle: 'Garson',
  counterpartId: 'user_other',
  name: 'Ayşe Yılmaz',
  avatar: 'AY',
);

/// Listeyi kaydırılabilir yapacak kadar mesaj: sürükleyince klavyenin
/// kapanması bir kaydırma bildirimine bağlı, sığan bir liste bildirim
/// üretmiyor.
const int _messageCount = 30;

FakeApiResponse _messagesPage() => FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': {
      'content': [
        for (var i = 0; i < _messageCount; i++)
          {
            'id': 'msg_$i',
            'conversationId': _chat.id,
            'senderId': 'user_other',
            'content': 'Merhaba $i',
            'sentAt': '2026-09-14T09:${i.toString().padLeft(2, '0')}:00Z',
          },
      ],
    },
  },
);

/// Sohbet ekranının klavye davranışı iki kabukta da aynı
/// (is-koala/koala#190): mesaj kutusu klavyenin üstünde kalıyor, listeye
/// dokunmak ya da onu sürüklemek klavyeyi kapatıyor.
void registerChatPageKeyboardTests({
  required String role,
  required String currentUserId,
  required bool isEmployer,
  required ChatPageBuilder buildPage,
}) {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('$role / $themeName tema / klavye', () {
      Future<void> pumpChat(WidgetTester tester) async {
        final api = FakeApi(
          handler: (options) => options.method == 'GET'
              ? _messagesPage()
              : const FakeApiResponse(statusCode: 200, body: {'success': true}),
        );
        final realtime = FakeSilentRealtimeClient();
        final thread = ChatThreadController(
          conversationId: _chat.id,
          chatService: ChatService.withClient(api.client),
          realtimeClient: realtime,
        );
        addTearDown(realtime.dispose);
        addTearDown(thread.dispose);
        final userProvider = (await tester.runAsync(
          () => _loadedUserProvider(
            currentUserId: currentUserId,
            isEmployer: isEmployer,
          ),
        ))!;
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
      }

      testWidgets('mesaj kutusu klavyenin üstünde kalır', (tester) async {
        await pumpChat(tester);
        await showKeyboard(tester);

        await expectAboveKeyboard(tester, find.byType(MessageTextField));
      });

      testWidgets('listeye dokununca odak düşer', (tester) async {
        await pumpChat(tester);

        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(anyFieldFocused(tester), isTrue);

        await tester.tapAt(tester.getCenter(find.byType(ListView)));
        await tester.pump();

        expect(anyFieldFocused(tester), isFalse);
      });

      testWidgets('liste sürüklenince odak düşer', (tester) async {
        await pumpChat(tester);

        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(anyFieldFocused(tester), isTrue);

        await tester.drag(find.byType(ListView), const Offset(0, -60));
        await tester.pumpAndSettle();

        expect(anyFieldFocused(tester), isFalse);
      });
    });
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
