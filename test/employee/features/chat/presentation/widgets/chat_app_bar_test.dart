import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
