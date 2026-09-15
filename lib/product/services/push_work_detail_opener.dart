import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// `type=TRANSPORT` push'una dokunulunca gidilecek yeri bulur
/// (is-koala/koala#197).
///
/// Bildirim `jobAssignmentId` taşıyor, iş detayı ise `extra` olarak bir
/// [MyJob] istiyor; atama `GET /job-assignments/{id}` ile okunuyor ve
/// `/work-detail` [WorkDetailArgs] ile açılıyor (`SEAT_DROPPED` olayı
/// `seatDropped` bağlamıyla). Atama okunamazsa (`404`, ağ) yalnız İşlerim
/// listesi açılıyor: dokunan kullanıcı bir yere varmalı.
///
/// Ulaşım push'u yalnız işçiye gider (`TransportManager.notifyWorker`);
/// işveren oturumunda `PushMessaging` bu açıcıyı hiç çağırmaz, bildirim
/// ekranına düşer.
class PushWorkDetailOpener {
  PushWorkDetailOpener({
    required this.navigate,
    AssignmentService? assignmentService,
  }) : _assignmentService = assignmentService ?? AssignmentService();

  /// İşlerim listesinin yolu.
  static const String jobsRoute = '/jobs';

  /// İş detayının yolu; `extra` [WorkDetailArgs].
  static const String detailRoute = '/work-detail';

  /// [args] doluysa liste üstüne iş detayı, boşsa yalnız liste.
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

/// İşlerim'e gider; kayıt varsa üstüne iş detayını iter.
///
/// `openChatOn` ile aynı gerekçe: önce liste ki geri çıkınca kullanıcı
/// listeye düşsün; `push` bir sonraki kareye bırakılıyor ki `go`'nun rota
/// çözümü tamamlanmış olsun.
void openWorkDetailOn(GoRouter router, WorkDetailArgs? args) {
  router.go(PushWorkDetailOpener.jobsRoute);
  if (args == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    router.push(PushWorkDetailOpener.detailRoute, extra: args);
  });
}
