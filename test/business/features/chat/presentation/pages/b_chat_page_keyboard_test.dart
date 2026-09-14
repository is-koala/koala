import 'package:koala/business/features/chat/presentation/pages/b_chat_page.dart';

import '../../../../../support/chat_page_keyboard_harness.dart';

void main() {
  registerChatPageKeyboardTests(
    role: 'İşveren sohbeti',
    currentUserId: 'employer_me',
    isEmployer: true,
    buildPage: (chat, thread) =>
        BChatPage(chat: chat, threadController: thread),
  );
}
