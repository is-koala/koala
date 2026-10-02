import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_page.dart';
import 'package:koala/product/router/business_routes.dart';

import '../../../../../support/chat_page_group_harness.dart';

void main() {
  registerChatPageGroupTests(
    role: 'İşveren sohbeti',
    currentUserId: 'employer_me',
    isEmployer: true,
    buildPage: (chat, thread) =>
        BChatPage(chat: chat, threadController: thread),
    // İşveren kabuğu aday sayfasını açıyor; o sayfa kimliği yeterli buluyor.
    profileRoute: BusinessRoutes.userProfile,
    profileExtra: equals('user_other'),
  );
}
