import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';

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
}
