import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/message_sender.dart';

const _participants = [
  ChatParticipant(
    id: 'worker-1',
    firstName: 'Yakup',
    lastName: 'Kahraman',
    profilePictureUrl: 'https://example.com/yakup.png',
  ),
  ChatParticipant(id: 'gone-1', firstName: 'Eski', lastName: 'Üye', left: true),
];

Message buildMessage({
  String senderId = 'worker-1',
  String? senderName,
  String? senderProfilePictureUrl,
}) {
  return Message(
    id: 'm1',
    conversationId: 'c1',
    senderId: senderId,
    senderName: senderName,
    senderProfilePictureUrl: senderProfilePictureUrl,
    body: 'Merhaba',
    sentAt: DateTime.utc(2026, 9, 14, 10),
    isMe: false,
  );
}

void main() {
  group('MessageSender.resolve', () {
    test('sunucu senderName gönderdiyse o kullanılır', () {
      final sender = MessageSender.resolve(
        buildMessage(
          senderName: 'Yakup K.',
          senderProfilePictureUrl: 'https://example.com/fresh.png',
        ),
        _participants,
      );

      expect(sender.name, 'Yakup K.');
      expect(sender.avatarUrl, 'https://example.com/fresh.png');
      expect(sender.initials, 'YK');
    });

    // Eski sunucu `senderName` göndermiyor; ad katılımcı listesinden.
    test('senderName yoksa katılımcı eşlemesi', () {
      final sender = MessageSender.resolve(buildMessage(), _participants);

      expect(sender.name, 'Yakup Kahraman');
      expect(sender.avatarUrl, 'https://example.com/yakup.png');
      expect(sender.left, isFalse);
    });

    test('ayrılan katılımcının mesajı adı ve ayrıldı bilgisiyle çözülür', () {
      final sender = MessageSender.resolve(
        buildMessage(senderId: 'gone-1'),
        _participants,
      );

      expect(sender.name, 'Eski Üye');
      expect(sender.left, isTrue);
    });

    // `senderName` gelse de "Ayrıldı" bilgisi yalnız katılımcı listesinde.
    test('senderName varken ayrıldı bilgisi listeden gelir', () {
      final sender = MessageSender.resolve(
        buildMessage(senderId: 'gone-1', senderName: 'Eski Üye'),
        _participants,
      );

      expect(sender.left, isTrue);
    });

    test('hiçbir kaynakta yoksa anonim', () {
      final sender = MessageSender.resolve(
        buildMessage(senderId: 'unknown'),
        _participants,
      );

      expect(sender.name, ChatParticipant.anonymousName);
      expect(sender.avatarUrl, isNull);
      expect(sender.left, isFalse);
    });
  });
}
