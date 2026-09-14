import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_list_tile.dart';

import '../../../../../support/pump.dart';

const _direct = Conversation(
  id: 'conv-1',
  jobId: 'job-1',
  jobTitle: 'Hafta Sonu Garson',
  counterpartId: 'employer-1',
  name: 'Kahve Durağı',
  avatar: 'KD',
  lastMessage: 'Yarın görüşürüz',
);

const _group = Conversation(
  id: 'conv-crew',
  jobId: 'job-1',
  jobTitle: 'Hafta Sonu Garson',
  counterpartId: '',
  name: 'Hafta Sonu Garson',
  avatar: 'HG',
  kind: ConversationKind.group,
  participantCount: 3,
  lastMessage: 'Herkese merhaba',
);

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('ChatListTile / $themeName tema', () {
      testWidgets('ikili sohbet karşı tarafın adını yazar, sayı yok', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          const ChatListTile(chat: _direct),
          brightness: brightness,
        );

        expect(find.text('Kahve Durağı'), findsOneWidget);
        expect(find.text('Yarın görüşürüz'), findsOneWidget);
        expect(find.textContaining('katılımcı'), findsNothing);
      });

      testWidgets('grup satırı ilan başlığı ve katılımcı sayısıyla çizilir', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          const ChatListTile(chat: _group),
          brightness: brightness,
        );

        expect(find.text('Hafta Sonu Garson'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('chat-participants-conv-crew')),
          findsOneWidget,
        );
        expect(find.text('3 katılımcı'), findsOneWidget);
        expect(find.text('Herkese merhaba'), findsOneWidget);
      });
    });
  }
}
