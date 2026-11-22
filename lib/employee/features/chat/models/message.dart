/// Tek mesaj (`MessageDto`); `conversationId` ve [isMe] bağlamdan.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.isMe,
    this.senderName,
    this.senderProfilePictureUrl,
    this.readAt,
    this.status = MessageStatus.sent,
  });

  final String id;

  final String conversationId;

  final String senderId;

  /// Eski sunucuda `null`; grup balonu adı katılımcılardan çözer.
  final String? senderName;

  final String? senderProfilePictureUrl;

  /// En fazla 4000 karakter.
  final String body;

  final DateTime sentAt;

  final DateTime? readAt;

  final bool isMe;

  /// [MessageStatus.sending] ve [MessageStatus.failed] yalnız istemcide.
  final MessageStatus status;

  String get timeString {
    final difference = DateTime.now().difference(sentAt);

    if (difference.inDays == 0) {
      final hour = sentAt.hour.toString().padLeft(2, '0');
      final minute = sentAt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (difference.inDays == 1) return 'Dün';
    if (difference.inDays < 7) return '${difference.inDays} gün önce';

    return '${sentAt.day}/${sentAt.month}/${sentAt.year}';
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    required String conversationId,
    required String currentUserId,
  }) {
    final readAt = json['readAt'] as String?;
    final senderId = json['senderId'] as String? ?? '';
    final senderName = (json['senderName'] as String?)?.trim();

    return Message(
      id: json['id'] as String,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName == null || senderName.isEmpty ? null : senderName,
      senderProfilePictureUrl: json['senderProfilePictureUrl'] as String?,
      body: json['body'] as String? ?? '',
      sentAt:
          DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
      readAt: readAt == null ? null : DateTime.tryParse(readAt),
      isMe: senderId == currentUserId,
      status: readAt == null ? MessageStatus.sent : MessageStatus.read,
    );
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderProfilePictureUrl,
    String? body,
    DateTime? sentAt,
    DateTime? readAt,
    bool? isMe,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfilePictureUrl:
          senderProfilePictureUrl ?? this.senderProfilePictureUrl,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      isMe: isMe ?? this.isMe,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfilePictureUrl': senderProfilePictureUrl,
      'body': body,
      'sentAt': sentAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isMe': isMe,
      'status': status.name,
    };
  }
}

enum MessageStatus { sending, sent, delivered, read, failed }
