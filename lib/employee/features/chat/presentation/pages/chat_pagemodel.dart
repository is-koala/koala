part of 'chat_page.dart';

abstract class ChatPagemodel extends ChatThreadPagemodel<ChatPage> {
  @override
  Conversation get chat => widget.chat;

  @override
  ChatThreadController? get providedThreadController => widget.threadController;

  @override
  bool get asEmployer => false;
}
