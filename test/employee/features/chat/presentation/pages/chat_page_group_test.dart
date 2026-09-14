import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';

import '../../../../../support/chat_page_group_harness.dart';

void main() {
  registerChatPageGroupTests(
    role: 'Çalışan sohbeti',
    currentUserId: 'worker_me',
    isEmployer: false,
    buildPage: (chat, thread) => ChatPage(chat: chat, threadController: thread),
  );
}
