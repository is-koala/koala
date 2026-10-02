import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_participants_sheet.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/network/realtime_event.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import 'chat_page_retry_harness.dart';
import 'fake_api.dart';
import 'fake_realtime.dart';
import 'finders.dart';
import 'pump.dart';

const _other = 'user_other';
const _officer = 'user_officer';
const _gone = 'user_gone';

/// İlan grubunun katılımcıları (is-koala/koala-backend#281 gövdesi):
/// oturum sahibi, bir çalışan, bir şirket yetkilisi ve ayrılmış bir üye.
List<ChatParticipant> _participants({
  required String currentUserId,
  required bool isEmployer,
}) => [
  ChatParticipant(
    id: currentUserId,
    firstName: isEmployer ? 'İşveren' : 'Yakup',
    lastName: isEmployer ? 'Kullanıcı' : 'Kahraman',
    role: isEmployer
        ? ChatParticipantRole.employer
        : ChatParticipantRole.worker,
    joinedAt: DateTime.utc(2026, 9, 1, 8),
  ),
  ChatParticipant(
    id: _other,
    firstName: 'Ayşe',
    lastName: 'Yılmaz',
    role: ChatParticipantRole.worker,
    joinedAt: DateTime.utc(2026, 9, 2, 8),
    lastReadAt: DateTime.utc(2026, 9, 14, 9, 30),
  ),
  ChatParticipant(
    id: _officer,
    firstName: 'Yetkili',
    lastName: 'Kişi',
    role: ChatParticipantRole.companyContact,
    joinedAt: DateTime.utc(2026, 9, 3, 8),
  ),
  ChatParticipant(
    id: _gone,
    firstName: 'Eski',
    lastName: 'Üye',
    role: ChatParticipantRole.worker,
    joinedAt: DateTime.utc(2026, 9, 4, 8),
    left: true,
  ),
];

Conversation _group({
  required String currentUserId,
  required bool isEmployer,
  bool closed = false,
}) => Conversation(
  id: 'conv_crew',
  jobId: 'job_1',
  jobTitle: 'Hafta Sonu Garson',
  counterpartId: '',
  name: 'Hafta Sonu Garson',
  avatar: 'HG',
  kind: ConversationKind.group,
  participants: _participants(
    currentUserId: currentUserId,
    isEmployer: isEmployer,
  ),
  closed: closed,
);

const _direct = Conversation(
  id: 'conv_1',
  jobId: 'job_1',
  jobTitle: 'Garson',
  counterpartId: _other,
  name: 'Ayşe Yılmaz',
  avatar: 'AY',
);

/// Sunucunun mesaj sayfası: benim mesajım, Ayşe'nin adı olmadan gelen
/// mesajı (eski sunucu → katılımcı eşlemesi), ayrılan üyenin mesajı ve
/// `senderName` taşıyan bir mesaj (yeni sunucu).
List<Map<String, dynamic>> _messages(String currentUserId) => [
  {
    'id': 'm-mine',
    'senderId': currentUserId,
    'body': 'Herkese merhaba',
    'sentAt': '2026-09-14T09:00:00Z',
  },
  {
    'id': 'm-other',
    'senderId': _other,
    'body': 'Merhaba, geliyorum',
    'sentAt': '2026-09-14T09:10:00Z',
  },
  {
    'id': 'm-gone',
    'senderId': _gone,
    'body': 'Ben gelemeyeceğim',
    'sentAt': '2026-09-14T09:20:00Z',
  },
  {
    'id': 'm-named',
    'senderId': _officer,
    'body': 'Not aldım',
    'sentAt': '2026-09-14T09:25:00Z',
    'senderName': 'Yetkili K.',
  },
];

/// Grup sohbeti ekranının iki kabukta aynı davranışını doğrular
/// (is-koala/koala#179): gönderen adı, görüldü sayısı ve canlı
/// güncellenmesi, başlığa dokununca katılımcılar sheet'i ve oradan
/// başkasının profiline gidiş (is-koala/koala#182).
///
/// Profil iki kabukta farklı sayfa: [profileRoute] kabuğun açtığı rotanın
/// kalıbı, [profileLocation] başkasının satırına dokununca açılan adres,
/// [profileExtra] o rotaya verilen `extra`'nın beklentisi. Bağlantının
/// **var** olması iki kabukta aynı; **kendi satırı** ise yalnız çalışan
/// kabuğunda profil sekmesine gidiyor (`EmployeeRoutes.ownProfile`),
/// işverende dokunulmuyor.
void registerChatPageGroupTests({
  required String role,
  required String currentUserId,
  required bool isEmployer,
  required ChatPageBuilder buildPage,
  required String profileRoute,
  required String profileLocation,
  required Matcher profileExtra,
}) {
  Future<
    ({
      FakeApi api,
      FakeLiveRealtimeClient realtime,
      ChatThreadController thread,
      UserProvider userProvider,
    })
  >
  setUpThread(
    WidgetTester tester, {
    required Conversation chat,
    List<Map<String, dynamic>>? messages,
  }) async {
    final api = FakeApi(
      handler: (options) => options.method == 'GET'
          ? FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'content': messages ?? _messages(currentUserId)},
              },
            )
          : const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    final realtime = FakeLiveRealtimeClient();
    final thread = ChatThreadController(
      conversationId: chat.id,
      participants: chat.participants,
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
    return (
      api: api,
      realtime: realtime,
      thread: thread,
      userProvider: userProvider,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Conversation chat,
    required ChatThreadController thread,
    required UserProvider userProvider,
    required Brightness brightness,
  }) async {
    await pumpInApp(
      tester,
      ChangeNotifierProvider.value(
        value: userProvider,
        child: buildPage(chat, thread),
      ),
      brightness: brightness,
    );
    await tester.pumpAndSettle();
  }

  /// Sayfayı bir [GoRouter] içinde çizer: katılımcı satırı `context.push`
  /// ile profile gidiyor, düz `MaterialApp` bunu karşılayamaz. Profil rotası
  /// ve kendi profil sekmesi sahte; açılan adresler, `extra`'lar ve sekme
  /// ziyaretleri dönen kayıtta birikiyor.
  Future<
    ({List<String> locations, List<Object?> extras, List<String> ownVisits})
  >
  pumpPageInRouter(
    WidgetTester tester, {
    required Conversation chat,
    required ChatThreadController thread,
    required UserProvider userProvider,
    required Brightness brightness,
  }) async {
    final extras = <Object?>[];
    final locations = <String>[];
    final ownVisits = <String>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: buildPage(chat, thread),
          ),
        ),
        GoRoute(
          path: profileRoute,
          pageBuilder: (context, state) {
            extras.add(state.extra);
            locations.add(state.matchedLocation);
            return MaterialPage<void>(
              key: state.pageKey,
              child: const Scaffold(body: Text('profil ekranı')),
            );
          },
        ),
        GoRoute(
          path: EmployeeRoutes.ownProfile,
          pageBuilder: (context, state) {
            ownVisits.add(state.matchedLocation);
            return MaterialPage<void>(
              key: state.pageKey,
              child: const Scaffold(body: Text('profil sekmesi')),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: userProvider,
        child: MaterialApp.router(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (locations: locations, extras: extras, ownVisits: ownVisits);
  }

  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('$role grup / $themeName tema', () {
      testWidgets('karşı tarafın balonunda gönderen adı, kendi balonunda yok', (
        tester,
      ) async {
        final chat = _group(
          currentUserId: currentUserId,
          isEmployer: isEmployer,
        );
        final setup = await setUpThread(tester, chat: chat);
        await pumpPage(
          tester,
          chat: chat,
          thread: setup.thread,
          userProvider: setup.userProvider,
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(MessageBubble), findsNWidgets(4));
        // Eski sunucu: ad katılımcı listesinden.
        expect(
          find.descendant(
            of: find.widgetWithText(MessageBubble, 'Merhaba, geliyorum'),
            matching: find.text('Ayşe Yılmaz'),
          ),
          findsOneWidget,
        );
        // Ayrılan üye: ad + etiket.
        final goneBubble = find.widgetWithText(
          MessageBubble,
          'Ben gelemeyeceğim',
        );
        expect(
          find.descendant(of: goneBubble, matching: find.text('Eski Üye')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: goneBubble, matching: find.text('Ayrıldı')),
          findsOneWidget,
        );
        // Yeni sunucu: `senderName` katılımcı adının önüne geçer.
        expect(find.text('Yetkili K.'), findsOneWidget);
        expect(find.text('Yetkili Kişi'), findsNothing);
        // Kendi balonumda ad yok.
        final mine = find.widgetWithText(MessageBubble, 'Herkese merhaba');
        expect(
          find.descendant(
            of: mine,
            matching: find.text(isEmployer ? 'İşveren Kullanıcı' : 'Yakup'),
          ),
          findsNothing,
        );
      });

      testWidgets(
        'görüldü sayısı katılımcı damgasından, READ olayıyla canlı artar',
        (tester) async {
          final chat = _group(
            currentUserId: currentUserId,
            isEmployer: isEmployer,
          );
          final setup = await setUpThread(tester, chat: chat);
          await pumpPage(
            tester,
            chat: chat,
            thread: setup.thread,
            userProvider: setup.userProvider,
            brightness: brightness,
          );

          // Yalnız Ayşe'nin damgası (09:30) mesajımdan (09:00) sonra.
          expect(find.text('1 kişi gördü'), findsOneWidget);
          final fetchesBefore = setup.api.requests
              .where((r) => r.method == 'GET')
              .length;

          setup.realtime.emitConversationEvent(
            RealtimeEvent.fromJson({
              'type': 'READ',
              'conversationId': chat.id,
              'userId': _officer,
              'lastReadAt': '2026-09-14T09:40:00Z',
              'at': '2026-09-14T09:40:00Z',
            }),
          );
          await tester.pumpAndSettle();

          expect(find.text('2 kişi gördü'), findsOneWidget);
          expect(
            setup.api.requests.where((r) => r.method == 'GET').length,
            fetchesBefore,
          );

          await tester.tap(find.text('2 kişi gördü'));
          await tester.pumpAndSettle();

          expect(find.text('Görenler'), findsOneWidget);
          expect(find.text('Yetkili Kişi'), findsOneWidget);
        },
      );

      testWidgets('başlığa dokununca katılımcılar sheet\'i açılır', (
        tester,
      ) async {
        final chat = _group(
          currentUserId: currentUserId,
          isEmployer: isEmployer,
          closed: true,
        );
        final setup = await setUpThread(tester, chat: chat);
        await pumpPage(
          tester,
          chat: chat,
          thread: setup.thread,
          userProvider: setup.userProvider,
          brightness: brightness,
        );

        // Dört katılımcıdan biri ayrıldı; sayı üç.
        await tester.tap(find.text('3 katılımcı'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ChatParticipantsSheet), findsOneWidget);
        expect(find.text(ChatParticipantsSheet.title), findsOneWidget);
        expect(find.text('Çalışan · Katılım: 02.09.2026'), findsOneWidget);
        expect(
          find.text('Şirket yetkilisi · Katılım: 03.09.2026'),
          findsOneWidget,
        );
        expect(find.text(ChatParticipantsSheet.youTag), findsOneWidget);
        // Arkadaki balonda da "Ayrıldı" var; sheet'in kendi etiketi aranıyor.
        expect(
          find.descendant(
            of: find.byType(ChatParticipantsSheet),
            matching: find.text(ChatParticipantsSheet.leftTag),
          ),
          findsOneWidget,
        );
        expect(find.text(ChatParticipantsSheet.closedNote), findsOneWidget);
        // Profil bağlantısı iki kabukta da var (is-koala/koala#182): ayrılan
        // dahil diğer üç satır. Kendi satırım yalnız çalışan kabuğunda
        // dokunulabilir (profil sekmesi), işverende ok yok.
        expect(
          findAppIcon(AppIcons.arrowRight),
          findsNWidgets(isEmployer ? 3 : 4),
        );
      });

      testWidgets('katılımcı satırına dokununca kabuğun profil rotası açılır', (
        tester,
      ) async {
        final chat = _group(
          currentUserId: currentUserId,
          isEmployer: isEmployer,
        );
        final setup = await setUpThread(tester, chat: chat);
        final opened = await pumpPageInRouter(
          tester,
          chat: chat,
          thread: setup.thread,
          userProvider: setup.userProvider,
          brightness: brightness,
        );

        await tester.tap(find.text('3 katılımcı'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(ChatParticipantsSheet),
            matching: find.text('Ayşe Yılmaz'),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(opened.extras, hasLength(1));
        expect(opened.extras.single, profileExtra);
        expect(opened.locations, [profileLocation]);
        expect(opened.ownVisits, isEmpty);
        expect(find.text('profil ekranı'), findsOneWidget);
        // Sheet profil açılmadan kapanıyor: dönüşte sohbet görünsün.
        expect(find.byType(ChatParticipantsSheet), findsNothing);
      });

      testWidgets(
        isEmployer
            ? 'kendi satırı dokunulmaz: profil açılmaz, sheet kalır'
            : 'kendi satırı profil sekmesine gider, başkasının profili açılmaz',
        (tester) async {
          final chat = _group(
            currentUserId: currentUserId,
            isEmployer: isEmployer,
          );
          final setup = await setUpThread(tester, chat: chat);
          final opened = await pumpPageInRouter(
            tester,
            chat: chat,
            thread: setup.thread,
            userProvider: setup.userProvider,
            brightness: brightness,
          );

          await tester.tap(find.text('3 katılımcı'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(ChatParticipantsSheet),
              matching: find.text(
                isEmployer ? 'İşveren Kullanıcı' : 'Yakup Kahraman',
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Başkasının profili iki kabukta da açılmadı.
          expect(opened.extras, isEmpty);
          expect(opened.locations, isEmpty);
          if (isEmployer) {
            // İşveren: davranış değişmedi, satır dokunulmaz.
            expect(opened.ownVisits, isEmpty);
            expect(find.byType(ChatParticipantsSheet), findsOneWidget);
          } else {
            // Çalışan: sheet kapanır, kendi profil sekmesi açılır.
            expect(opened.ownVisits, [EmployeeRoutes.ownProfile]);
            expect(find.text('profil sekmesi'), findsOneWidget);
            expect(find.byType(ChatParticipantsSheet), findsNothing);
          }
        },
      );

      testWidgets('ikili sohbette ne gönderen adı ne görüldü sayısı var', (
        tester,
      ) async {
        final setup = await setUpThread(
          tester,
          chat: _direct,
          messages: [
            {
              'id': 'm-mine',
              'senderId': currentUserId,
              'body': 'Merhaba',
              'sentAt': '2026-09-14T09:00:00Z',
              'readAt': '2026-09-14T09:05:00Z',
            },
            {
              'id': 'm-other',
              'senderId': _other,
              'body': 'Selam',
              'sentAt': '2026-09-14T09:10:00Z',
              'senderName': 'Ayşe Yılmaz',
            },
          ],
        );
        await pumpPage(
          tester,
          chat: _direct,
          thread: setup.thread,
          userProvider: setup.userProvider,
          brightness: brightness,
        );

        expect(find.byType(MessageBubble), findsNWidgets(2));
        // Ad yalnız başlıkta; balonda tekrar yazılmıyor.
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
        expect(find.textContaining('kişi gördü'), findsNothing);

        // İkili sohbette başlık dokunulmuyor: sheet açılmaz.
        await tester.tap(find.text('Ayşe Yılmaz'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatParticipantsSheet), findsNothing);
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
