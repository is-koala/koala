import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_list_page.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_list_controller.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fake_realtime.dart';
import '../../../../../support/pump.dart';

const _me = 'employer-1';

const _conversations = [
  {
    'id': 'conv-direct',
    'jobId': 'job-1',
    'jobTitle': 'Hafta Sonu Garson',
    'kind': 'DIRECT',
    'employer': {'id': _me, 'firstName': 'Kahve', 'lastName': 'Durağı'},
    'worker': {'id': 'worker-1', 'firstName': 'Yakup', 'lastName': 'Kahraman'},
    'participants': [
      {'id': _me, 'firstName': 'Kahve', 'lastName': 'Durağı'},
      {'id': 'worker-1', 'firstName': 'Yakup', 'lastName': 'Kahraman'},
    ],
    'lastMessageBody': 'Selam',
    'unreadCount': 0,
    'closed': false,
  },
  {
    'id': 'conv-crew',
    'jobId': 'job-1',
    'jobTitle': 'Hafta Sonu Garson',
    'kind': 'GROUP',
    'employer': {'id': _me, 'firstName': 'Kahve', 'lastName': 'Durağı'},
    'worker': null,
    'participants': [
      {'id': _me, 'firstName': 'Kahve', 'lastName': 'Durağı'},
      {'id': 'officer-1', 'firstName': 'Yetkili', 'lastName': 'Kişi'},
      {'id': 'worker-1', 'firstName': 'Yakup', 'lastName': 'Kahraman'},
    ],
    'lastMessageBody': 'Ekip kuruldu',
    'unreadCount': 1,
    'closed': false,
  },
];

Future<UserProvider> _loadedEmployer() async {
  final api = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': _me,
          'firstName': 'Kahve',
          'lastName': 'Durağı',
          'email': 'kahve@example.com',
          'isEmployer': true,
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
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    testWidgets('grup sohbeti ilan başlığı ve katılımcı sayısıyla listelenir '
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
      final realtime = FakeSilentRealtimeClient();
      final controller = ChatListController(
        chatService: ChatService.withClient(api.client),
        realtimeClient: realtime,
      );
      final userProvider = (await tester.runAsync(_loadedEmployer))!;
      addTearDown(realtime.dispose);
      addTearDown(controller.dispose);
      addTearDown(userProvider.dispose);

      await pumpInApp(
        tester,
        ChangeNotifierProvider.value(
          value: userProvider,
          child: BChatListPage(controller: controller),
        ),
        brightness: brightness,
      );
      await tester.pumpAndSettle();

      // İkili sohbet: işveren bakınca karşı taraf çalışan.
      expect(find.text('Yakup Kahraman'), findsOneWidget);
      // Grup: ilan başlığı + katılımcı sayısı; işverenin kendi adı değil.
      expect(find.text('Hafta Sonu Garson'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-participants-conv-crew')),
        findsOneWidget,
      );
      expect(find.text('3 katılımcı'), findsOneWidget);
      expect(find.text('Kahve Durağı'), findsNothing);
      expect(find.text('Ekip kuruldu'), findsOneWidget);
    });
  }
}
