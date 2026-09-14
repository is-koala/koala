import 'package:koala/business/features/chat/presentation/pages/b_chat_page.dart';

import '../../../../../support/chat_page_gate_harness.dart';

void main() {
  registerChatPageGateTests(
    role: 'İşveren sohbeti',
    currentUserId: 'employer_me',
    isEmployer: true,
    expectedPaymentNote: 'Ödemeyi tamamlayınca ekip sohbeti açılır.',
    buildPage: (chat, thread) =>
        BChatPage(chat: chat, threadController: thread),
  );
}
