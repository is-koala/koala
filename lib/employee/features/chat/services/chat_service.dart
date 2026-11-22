import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/conversation_page.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/presence.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Sohbet uçları; iki taraf ortak. Sunucu "karşı taraf" ve "ben mi gönderdim"i
/// vermediği için her çağrı [currentUserId] istiyor.
class ChatService {
  ChatService._(this._apiClient);

  static final ChatService _instance = ChatService._(ApiClient());

  factory ChatService() => _instance;

  @visibleForTesting
  factory ChatService.withClient(ApiClient apiClient) {
    return ChatService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<ConversationPage> fetchConversations({
    required String currentUserId,
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<ConversationPage>(
      ApiPaths.conversations,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => ConversationPage.fromJson(
        data! as Map<String, dynamic>,
        currentUserId: currentUserId,
      ),
    );
  }

  /// Bildirimden açarken; taraf olmayan ve olmayan sohbet aynı `404`.
  Future<Conversation> fetchConversation({
    required String conversationId,
    required String currentUserId,
  }) {
    return _apiClient.get<Conversation>(
      ApiPaths.conversation(conversationId),
      parse: (data) => Conversation.fromJson(
        data! as Map<String, dynamic>,
        currentUserId: currentUserId,
      ),
    );
  }

  /// Mesajlar (sayfa 30). [after] verilirse yalnız sonrakiler (artımlı
  /// tamamlama); `sort` hiç gönderilmiyor. Çapa bilinmiyorsa `400
  /// MESSAGING_AFTER_UNKNOWN`.
  Future<MessagePage> fetchMessages({
    required String conversationId,
    required String currentUserId,
    int page = 0,
    int size = 30,
    String? after,
  }) {
    return _apiClient.get<MessagePage>(
      ApiPaths.conversationMessages(conversationId),
      queryParameters: {'page': page, 'size': size, 'after': ?after},
      parse: (data) => MessagePage.fromJson(
        data! as Map<String, dynamic>,
        conversationId: conversationId,
        currentUserId: currentUserId,
      ),
    );
  }

  /// En fazla 4000 karakter; boş gövde reddedilir.
  Future<Message> sendMessage({
    required String conversationId,
    required String currentUserId,
    required String body,
  }) {
    return _apiClient.post<Message>(
      ApiPaths.conversationMessages(conversationId),
      body: {'body': body},
      parse: (data) => Message.fromJson(
        data! as Map<String, dynamic>,
        conversationId: conversationId,
        currentUserId: currentUserId,
      ),
    );
  }

  Future<void> markRead(String conversationId) {
    return _apiClient.postWithoutData(
      ApiPaths.conversationRead(conversationId),
    );
  }

  /// Varsa mevcut sohbeti döndürür. [workerId] yalnız işveren için.
  Future<Conversation> openConversationForJob({
    required String jobId,
    required String currentUserId,
    String? workerId,
  }) {
    return _apiClient.post<Conversation>(
      ApiPaths.jobConversation(jobId),
      queryParameters: {'workerId': ?workerId},
      parse: (data) => Conversation.fromJson(
        data! as Map<String, dynamic>,
        currentUserId: currentUserId,
      ),
    );
  }

  /// Toplu uç; boş listede ağa çıkmaz.
  Future<Map<String, Presence>> fetchPresence(List<String> userIds) async {
    if (userIds.isEmpty) return const {};

    final list = await _apiClient.post<List<Presence>>(
      ApiPaths.presenceLookup,
      body: userIds,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(Presence.fromJson)
                .toList()
          : const [],
    );

    return {for (final presence in list) presence.userId: presence};
  }
}
