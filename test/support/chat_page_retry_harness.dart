import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/blocked_notice.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';

import 'fake_api.dart';
import 'fake_realtime.dart';
import 'pump.dart';

typedef ChatPageBuilder =
    Widget Function(Conversation chat, ChatThreadController? threadController);

const _chat = Conversation(
  id: 'conv_1',
  jobId: 'job_1',
  jobTitle: 'Garson',
  counterpartId: 'user_other',
  name: 'Ayşe Yılmaz',
  avatar: 'AY',
);

const _blocked = FakeApiResponse(
  statusCode: 403,
  body: {'success': false, 'message': 'Bu kullanıcıyla mesajlaşamazsınız.'},
);

const _success = FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': {'content': []},
  },
);

/// Çalışan ve işveren sohbet sayfalarının ortak kullanıcı davranışlarını
/// gerçek widget'lar üzerinden doğrular.
///
/// Sayfa kurucu dışında rol ayrıntısı almıyor: retry ve controller yaşam
/// döngüsü iki ekranda aynı interface üzerinden çalışmalı.
void registerChatPageRetryTests({
  required String role,
  required String currentUserId,
  required bool isEmployer,
  required ChatPageBuilder buildPage,
}) {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('$role / $themeName tema', () {
      testWidgets('engel kalkınca tekrar deneme mesaj kutusunu geri getirir', (
        tester,
      ) async {
        var getCount = 0;
        final api = FakeApi(
          handler: (options) {
            if (options.method != 'GET') return _success;
            getCount++;
            return getCount == 1 ? _blocked : _success;
          },
        );
        final realtime = FakeSilentRealtimeClient();
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

        await _pumpPage(
          tester,
          brightness: brightness,
          userProvider: userProvider,
          child: buildPage(_chat, thread),
        );
        expect(find.byType(BlockedNotice), findsOneWidget);
        expect(find.byType(MessageTextField), findsNothing);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Tekrar Dene'));
        await tester.pumpAndSettle();

        expect(find.byType(BlockedNotice), findsNothing);
        expect(find.byType(MessageTextField), findsOneWidget);
      });

      testWidgets('403 sürüyorsa tekrar deneme mesaj kutusunu kapalı tutar', (
        tester,
      ) async {
        final api = FakeApi(handler: (_) => _blocked);
        final realtime = FakeSilentRealtimeClient();
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

        await _pumpPage(
          tester,
          brightness: brightness,
          userProvider: userProvider,
          child: buildPage(_chat, thread),
        );
        await tester.tap(find.widgetWithText(OutlinedButton, 'Tekrar Dene'));
        await tester.pumpAndSettle();

        expect(find.byType(BlockedNotice), findsOneWidget);
        expect(find.byType(MessageTextField), findsNothing);
        expect(
          find.text('Bu kullanıcıyla mesajlaşamazsınız.'),
          findsNWidgets(2),
        );
      });

      testWidgets('üst widget controller değiştirince yeni sohbeti yükler', (
        tester,
      ) async {
        final firstRealtime = FakeSilentRealtimeClient();
        final secondRealtime = FakeSilentRealtimeClient();
        final firstThread = _TrackingChatThreadController(
          conversationId: _chat.id,
          chatService: ChatService.withClient(
            FakeApi(handler: (_) => _blocked).client,
          ),
          realtimeClient: firstRealtime,
        );
        final secondThread = _TrackingChatThreadController(
          conversationId: _chat.id,
          chatService: ChatService.withClient(
            FakeApi(handler: (_) => _success).client,
          ),
          realtimeClient: secondRealtime,
        );
        final selected = ValueNotifier<ChatThreadController?>(firstThread);
        final userProvider = (await tester.runAsync(
          () => _loadedUserProvider(
            currentUserId: currentUserId,
            isEmployer: isEmployer,
          ),
        ))!;
        addTearDown(firstRealtime.dispose);
        addTearDown(secondRealtime.dispose);
        addTearDown(() {
          if (!firstThread.wasDisposed) firstThread.dispose();
          if (!secondThread.wasDisposed) secondThread.dispose();
        });
        addTearDown(selected.dispose);
        addTearDown(userProvider.dispose);

        await _pumpPage(
          tester,
          brightness: brightness,
          userProvider: userProvider,
          child: ValueListenableBuilder<ChatThreadController?>(
            valueListenable: selected,
            builder: (_, thread, _) => buildPage(_chat, thread),
          ),
        );
        expect(find.byType(BlockedNotice), findsOneWidget);

        selected.value = secondThread;
        await tester.pumpAndSettle();

        expect(find.byType(BlockedNotice), findsNothing);
        expect(find.byType(MessageTextField), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(firstThread.wasDisposed, isFalse);
        expect(secondThread.wasDisposed, isFalse);
      });

      testWidgets('dış controller kaldırılınca sahipliğini üstlenmez', (
        tester,
      ) async {
        final realtime = FakeSilentRealtimeClient();
        final externalThread = _TrackingChatThreadController(
          conversationId: _chat.id,
          chatService: ChatService.withClient(
            FakeApi(handler: (_) => _blocked).client,
          ),
          realtimeClient: realtime,
        );
        await tester.runAsync(
          () => externalThread.load(currentUserId: currentUserId),
        );

        final pendingProfile = Completer<FakeApiResponse>();
        final profileApi = FakeApi(handler: (_) => pendingProfile.future);
        final userProvider = UserProvider(
          userService: UserService.withClient(profileApi.client),
        );
        await tester.runAsync(() async {
          unawaited(userProvider.load());
          await profileApi.requestsReach(1);
        });
        final selected = ValueNotifier<ChatThreadController?>(externalThread);
        addTearDown(realtime.dispose);
        addTearDown(() {
          if (!externalThread.wasDisposed) externalThread.dispose();
        });
        addTearDown(selected.dispose);
        addTearDown(userProvider.dispose);

        await _pumpPage(
          tester,
          brightness: brightness,
          userProvider: userProvider,
          child: ValueListenableBuilder<ChatThreadController?>(
            valueListenable: selected,
            builder: (_, thread, _) => buildPage(_chat, thread),
          ),
        );

        selected.value = null;
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());

        expect(externalThread.wasDisposed, isFalse);
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

Future<void> _pumpPage(
  WidgetTester tester, {
  required Brightness brightness,
  required UserProvider userProvider,
  required Widget child,
}) async {
  await pumpInApp(
    tester,
    ChangeNotifierProvider.value(value: userProvider, child: child),
    brightness: brightness,
  );
  await tester.pumpAndSettle();
}

class _TrackingChatThreadController extends ChatThreadController {
  _TrackingChatThreadController({
    required super.conversationId,
    required super.chatService,
    required super.realtimeClient,
  });

  bool wasDisposed = false;

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}
