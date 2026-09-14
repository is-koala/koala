import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/blocked_notice.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:provider/provider.dart';

import 'chat_page_retry_harness.dart';
import 'fake_api.dart';
import 'fake_realtime.dart';
import 'finders.dart';
import 'pump.dart';

const _chat = Conversation(
  id: 'conv_1',
  jobId: 'job_1',
  jobTitle: 'Garson',
  counterpartId: 'user_other',
  name: 'Ayşe Yılmaz',
  avatar: 'AY',
);

const _paymentRequired = FakeApiResponse(
  statusCode: 403,
  body: {
    'success': false,
    'message': 'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
    'errorCode': 'MESSAGING_PAYMENT_REQUIRED',
    'errorCategory': 'ACCESS_DENIED',
  },
);

const _windowClosed = FakeApiResponse(
  statusCode: 409,
  body: {
    'success': false,
    'message': 'Bu iş için mesajlaşma süresi doldu.',
    'errorCode': 'MESSAGING_WINDOW_CLOSED',
    'errorCategory': 'DATA_CONFLICT',
  },
);

const _emptyPage = FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': {'content': []},
  },
);

/// Mesajlaşma kapısının iki sohbet ekranındaki davranışını doğrular.
///
/// Kapı metni tarafa göre değişiyor: [expectedPaymentNote] o kabuğun ödeme
/// bekleniyor cümlesi. Kapalı sohbet cümlesi iki tarafta aynı.
void registerChatPageGateTests({
  required String role,
  required String currentUserId,
  required bool isEmployer,
  required String expectedPaymentNote,
  required ChatPageBuilder buildPage,
}) {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('$role / $themeName tema / mesajlaşma kapısı', () {
      Future<UserProvider> loadedUser(WidgetTester tester) async {
        final provider = (await tester.runAsync(
          () => _loadedUserProvider(
            currentUserId: currentUserId,
            isEmployer: isEmployer,
          ),
        ))!;
        addTearDown(provider.dispose);
        return provider;
      }

      testWidgets(
        '403 MESSAGING_PAYMENT_REQUIRED kutunun yerine ödeme açıklaması koyar',
        (tester) async {
          final api = FakeApi(
            handler: (options) =>
                options.method == 'GET' ? _emptyPage : _paymentRequired,
          );
          final realtime = FakeSilentRealtimeClient();
          final thread = ChatThreadController(
            conversationId: _chat.id,
            chatService: ChatService.withClient(api.client),
            realtimeClient: realtime,
          );
          addTearDown(realtime.dispose);
          addTearDown(thread.dispose);
          final userProvider = await loadedUser(tester);

          await pumpInApp(
            tester,
            ChangeNotifierProvider.value(
              value: userProvider,
              child: buildPage(_chat, thread),
            ),
            brightness: brightness,
          );
          await tester.pumpAndSettle();
          expect(find.byType(MessageTextField), findsOneWidget);

          await tester.enterText(find.byType(TextField), 'Merhaba');
          await tester.tap(find.byIcon(Icons.send));
          await tester.pumpAndSettle();

          expect(find.byType(MessageTextField), findsNothing);
          expect(find.byType(BlockedNotice), findsOneWidget);
          // Şerit + toast: aynı cümle iki yerde.
          expect(find.text(expectedPaymentNote), findsWidgets);
          // Kapı engel değil: engel ikonu değil bilgi ikonu.
          expect(
            find.descendant(
              of: find.byType(BlockedNotice),
              matching: findAppIcon(AppIcons.info),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(BlockedNotice),
              matching: findAppIcon(AppIcons.userBlock),
            ),
            findsNothing,
          );
        },
      );

      testWidgets('409 MESSAGING_WINDOW_CLOSED "Bu sohbet kapandı" yazar', (
        tester,
      ) async {
        final api = FakeApi(
          handler: (options) =>
              options.method == 'GET' ? _emptyPage : _windowClosed,
        );
        final realtime = FakeSilentRealtimeClient();
        final thread = ChatThreadController(
          conversationId: _chat.id,
          chatService: ChatService.withClient(api.client),
          realtimeClient: realtime,
        );
        addTearDown(realtime.dispose);
        addTearDown(thread.dispose);
        final userProvider = await loadedUser(tester);

        await pumpInApp(
          tester,
          ChangeNotifierProvider.value(
            value: userProvider,
            child: buildPage(_chat, thread),
          ),
          brightness: brightness,
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Merhaba');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(find.byType(MessageTextField), findsNothing);
        expect(find.text('Bu sohbet kapandı'), findsWidgets);
        expect(find.text('Bu iş için mesajlaşma süresi doldu.'), findsNothing);
      });

      // Listeden gelen `closed` bayrağı: sunucuya gitmeden kutu kapalı.
      testWidgets('listeden kapalı gelen sohbet kutuyu hiç açmaz', (
        tester,
      ) async {
        final api = FakeApi(handler: (_) => _emptyPage);
        final realtime = FakeSilentRealtimeClient();
        final thread = ChatThreadController(
          conversationId: _chat.id,
          chatService: ChatService.withClient(api.client),
          realtimeClient: realtime,
        );
        addTearDown(realtime.dispose);
        addTearDown(thread.dispose);
        final userProvider = await loadedUser(tester);

        await pumpInApp(
          tester,
          ChangeNotifierProvider.value(
            value: userProvider,
            child: buildPage(_chat.copyWith(closed: true), thread),
          ),
          brightness: brightness,
        );
        await tester.pumpAndSettle();

        expect(find.byType(MessageTextField), findsNothing);
        expect(find.text('Bu sohbet kapandı'), findsOneWidget);
        expect(
          api.requests
              .where((r) => r.path.endsWith('/messages'))
              .map((r) => r.method),
          isNot(contains('POST')),
        );
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
