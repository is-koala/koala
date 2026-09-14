import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';

/// Grup balonunun üstünde yazılan gönderen: ad, avatar ve ayrılma bilgisi.
///
/// Üç kaynaktan sırayla çözülüyor: sunucu `senderName` gönderdiyse o
/// (is-koala/koala-backend#281); yoksa sohbetin katılımcı listesinde
/// `senderId` eşleşmesi; o da yoksa [ChatParticipant.anonymousName] — eski
/// sunucu ayrılanları listede taşımıyor, adı çözülemeyen bir gönderen için
/// boş bırakmaktansa anonim yazılıyor. "Ayrıldı" etiketi yalnız katılımcı
/// listesinden gelebiliyor; `MessageDto` bunu taşımıyor.
class MessageSender {
  const MessageSender({required this.name, this.avatarUrl, this.left = false});

  final String name;
  final String? avatarUrl;

  /// Gönderen sohbetten ayrıldı mı; balonda adın yanına "Ayrıldı" yazılıyor.
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
