import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/conversation_page.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/presence.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Sohbet uçları.
///
/// İki arayüz de bunu kullanıyor: `GET /conversations` oturumu açan kullanıcının
/// sohbetlerini döndürüyor, kullanıcının işveren mi çalışan mı olduğuna
/// bakmıyor.
///
/// Her çağrı [currentUserId] istiyor çünkü sunucu "karşı taraf" ve "bu mesajı
/// ben mi gönderdim" bilgisini vermiyor; ikisi de iki katılımcıdan hangisinin
/// oturum sahibi olduğuna bakılarak türetiliyor.
class ChatService {
  ChatService._(this._apiClient);

  static final ChatService _instance = ChatService._(ApiClient());

  factory ChatService() => _instance;

  @visibleForTesting
  factory ChatService.withClient(ApiClient apiClient) {
    return ChatService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Kullanıcının sohbetleri, son mesaja göre.
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

  /// Bir sohbetin mesajları.
  ///
  /// Sunucunun varsayılan sayfa boyutu 30; aynı değer burada da varsayılan.
  Future<MessagePage> fetchMessages({
    required String conversationId,
    required String currentUserId,
    int page = 0,
    int size = 30,
  }) {
    return _apiClient.get<MessagePage>(
      ApiPaths.conversationMessages(conversationId),
      queryParameters: {'page': page, 'size': size},
      parse: (data) => MessagePage.fromJson(
        data! as Map<String, dynamic>,
        conversationId: conversationId,
        currentUserId: currentUserId,
      ),
    );
  }

  /// Mesaj gönderir. Sunucu en fazla 4000 karakter kabul ediyor ve boş
  /// gövdeyi reddediyor.
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

  /// Sohbeti okundu işaretler; okunmamış sayacını sıfırlıyor.
  Future<void> markRead(String conversationId) {
    return _apiClient.postWithoutData(
      ApiPaths.conversationRead(conversationId),
    );
  }

  /// Bir ilan üzerinden sohbet açar; zaten varsa mevcut sohbeti döndürüyor.
  ///
  /// [workerId] yalnızca işveren tarafı için: hangi başvuranla konuşulacağını
  /// belirtiyor. Çalışan tarafı geçmiyor, karşı taraf zaten ilan sahibi.
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

  /// Birden çok kullanıcının çevrimiçi durumu, tek istekte.
  ///
  /// Sohbet listesi satır başına ayrı istek atmasın diye toplu uç kullanılıyor.
  /// Boş liste ile çağrılırsa ağa hiç çıkmıyor.
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
