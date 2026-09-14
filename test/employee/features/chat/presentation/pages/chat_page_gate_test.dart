import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';

import '../../../../../support/chat_page_gate_harness.dart';

void main() {
  registerChatPageGateTests(
    role: 'Çalışan sohbeti',
    currentUserId: 'user_me',
    isEmployer: false,
    expectedPaymentNote: 'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
    buildPage: (chat, thread) => ChatPage(chat: chat, threadController: thread),
  );
}
