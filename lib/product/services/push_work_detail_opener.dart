import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// `type=TRANSPORT` push'una dokunulunca iş detayını açar (#197). Atama `GET
/// /job-assignments/{id}` ile okunuyor; okunamazsa yalnız İşlerim açılır.
/// İşveren oturumunda hiç çağrılmaz.
class PushWorkDetailOpener {
  PushWorkDetailOpener({
    required this.navigate,
    AssignmentService? assignmentService,
  }) : _assignmentService = assignmentService ?? AssignmentService();

  static const String jobsRoute = '/jobs';

  static const String detailRoute = '/work-detail';

  final void Function(WorkDetailArgs? args) navigate;

  final AssignmentService _assignmentService;

  Future<void> open({
    required String assignmentId,
    required bool seatDropped,
  }) async {
    try {
      final assignment = await _assignmentService.fetchAssignment(assignmentId);
      navigate(
        WorkDetailArgs(
          job: MyJob.fromAssignment(assignment),
          seatDropped: seatDropped,
        ),
      );
    } on ApiException catch (error) {
      debugPrint('Ulaşım push\'ı: atama açılamadı, İşlerim açılıyor: $error');
      navigate(null);
    }
  }
}

/// Önce İşlerim'e `go`, sonraki karede detay `push`; geri çıkınca liste.
void openWorkDetailOn(GoRouter router, WorkDetailArgs? args) {
  router.go(PushWorkDetailOpener.jobsRoute);
  if (args == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    router.push(PushWorkDetailOpener.detailRoute, extra: args);
  });
}
