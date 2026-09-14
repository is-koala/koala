import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_list_page.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_list_controller.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/network/realtime_event.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fake_realtime.dart';
import '../../../../../support/pump.dart';

const _me = 'worker-1';
const _employer = 'employer-1';

const _conversations = [
  {
    'id': 'conv-direct',
    'jobId': 'job-1',
    'jobTitle': 'Hafta Sonu Garson',
    'kind': 'DIRECT',
    'employer': {'id': _employer, 'firstName': 'Kahve', 'lastName': 'Durağı'},
    'worker': {'id': _me, 'firstName': 'Yakup', 'lastName': 'Kahraman'},
    'lastMessageBody': 'Selam',
    'unreadCount': 0,
    'closed': false,
  },
];

Future<UserProvider> _loadedWorker() async {
  final api = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': _me,
          'firstName': 'Yakup',
          'lastName': 'Kahraman',
          'email': 'yakup@example.com',
          'isEmployer': false,
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

void main() {
  // Çalışan kabuğu işverenle aynı `ChatListController`'ı kullanıyor; işverenin
  // yazdığı mesaj kişisel kuyruktan düşüyor ve liste yeniden çekilmeden
  // güncelleniyor (is-koala/koala#157).
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    testWidgets('çalışan listesi canlı mesajı çekme yapmadan gösterir '
        '($themeName tema)', (tester) async {
      final api = FakeApi(
        handler: (options) => options.path == '/presence/lookup'
            ? const FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': []},
              )
            : const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'content': _conversations},
                },
              ),
      );
      final realtime = FakeLiveRealtimeClient();
      final controller = ChatListController(
        chatService: ChatService.withClient(api.client),
        realtimeClient: realtime,
      );
      final userProvider = (await tester.runAsync(_loadedWorker))!;
      addTearDown(realtime.dispose);
      addTearDown(controller.dispose);
      addTearDown(userProvider.dispose);

      await pumpInApp(
        tester,
        ChangeNotifierProvider.value(
          value: userProvider,
          child: ChatListPage(controller: controller),
        ),
        brightness: brightness,
      );
      await tester.pumpAndSettle();
      expect(find.text('Selam'), findsOneWidget);
      final fetchesBefore = api.requests
          .where((request) => request.path == '/conversations')
          .length;

      realtime.emitUserEvent(
        RealtimeEvent.fromJson({
          'type': 'MESSAGE',
          'conversationId': 'conv-direct',
          'userId': _employer,
          'message': {
            'id': 'msg-live',
            'senderId': _employer,
            'body': 'Saat 9 uygun mu?',
            'sentAt': '2026-09-14T10:00:00Z',
          },
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saat 9 uygun mu?'), findsOneWidget);
      expect(find.text('Selam'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(
        api.requests.where((request) => request.path == '/conversations'),
        hasLength(fetchesBefore),
      );
    });
  }
}
