import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/message_sender.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_seen_sheet.dart';

import '../../../../../support/pump.dart';

Message buildMessage({required bool isMe}) {
  return Message(
    id: 'm1',
    conversationId: 'c1',
    senderId: isMe ? 'me' : 'other',
    body: 'Merhaba',
    sentAt: DateTime(2026, 2, 15, 9),
    isMe: isMe,
  );
}

final _readers = [
  ChatParticipant(
    id: 'u2',
    firstName: 'Yakup',
    lastName: 'Kahraman',
    lastReadAt: DateTime(2026, 2, 15, 9, 5),
  ),
  ChatParticipant(
    id: 'u3',
    firstName: 'Yetkili',
    lastName: 'Kişi',
    lastReadAt: DateTime(2026, 2, 15, 9, 10),
  ),
  ChatParticipant(
    id: 'u4',
    firstName: 'Eski',
    lastName: 'Üye',
    left: true,
    lastReadAt: DateTime(2026, 2, 15, 9, 1),
  ),
];

void main() {
  group('MessageBubble uzun basma menüsü', () {
    testWidgets('kendi mesajında şikayet menüsü açılmaz', (tester) async {
      await pumpInApp(
        tester,
        MessageBubble(
          message: buildMessage(isMe: true),
          isNextSameSender: false,
        ),
      );

      await tester.longPress(find.text('Merhaba'));
      await tester.pumpAndSettle();

      // Kendi mesajını şikayet etmenin yolu olmamalı.
      expect(find.text('Şikayet Et'), findsNothing);
    });

    testWidgets('karşı tarafın mesajında şikayet menüsü açılır', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        MessageBubble(
          message: buildMessage(isMe: false),
          isNextSameSender: false,
        ),
      );

      await tester.longPress(find.text('Merhaba'));
      await tester.pumpAndSettle();

      expect(find.text('Şikayet Et'), findsOneWidget);
    });

    testWidgets('her iki temada da hatasız çizilir', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpInApp(
          tester,
          MessageBubble(
            message: buildMessage(isMe: false),
            isNextSameSender: false,
          ),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull, reason: '$brightness patladı');
        expect(find.text('Merhaba'), findsOneWidget);
      }
    });
  });

  // Grup sohbeti: karşı tarafın balonunda gönderen, kendi balonunda görenler
  // (is-koala/koala#179).
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('MessageBubble grup / $themeName tema', () {
      testWidgets('gönderen adı ve avatar baş harfi çizilir', (tester) async {
        await pumpInApp(
          tester,
          MessageBubble(
            message: buildMessage(isMe: false),
            isNextSameSender: false,
            sender: const MessageSender(name: 'Yakup Kahraman'),
          ),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Yakup Kahraman'), findsOneWidget);
        expect(find.text('YK'), findsOneWidget);
        expect(find.byType(ChatAvatar), findsOneWidget);
        expect(find.text('Ayrıldı'), findsNothing);
      });

      testWidgets('ayrılan gönderenin adının yanında Ayrıldı yazar', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          MessageBubble(
            message: buildMessage(isMe: false),
            isNextSameSender: false,
            sender: const MessageSender(name: 'Eski Üye', left: true),
          ),
          brightness: brightness,
        );

        expect(find.text('Eski Üye'), findsOneWidget);
        expect(find.text('Ayrıldı'), findsOneWidget);
      });

      testWidgets('gönderen verilmezse ne ad ne avatar var', (tester) async {
        await pumpInApp(
          tester,
          MessageBubble(
            message: buildMessage(isMe: false),
            isNextSameSender: false,
          ),
          brightness: brightness,
        );

        expect(find.byType(ChatAvatar), findsNothing);
      });

      testWidgets('görenler varsa sayı yazar, dokununca liste açılır', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          MessageBubble(
            message: buildMessage(isMe: true),
            isNextSameSender: false,
            seenBy: _readers,
          ),
          brightness: brightness,
        );

        expect(find.text('3 kişi gördü'), findsOneWidget);

        await tester.tap(find.text('3 kişi gördü'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MessageSeenSheet), findsOneWidget);
        expect(find.text(MessageSeenSheet.title), findsOneWidget);
        expect(find.text('Yakup Kahraman'), findsOneWidget);
        expect(find.text('Yetkili Kişi'), findsOneWidget);
        expect(find.text('Eski Üye'), findsOneWidget);
        expect(find.text('15.02.2026 09:05'), findsOneWidget);
      });

      // Henüz kimse görmediyse de, eski sunucu damga göndermiyorsa da satır
      // yok — ikili sohbetin balonuyla aynı görünüm.
      testWidgets('gören yoksa satır çizilmez', (tester) async {
        await pumpInApp(
          tester,
          MessageBubble(
            message: buildMessage(isMe: true),
            isNextSameSender: false,
          ),
          brightness: brightness,
        );

        expect(find.textContaining('kişi gördü'), findsNothing);
      });
    });
  }
}
