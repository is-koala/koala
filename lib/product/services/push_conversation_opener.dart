import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Bir kabuğun sohbet rotaları: liste ve tek sohbet.
///
/// İki kabuk aynı `ChatPage`/`BChatPage` sözleşmesini kullanıyor (`extra`
/// olarak [Conversation]); yalnız yol adları farklı.
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

/// `type=MESSAGE` push'una dokunulunca gidilecek yeri bulur.
///
/// Bildirim yalnız `conversationId` taşıyor, sohbet ekranı ise `extra`
/// olarak tam bir [Conversation] istiyor; tek sohbet
/// `GET /conversations/{id}` ile okunur ve sohbet ekranı açılır. Sohbet
/// bulunamazsa (`404` — silinmiş ya da artık taraf değilsiniz), oturum
/// sahibi okunamazsa ya da istek düşerse sohbet **listesi** açılır: dokunan
/// kullanıcı bir yere varmalı, boş bir ekran ya da hiçbir şey olmaması
/// bozuk okunur.
class PushConversationOpener {
  PushConversationOpener({
    required this.currentUserId,
    required this.routes,
    required this.navigate,
    ChatService? chatService,
  }) : _chatService = chatService ?? ChatService();

  /// Oturum sahibinin kimliği; [Conversation.fromJson] karşı tarafı buna
  /// göre seçiyor. Okunamazsa `null`.
  final Future<String?> Function() currentUserId;

  /// Oturumun kabuğuna göre rota çifti.
  final ChatRoutes Function() routes;

  /// [conversation] doluysa liste üstüne sohbet ekranı, boşsa yalnız liste.
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

/// Sohbet listesine gider; sohbet varsa üstüne sohbet ekranını iter.
///
/// Önce liste: sohbetten geri çıkınca kullanıcı listeye düşmeli, boş bir
/// yığına değil. `push` bir sonraki kareye bırakılıyor ki `go`'nun rota
/// çözümü tamamlanmış olsun ve `push` yeni yığını taban alsın; iki kabuk da
/// aynı `extra` sözleşmesini kullanıyor ([Conversation]).
/// `PushMessaging` bunu uygulamanın router'ıyla çağırıyor; testler kendi
/// küçük router'larıyla.
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
