import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';
import 'package:koala/employee/features/profile/models/public_profile_args.dart';
import 'package:koala/product/router/employee_routes.dart';

import '../../../../../support/chat_page_group_harness.dart';

void main() {
  registerChatPageGroupTests(
    role: 'Çalışan sohbeti',
    currentUserId: 'worker_me',
    isEmployer: false,
    buildPage: (chat, thread) => ChatPage(chat: chat, threadController: thread),
    // Çalışan kabuğu başkasının profilini kendi rotasında, sohbetin bildiği
    // ad ve rolle açıyor (is-koala/koala#182).
    profileRoute: EmployeeRoutes.publicProfilePattern,
    profileLocation: EmployeeRoutes.publicProfile('user_other'),
    profileExtra: isA<PublicProfileArgs>()
        .having((args) => args.userId, 'userId', 'user_other')
        .having((args) => args.name, 'name', 'Ayşe Yılmaz')
        .having((args) => args.role, 'role', ChatParticipantRole.worker)
        // Şirket satırı için sohbetin ilanı da gidiyor.
        .having((args) => args.jobId, 'jobId', 'job_1'),
  );
}
