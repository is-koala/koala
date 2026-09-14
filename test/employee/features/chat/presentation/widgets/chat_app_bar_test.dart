import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_app_bar.dart';

import '../../../../../support/pump.dart';

const _chat = Conversation(
  id: 'c1',
  jobId: 'j1',
  jobTitle: 'Garson',
  counterpartId: 'u9',
  name: 'Ayşe Yılmaz',
  avatar: 'AY',
);

const _group = Conversation(
  id: 'c2',
  jobId: 'j1',
  jobTitle: 'Garson',
  counterpartId: '',
  name: 'Garson',
  avatar: 'G',
  kind: ConversationKind.group,
  participants: [
    ChatParticipant(id: 'p1', firstName: 'Kahve', lastName: 'Durağı'),
    ChatParticipant(id: 'p2', firstName: 'Yetkili', lastName: 'Kişi'),
    ChatParticipant(id: 'p3', firstName: 'Yakup', lastName: 'Kahraman'),
  ],
);

void main() {
  group('ChatAppBar taşma menüsü', () {
    testWidgets('menü açılınca şikayet eylemi görünür', (tester) async {
      await pumpInApp(tester, const ChatAppBar(chat: _chat));

      // Menünün değer tipi private; `byType` yerine tip yüklemiyle
      // aranıyor.
      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();

      expect(find.text('Şikayet Et'), findsOneWidget);
    });

    testWidgets('menü açılınca engelleme eylemi görünür', (tester) async {
      await pumpInApp(tester, const ChatAppBar(chat: _chat));

      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();

      expect(find.text('Engelle'), findsOneWidget);
    });

    testWidgets('her iki temada da hatasız çizilir', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpInApp(
          tester,
          const ChatAppBar(chat: _chat),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull, reason: '$brightness patladı');
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      }
    });
  });

  // Grupta başlığa dokununca katılımcılar açılıyor (is-koala/koala#179);
  // sayfa bunu `onTitleTap` ile bağlıyor.
  group('ChatAppBar başlık dokunuşu', () {
    testWidgets('onTitleTap verilince ada dokununca çağrılır', (tester) async {
      var taps = 0;
      await pumpInApp(
        tester,
        ChatAppBar(chat: _group, onTitleTap: () => taps++),
      );

      await tester.tap(find.text('Garson'));
      await tester.pump();

      expect(taps, 1);
      // Katılımcı sayısı da başlığın parçası; ona dokunmak da açıyor.
      await tester.tap(find.text('3 katılımcı'));
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('dokunulabilir başlık erişilebilirlikte düğme', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInApp(tester, ChatAppBar(chat: _group, onTitleTap: () {}));

      final semantics = tester.getSemantics(find.text('3 katılımcı'));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.label, contains(ChatAppBar.participantsSemanticsLabel));
      handle.dispose();
    });

    testWidgets('onTitleTap yoksa dokunmak bir şey yapmaz', (tester) async {
      await pumpInApp(tester, const ChatAppBar(chat: _chat));

      await tester.tap(find.text('Ayşe Yılmaz'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('grup başlığı iki temada da çizilir', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpInApp(
          tester,
          ChatAppBar(chat: _group, onTitleTap: () {}),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull, reason: '$brightness patladı');
        expect(find.text('3 katılımcı'), findsOneWidget);
      }
    });
  });
}
