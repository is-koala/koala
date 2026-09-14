import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_list_page.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_list_controller.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fake_realtime.dart';
import '../../../../../support/pump.dart';

const _me = 'worker-1';

Map<String, dynamic> _direct() => {
  'id': 'conv-direct',
  'jobId': 'job-1',
  'jobTitle': 'Hafta Sonu Garson',
  'kind': 'DIRECT',
  'employer': {'id': 'employer-1', 'firstName': 'Kahve', 'lastName': 'Durağı'},
  'worker': {'id': _me, 'firstName': 'Yakup', 'lastName': 'Kahraman'},
  'lastMessageBody': 'Selam',
  'unreadCount': 0,
  'closed': false,
};

Map<String, dynamic> _crew() => {
  'id': 'conv-crew',
  'jobId': 'job-1',
  'jobTitle': 'Hafta Sonu Garson',
  'kind': 'GROUP',
  'employer': {'id': 'employer-1', 'firstName': 'Kahve', 'lastName': 'Durağı'},
  'worker': null,
  'participants': [
    {'id': 'employer-1', 'firstName': 'Kahve', 'lastName': 'Durağı'},
    {'id': _me, 'firstName': 'Yakup', 'lastName': 'Kahraman'},
  ],
  'lastMessageBody': null,
  'unreadCount': 0,
  'closed': false,
};

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

/// Gerçek `ShellPage` gibi: sekme sayfası hangi konumda olunursa olunsun
/// ağaçta kalıyor, rota yalnızca hangisinin göründüğünü söylüyor.
class _KeepAliveShell extends StatelessWidget {
  const _KeepAliveShell({required this.chatList});

  final Widget chatList;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: Column(
        children: [
          Text('konum: $location'),
          Expanded(child: chatList),
        ],
      ),
    );
  }
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
            : FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [_direct(), _crew()],
                  },
                },
              ),
      );
      final realtime = FakeSilentRealtimeClient();
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

      // İkili sohbet: çalışan bakınca karşı taraf işveren.
      expect(find.text('Kahve Durağı'), findsOneWidget);
      // Grup: ilan başlığı + katılımcı sayısı.
      expect(find.text('Hafta Sonu Garson'), findsOneWidget);
      expect(find.text('2 katılımcı'), findsOneWidget);
    });
  }

  // Ödemeyle kurulan grup için sunucu canlı olay göndermiyor; sayfa canlı
  // tutulduğundan `initState` de bir daha çalışmıyor. Sekmeye dönüş listeyi
  // yeniden çekmeli ki grup yenileme gerektirmeden görünsün.
  testWidgets('sohbet sekmesine dönüşte liste sessizce yeniden çekilir', (
    tester,
  ) async {
    var listRequests = 0;
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
              'content': [_direct(), if (listRequests > 1) _crew()],
            },
          },
        );
      },
    );
    final realtime = FakeSilentRealtimeClient();
    final controller = ChatListController(
      chatService: ChatService.withClient(api.client),
      realtimeClient: realtime,
    );
    final userProvider = (await tester.runAsync(_loadedWorker))!;
    final chatList = ChangeNotifierProvider.value(
      value: userProvider,
      child: ChatListPage(controller: controller),
    );
    final router = GoRouter(
      initialLocation: '/explore',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              _KeepAliveShell(chatList: chatList),
          routes: [
            GoRoute(
              path: '/explore',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SizedBox.shrink()),
            ),
            GoRoute(
              path: '/chat',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SizedBox.shrink()),
            ),
          ],
        ),
      ],
    );
    addTearDown(realtime.dispose);
    addTearDown(controller.dispose);
    addTearDown(userProvider.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();

    // İlk yükleme: sayfa kurulur kurulmaz, sekme görünmese de.
    expect(listRequests, 1);
    expect(find.text('Hafta Sonu Garson'), findsNothing);

    // İstek üretimdeki interceptor zincirinden geçiyor ve sekme geçişi
    // yalnızca bir iki kare çiziyor; `pumpAndSettle` zincir bitmeden döner.
    // Olay döngüsü sabit sayıda kareyle ilerletiliyor.
    router.go('/chat');
    await settleNetwork(tester);

    // Sekmeye geçiş: liste yeniden çekildi ve grup göründü; yükleme
    // göstergesi açılmadı.
    expect(listRequests, 2);
    expect(find.text('Hafta Sonu Garson'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    router.go('/explore');
    await settleNetwork(tester);

    // Sekmeden ayrılmak istek atmıyor.
    expect(listRequests, 2);

    router.go('/chat');
    await settleNetwork(tester);

    expect(listRequests, 3);
  });
}

Future<void> settleNetwork(WidgetTester tester) async {
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}
