import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';

import '../../../../../support/chat_page_keyboard_harness.dart';

void main() {
  registerChatPageKeyboardTests(
    role: 'Çalışan sohbeti',
    currentUserId: 'user_me',
    isEmployer: false,
    buildPage: (chat, thread) => ChatPage(chat: chat, threadController: thread),
  );
}
