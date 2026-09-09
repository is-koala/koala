part of 'b_chat_page.dart';

abstract class BChatPagemodel extends ChatThreadPagemodel<BChatPage> {
  @override
  Conversation get chat => widget.chat;

  @override
  ChatThreadController? get providedThreadController => widget.threadController;
}
