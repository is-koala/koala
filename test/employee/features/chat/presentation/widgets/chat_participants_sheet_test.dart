import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_participants_sheet.dart';
import 'package:koala/product/constants/app_icons.dart';

import '../../../../../support/finders.dart';
import '../../../../../support/pump.dart';

const _chat = Conversation(
  id: 'conv-crew',
  jobId: 'job-1',
  jobTitle: 'Hafta Sonu Garson',
  counterpartId: '',
  name: 'Hafta Sonu Garson',
  avatar: 'HG',
  kind: ConversationKind.group,
  participantCount: 3,
);

final _participants = [
  ChatParticipant(
    id: 'gone',
    firstName: 'Eski',
    lastName: 'Üye',
    role: ChatParticipantRole.worker,
    joinedAt: DateTime(2026, 9, 3),
    left: true,
  ),
  ChatParticipant(
    id: 'employer',
    firstName: 'Kahve',
    lastName: 'Durağı',
    role: ChatParticipantRole.employer,
    joinedAt: DateTime(2026, 9, 1),
  ),
  ChatParticipant(
    id: 'officer',
    firstName: 'Yetkili',
    lastName: 'Kişi',
    role: ChatParticipantRole.companyContact,
    joinedAt: DateTime(2026, 9, 2),
  ),
  ChatParticipant(
    id: 'me',
    firstName: 'Yakup',
    lastName: 'Kahraman',
    role: ChatParticipantRole.worker,
    joinedAt: DateTime(2026, 9, 4),
  ),
];

/// Bir katılımcının satırındaki metinlerin dikey sırası için `dy`.
double _dyOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'açık' : 'koyu';

    group('ChatParticipantsSheet / $themeName tema', () {
      testWidgets('ilan başlığı, sayı, rol ve katılma tarihi yazar', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          ChatParticipantsSheet(
            chat: _chat,
            participants: _participants,
            currentUserId: 'me',
          ),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(ChatParticipantsSheet.title), findsOneWidget);
        expect(find.text('Hafta Sonu Garson'), findsOneWidget);
        expect(find.text('4 katılımcı'), findsOneWidget);
        expect(find.text('Kahve Durağı'), findsOneWidget);
        expect(find.text('İşveren · Katılım: 01.09.2026'), findsOneWidget);
        expect(
          find.text('Şirket yetkilisi · Katılım: 02.09.2026'),
          findsOneWidget,
        );
        expect(find.text('Çalışan · Katılım: 04.09.2026'), findsOneWidget);
        expect(find.text(ChatParticipantsSheet.youTag), findsOneWidget);
      });

      testWidgets('ayrılan katılımcı etiketle listenin sonunda', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          ChatParticipantsSheet(chat: _chat, participants: _participants),
          brightness: brightness,
        );

        expect(find.text(ChatParticipantsSheet.leftTag), findsOneWidget);
        // Sunucu sırasında ilk gelmesine rağmen ayrılan en alta iniyor.
        expect(
          _dyOf(tester, 'Eski Üye'),
          greaterThan(_dyOf(tester, 'Yakup Kahraman')),
        );
        // Ayrılanın adı gri: aktif katılımcının renginden farklı.
        final leftName = tester.widget<Text>(find.text('Eski Üye'));
        final activeName = tester.widget<Text>(find.text('Kahve Durağı'));
        expect(leftName.style?.color, isNot(activeName.style?.color));
      });

      testWidgets('sohbet kapalıysa not var', (tester) async {
        await pumpInApp(
          tester,
          ChatParticipantsSheet(
            chat: _chat.copyWith(closed: true),
            participants: _participants,
          ),
          brightness: brightness,
        );

        expect(find.text(ChatParticipantsSheet.closedNote), findsOneWidget);
      });

      testWidgets('açık sohbette not yok', (tester) async {
        await pumpInApp(
          tester,
          ChatParticipantsSheet(chat: _chat, participants: _participants),
          brightness: brightness,
        );

        expect(find.text(ChatParticipantsSheet.closedNote), findsNothing);
      });

      testWidgets('profil bağlantısı verilince satır dokununca çağrılır', (
        tester,
      ) async {
        ChatParticipant? opened;
        await pumpInApp(
          tester,
          ChatParticipantsSheet(
            chat: _chat,
            participants: _participants,
            currentUserId: 'me',
            onOpenProfile: (participant) => opened = participant,
          ),
          brightness: brightness,
        );

        // Kendi satırım dışındaki üç satırda ok var.
        expect(findAppIcon(AppIcons.arrowRight), findsNWidgets(3));

        await tester.tap(find.text('Kahve Durağı'));
        await tester.pumpAndSettle();

        expect(opened?.id, 'employer');
      });

      testWidgets('profil bağlantısı yoksa satırlar dokunulmuyor', (
        tester,
      ) async {
        await pumpInApp(
          tester,
          ChatParticipantsSheet(chat: _chat, participants: _participants),
          brightness: brightness,
        );

        expect(findAppIcon(AppIcons.arrowRight), findsNothing);
        for (final participant in _participants) {
          final row = tester.widget<InkWell>(
            find.ancestor(
              of: find.text(participant.fullName),
              matching: find.byType(InkWell),
            ),
          );
          expect(row.onTap, isNull, reason: participant.fullName);
        }
      });

      // Sohbeti açan POST yanıtı ve eski sunucu boş liste verebiliyor.
      testWidgets('liste boşsa açıklama yazar', (tester) async {
        await pumpInApp(
          tester,
          const ChatParticipantsSheet(chat: _chat, participants: []),
          brightness: brightness,
        );

        expect(find.text(ChatParticipantsSheet.emptyNote), findsOneWidget);
        expect(find.text('0 katılımcı'), findsOneWidget);
      });

      // Eski sunucu rol ve tarih göndermiyor; satır yalnız adla kalıyor.
      testWidgets('rol ve tarih yoksa ayrıntı satırı boş', (tester) async {
        await pumpInApp(
          tester,
          ChatParticipantsSheet(
            chat: _chat,
            participants: const [
              ChatParticipant(id: 'x', firstName: 'Ali', lastName: 'Veli'),
            ],
          ),
          brightness: brightness,
        );

        expect(find.text('Ali Veli'), findsOneWidget);
        expect(find.textContaining('Katılım:'), findsNothing);
      });
    });
  }
}
