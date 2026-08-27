/// Bir sohbetteki tek mesaj.
///
/// Backend'deki `MessageDto` (`{id, senderId, body, sentAt, readAt}`)
/// karşılığı. `conversationId` ve [isMe] sunucudan gelmiyor; ikisi de
/// çağrının bağlamından türetiliyor.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.isMe,
    this.readAt,
    this.status = MessageStatus.sent,
  });

  final String id;

  /// Mesajın ait olduğu sohbet. `MessageDto` taşımıyor — mesajlar zaten
  /// `/conversations/{id}/messages` altından geldiği için biliniyor.
  final String conversationId;

  final String senderId;

  /// Mesaj metni. Sunucuda en fazla 4000 karakter.
  final String body;

  final DateTime sentAt;

  /// Karşı tarafın mesajı okuduğu an; okunmadıysa `null`.
  final DateTime? readAt;

  /// Mesajı oturumu açan kullanıcı mı gönderdi. [senderId] ile karşılaştırma
  /// sonucunda doluyor.
  final bool isMe;

  /// Gönderim durumu.
  ///
  /// Sunucu yalnızca okundu/okunmadı ayrımı yapıyor ([readAt]);
  /// [MessageStatus.sending] ve [MessageStatus.failed] iyimser gönderim için
  /// yalnızca istemcide yaşıyor.
  final MessageStatus status;

  /// Balonun altındaki zaman etiketi.
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

    return Message(
      id: json['id'] as String,
      conversationId: conversationId,
      senderId: senderId,
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
      'body': body,
      'sentAt': sentAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isMe': isMe,
      'status': status.name,
    };
  }
}

enum MessageStatus { sending, sent, delivered, read, failed }
