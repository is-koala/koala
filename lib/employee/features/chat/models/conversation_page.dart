import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';

/// Sayfalı sohbet listesi. Backend `PageDto<ConversationDto>` karşılığı.
class ConversationPage {
  const ConversationPage({
    this.conversations = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<Conversation> conversations;
  final int page;
  final int totalElements;
  final bool last;

  factory ConversationPage.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final content = json['content'];

    return ConversationPage(
      conversations: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) =>
                      Conversation.fromJson(item, currentUserId: currentUserId),
                )
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}

/// Sayfalı mesaj listesi. Backend `PageDto<MessageDto>` karşılığı.
///
/// Sunucu en yeni mesajı başta döndürüyor; arayüz eskiden yeniye çizdiği için
/// liste burada tarihe göre artan sıraya alınıyor.
class MessagePage {
  const MessagePage({
    this.messages = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<Message> messages;
  final int page;
  final int totalElements;
  final bool last;

  factory MessagePage.fromJson(
    Map<String, dynamic> json, {
    required String conversationId,
    required String currentUserId,
  }) {
    final content = json['content'];

    final messages = content is List
        ? content
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => Message.fromJson(
                  item,
                  conversationId: conversationId,
                  currentUserId: currentUserId,
                ),
              )
              .toList()
        : <Message>[];

    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

    return MessagePage(
      messages: messages,
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
