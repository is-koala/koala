import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:koala/product/services/push_conversation_opener.dart';

/// `openChatOn` gerçek uygulama router'ıyla çağrılıyor; burada aynı biçimde
/// kurulmuş küçük bir router var: kabuk içinde liste (`ShellRoute`), üst
/// düzeyde `extra` olarak [Conversation] bekleyen sohbet ekranı. Uygulamanın
/// sayfaları sağlayıcı ormanı istiyor, biçim ise burada sınanabiliyor.
void main() {
  const conversation = Conversation(
    id: 'conv_1',
    jobId: 'job_1',
    jobTitle: 'Garson',
    counterpartId: 'user_other',
    name: 'Ayşe Yılmaz',
    avatar: 'AY',
  );

  late GoRouter router;

  GoRouter buildRouter(ChatRoutes routes) => GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            Scaffold(body: child, bottomNavigationBar: const Text('navbar')),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: Text('ana sayfa')),
          ),
          GoRoute(
            path: routes.list,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: Text('sohbet listesi')),
          ),
        ],
      ),
      GoRoute(
        path: routes.detail,
        pageBuilder: (context, state) {
          final chat = state.extra as Conversation;
          return MaterialPage(child: Text('sohbet: ${chat.name}'));
        },
      ),
    ],
  );

  Future<void> pumpRouter(WidgetTester tester, ChatRoutes routes) async {
    router = buildRouter(routes);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Iterable<String> stack() => router.routerDelegate.currentConfiguration.matches
      .map((match) => match.matchedLocation);

  for (final routes in [ChatRoutes.employee, ChatRoutes.business]) {
    testWidgets(
      'liste üstüne sohbet ekranı açılır, geri liste (${routes.list})',
      (tester) async {
        await pumpRouter(tester, routes);

        openChatOn(router, routes, conversation);
        await tester.pumpAndSettle();

        expect(find.text('sohbet: Ayşe Yılmaz'), findsOneWidget);
        expect(stack(), [routes.list, routes.detail]);

        router.pop();
        await tester.pumpAndSettle();

        expect(find.text('sohbet listesi'), findsOneWidget);
        expect(find.text('navbar'), findsOneWidget);
        expect(stack(), [routes.list]);
      },
    );
  }

  testWidgets('sohbet yoksa yalnız liste açılır', (tester) async {
    await pumpRouter(tester, ChatRoutes.employee);

    openChatOn(router, ChatRoutes.employee, null);
    await tester.pumpAndSettle();

    expect(find.text('sohbet listesi'), findsOneWidget);
    expect(stack(), ['/chat']);
  });

  // Gerçek router'da sohbet ekranları kabuğun dışında olmalı; içeride
  // kalsalar navbar'ın altında açılır ve `pop` listeye değil kabuğa düşer.
  test(
    'uygulama router\'ında sohbet ekranları üst düzeyde, listeler kabukta',
    () {
      final topLevel = RouterManager.router.configuration.routes
          .whereType<GoRoute>()
          .map((route) => route.path);
      final inShell = RouterManager.router.configuration.routes
          .whereType<ShellRoute>()
          .expand((shell) => shell.routes.whereType<GoRoute>())
          .map((route) => route.path);

      for (final routes in [ChatRoutes.employee, ChatRoutes.business]) {
        expect(topLevel, contains(routes.detail));
        expect(inShell, contains(routes.list));
      }
    },
  );
}
