import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';

import '../../../../../support/chat_page_retry_harness.dart';

void main() {
  registerChatPageRetryTests(
    role: 'Çalışan sohbeti',
    currentUserId: 'user_me',
    isEmployer: false,
    buildPage: (chat, thread) => ChatPage(chat: chat, threadController: thread),
  );
}
