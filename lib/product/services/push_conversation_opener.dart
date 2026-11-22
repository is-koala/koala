import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Bir kabuğun sohbet rotaları; iki kabuk aynı `extra` sözleşmesini
/// ([Conversation]) kullanıyor.
class ChatRoutes {
  const ChatRoutes({required this.list, required this.detail});

  static const ChatRoutes employee = ChatRoutes(
    list: '/chat',
    detail: '/chat-detail',
  );

  static const ChatRoutes business = ChatRoutes(
    list: '/business/chat',
    detail: '/business/chat-detail',
  );

  final String list;
  final String detail;
}

/// `type=MESSAGE` push'una dokunulunca sohbeti açar. Push yalnız
/// `conversationId` taşıdığı için sohbet `GET /conversations/{id}` ile
/// okunuyor; okunamazsa sohbet **listesi** açılır, kullanıcı bir yere varmalı.
class PushConversationOpener {
  PushConversationOpener({
    required this.currentUserId,
    required this.routes,
    required this.navigate,
    ChatService? chatService,
  }) : _chatService = chatService ?? ChatService();

  /// Okunamazsa `null`.
  final Future<String?> Function() currentUserId;

  final ChatRoutes Function() routes;

  final void Function(ChatRoutes routes, Conversation? conversation) navigate;

  final ChatService _chatService;

  Future<void> open(String conversationId) async {
    final target = routes();

    final userId = await currentUserId();
    if (userId == null) {
      debugPrint('Mesaj push\'ı: oturum sahibi okunamadı, liste açılıyor');
      navigate(target, null);
      return;
    }

    try {
      final conversation = await _chatService.fetchConversation(
        conversationId: conversationId,
        currentUserId: userId,
      );
      navigate(target, conversation);
    } on ApiException catch (error) {
      debugPrint('Mesaj push\'ı: sohbet açılamadı, liste açılıyor: $error');
      navigate(target, null);
    }
  }
}

/// Önce listeye `go`, bir sonraki karede sohbeti `push`: geri çıkınca kullanıcı
/// listeye düşsün ve `push` yeni yığını taban alsın.
void openChatOn(
  GoRouter router,
  ChatRoutes routes,
  Conversation? conversation,
) {
  router.go(routes.list);
  if (conversation == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    router.push(routes.detail, extra: conversation);
  });
}
