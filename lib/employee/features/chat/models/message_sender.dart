import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';

/// Grup balonundaki gönderen: önce sunucunun `senderName`'i, sonra katılımcı
/// listesi, en son [ChatParticipant.anonymousName]. "Ayrıldı" yalnız katılımcı
/// listesinden gelebilir.
class MessageSender {
  const MessageSender({required this.name, this.avatarUrl, this.left = false});

  final String name;
  final String? avatarUrl;

  final bool left;

  String get initials => Conversation.initialsOf(name);

  static MessageSender resolve(
    Message message,
    List<ChatParticipant> participants,
  ) {
    ChatParticipant? participant;
    for (final candidate in participants) {
      if (candidate.id == message.senderId) {
        participant = candidate;
        break;
      }
    }

    return MessageSender(
      name:
          message.senderName ??
          participant?.fullName ??
          ChatParticipant.anonymousName,
      avatarUrl:
          message.senderProfilePictureUrl ?? participant?.profilePictureUrl,
      left: participant?.left ?? false,
    );
  }
}
