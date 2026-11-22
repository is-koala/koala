import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/dispute/dispute_routes.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:koala/product/widgets/report_sheet.dart';
import 'package:provider/provider.dart';

/// İş satırındaki eylemlerin ortak gövdesi; İşlerim ve iş detayı aynı
/// kurallarla sunsun diye (#177). İskelet: kimliği kilitle, isteği at, sonucu
/// toast'la söyle, [refreshWork] ile tazele; `409`'da da tazele, kayıt
/// bayattır.
abstract class WorkActionsPagemodel<T extends StatefulWidget> extends State<T> {
  static const double _dialogLineHeight = 1.4;

  AssignmentService get assignmentService;
  ChatService get chatService;

  /// İşlerim bütün listeyi, iş detayı tek atamayı tazeliyor.
  Future<void> refreshWork();

  String? timesheetBusyAssignmentId;

  String? assignmentActionId;

  /// Kullanıcı aynı anda tek atamaya cevap veriyor; tek alan yeter.
  String? respondingAssignmentId;

  String? openingChatJobId;

  TimesheetQueueProvider? _timesheetQueue;
  int _timesheetDeliveryRevision = 0;

  /// Çevrimdışı mesai kuyruğuna bağlanır; ilk kareden sonra çağrılır.
  Future<void> initializeTimesheetQueue() async {
    try {
      final queue = context.read<TimesheetQueueProvider>();
      _timesheetQueue = queue;
      queue.addListener(_onTimesheetQueueChanged);
      announceTimesheetDelivery(queue);

      final userProvider = context.read<UserProvider>();
      if (userProvider.user == null) await userProvider.load(silent: true);
      if (!mounted) return;
      final userId = userProvider.user?.id;
      if (userId != null && queue.activeUserId != userId) {
        final started = await queue.tryStartForUser(userId);
        if (!started && mounted) {
          AppToast.error(context, 'Mesai kuyruğu başlatılamadı.');
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Mesai kuyruğu başlatılamadı.');
      }
    }
  }

  void disposeTimesheetQueue() {
    _timesheetQueue?.removeListener(_onTimesheetQueueChanged);
    _timesheetQueue = null;
  }

  void _onTimesheetQueueChanged() {
    final queue = _timesheetQueue;
    if (!mounted || queue == null) return;
    announceTimesheetDelivery(queue);
  }

  void announceTimesheetDelivery(TimesheetQueueProvider queue) {
    if (!mounted) return;
    if (queue.deliveryRevision == _timesheetDeliveryRevision) return;
    _timesheetDeliveryRevision = queue.deliveryRevision;
    if (queue.takeDeliveryAcknowledgement() == null) return;
    AppToast.success(context, 'Mesai kaydı gönderildi.');
    unawaited(refreshWork());
  }

  /// İlan üzerinden işverenle konuşur. Kapı kapalıysa aynı açıklama gösterilir
  /// ve liste yeniden çekilir: düğme görünüyorsa atama bayattır.
  Future<void> openChat(MyJob job) async {
    final jobId = job.jobId;
    final currentUser = context.read<UserProvider>().user;
    if (jobId == null || currentUser == null || openingChatJobId != null) {
      return;
    }

    setState(() => openingChatJobId = jobId);
    try {
      final conversation = await chatService.openConversationForJob(
        jobId: jobId,
        currentUserId: currentUser.id,
      );
      if (!mounted) return;
      await context.push('/chat-detail', extra: conversation);
    } on ApiException catch (error) {
      if (!mounted) return;
      final gate = MessagingAvailability.fromErrorCode(error.errorCode);
      if (gate == null) {
        AppToast.error(context, error.message);
        return;
      }
      AppToast.error(context, gate.noteFor(asEmployer: false) ?? error.message);
      await refreshWork();
    } finally {
      if (mounted) setState(() => openingChatJobId = null);
    }
  }

  /// Geri çeker; sunucu gerekçe istemiyor, o yüzden [ConfirmDialog]. Liste
  /// [ApplyProvider]'da güncellenir.
  Future<bool> withdrawApplication(MyJob job) async {
    final provider = context.read<ApplyProvider>();
    if (provider.withdrawingId != null) return false;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Başvurunuzu geri çekin',
      message:
          '"${job.title}" ilanına yaptığınız başvuru geri çekilecek ve '
          'işveren artık yanıtlayamayacak. İlan hâlâ açıksa yeniden '
          'başvurabilirsiniz.',
      actionLabel: 'Geri Çek',
    );

    if (confirmed != true || !mounted) return false;

    final withdrawn = await provider.withdraw(job.id);
    if (!mounted) return withdrawn;

    if (withdrawn) {
      AppToast.success(context, 'Başvurunuz geri çekildi');
      return true;
    }

    // `409`'da provider listeyi zaten tazeledi.
    AppToast.error(context, provider.errorMessage ?? 'Başvuru geri çekilemedi');
    return false;
  }

  /// İptal eder. Kesinti tahmin ettirilmiyor, sunucuya soruluyor; önizleme
  /// alınamazsa kutu kuralı kelimeyle anlatır, iptal hakkı kalkmaz.
  Future<void> cancelAssignment(MyJob job) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || assignmentActionId != null) return;

    setState(() => assignmentActionId = assignmentId);
    CancellationPreview? preview;
    try {
      preview = await assignmentService.fetchCancellationPreview(assignmentId);
    } on ApiException {
      preview = null;
    } finally {
      if (mounted) setState(() => assignmentActionId = null);
    }

    if (!mounted) return;

    if (preview != null && !preview.cancellableNow) {
      AppToast.error(context, 'Bu iş artık iptal edilemez');
      await refreshWork();
      return;
    }

    final reason = await ReasonDialog.show(
      context,
      title: 'İşi iptal et',
      description: _cancellationDescription(job, preview),
      fieldLabel: 'İptal gerekçeniz',
      confirmLabel: 'İptal Et',
    );

    if (reason == null || !mounted) return;

    await _runAssignmentAction(
      job,
      action: (id) async {
        final cancellation = await assignmentService.cancel(
          assignmentId: id,
          reason: reason,
        );
        return cancellation.hasFee
            ? 'İş iptal edildi · %${cancellation.feePercent} kesinti uygulandı'
            : 'İş iptal edildi';
      },
    );
  }

  /// Önizleme geldiyse tutar, gelmediyse kural; her durumda tutarın bağlayıcı
  /// olmadığı söylenir.
  String _cancellationDescription(MyJob job, CancellationPreview? preview) {
    final opening =
        '"${job.title}" işi iptal edilecek ve geri alınamayacak. '
        'Sık iptal profilinizi etkileyebilir.';

    if (preview == null) {
      return '$opening\n\nSizin iptalinizde kesinti uygulanmıyor, ücret '
          'işverene iade ediliyor.';
    }

    if (!preview.hasFee) {
      return '$opening\n\nBu iptalde sizden kesinti yapılmayacak.';
    }

    return '$opening\n\nBu iptalde %${preview.feePercent} kesinti '
        'uygulanacak (${TurkishMoneyFormatter.format(preview.feeAmount, 'TRY')}). Tutar iptal '
        'anında yeniden hesaplanır.';
  }

  /// Uyuşmazlık açar; yalnız para emanetteyken. Ödemeyi ve otomatik tamamlamayı
  /// dondurur, "ödemen hızlanır" diye sunulmamalı.
  Future<void> openDispute(MyJob job) async {
    final reason = await ReasonDialog.show(
      context,
      title: 'Sorun bildir',
      description:
          '"${job.title}" işiyle ilgili bir sorun bildireceksiniz. '
          'Emanetteki ücret, Koala konuyu inceleyip sonuçlandırana kadar '
          'dondurulur — yani ödeme hızlanmaz, durur.',
      fieldLabel: 'Yaşadığınız sorun',
      confirmLabel: 'Bildir',
      isDestructive: false,
    );

    if (reason == null || !mounted) return;

    final opened = await _runAssignmentAction(
      job,
      action: (id) async {
        await assignmentService.openDispute(assignmentId: id, reason: reason);
        return 'Sorun bildirildi, Koala inceleyecek';
      },
    );

    // Açılınca doğrudan kanıt ekleme (#215); kapanınca satır yeniden okunur.
    final assignmentId = job.assignmentId;
    if (opened && assignmentId != null && mounted) {
      await context.push(DisputeRoutes.location(assignmentId));
      if (mounted) await refreshWork();
    }
  }

  /// İptal ve uyuşmazlığın ortak gövdesi; başarılıysa `true`.
  Future<bool> _runAssignmentAction(
    MyJob job, {
    required Future<String> Function(String assignmentId) action,
  }) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || assignmentActionId != null) return false;

    setState(() => assignmentActionId = assignmentId);

    try {
      final message = await action(assignmentId);
      if (!mounted) return true;
      AppToast.success(context, message);
      await refreshWork();
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      AppToast.error(context, error.message);
      // Durum sunucuda değişmiş; doğrusu için tazelenir.
      if (error.type.serverStateMoved) await refreshWork();
      return false;
    } finally {
      if (mounted) setState(() => assignmentActionId = null);
    }
  }

  /// Konum alınamazsa giriş yine yapılır.
  Future<void> checkIn(MyJob job) => _runTimesheetAction(
    job,
    action: (queue, id, position) => queue.recordCheckIn(
      assignmentId: id,
      latitude: position?.latitude,
      longitude: position?.longitude,
    ),
  );

  Future<void> checkOut(MyJob job) => _runTimesheetAction(
    job,
    action: (queue, id, position) => queue.recordCheckOut(
      assignmentId: id,
      latitude: position?.latitude,
      longitude: position?.longitude,
    ),
  );

  Future<void> _runTimesheetAction(
    MyJob job, {
    required Future<TimesheetSubmission> Function(
      TimesheetQueueProvider queue,
      String id,
      Position? position,
    )
    action,
  }) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || timesheetBusyAssignmentId != null) return;

    setState(() => timesheetBusyAssignmentId = assignmentId);

    try {
      final queue = context.read<TimesheetQueueProvider>();
      if (queue.activeUserId == null) {
        final userProvider = context.read<UserProvider>();
        if (userProvider.user == null) await userProvider.load(silent: true);
        final userId = userProvider.user?.id;
        if (userId == null) {
          throw StateError('Oturum sahibi yüklenemedi.');
        }
        await queue.startForUser(userId);
      }

      final result = await action(
        queue,
        assignmentId,
        await _currentPosition(),
      );
      if (!mounted) return;
      switch (result) {
        case TimesheetSubmission.sent:
          // Sayfa kuyruğa henüz bağlanmadıysa teslimat burada bildirilir.
          announceTimesheetDelivery(queue);
        case TimesheetSubmission.pending:
          AppToast.info(context, 'Kaydedildi, gönderilmeyi bekliyor.');
        case TimesheetSubmission.requiresSupport:
          AppToast.error(
            context,
            'Mesai kaydı için destek gerekiyor.',
            actionLabel: 'Destek Al',
            onAction: () => openTimesheetSupport(job),
          );
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Mesai kaydı cihazda saklanamadı. Tekrar deneyin.',
      );
    } finally {
      if (mounted) setState(() => timesheetBusyAssignmentId = null);
    }
  }

  Future<void> openTimesheetSupport(MyJob job) async {
    final jobId = job.jobId;
    if (jobId == null) {
      await context.push('/reports');
      return;
    }
    await ReportSheet.show(
      context,
      ReportTarget.job(jobId: jobId, title: job.title),
    );
  }

  /// Alınamazsa `null`; sunucu konumsuz kaydı kabul ediyor.
  Future<Position?> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> respondToAssignment(MyJob job, {required bool accepted}) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || respondingAssignmentId != null) return;

    setState(() => respondingAssignmentId = assignmentId);

    try {
      await assignmentService.respond(
        assignmentId: assignmentId,
        accepted: accepted,
      );
      if (!mounted) return;
      AppToast.success(
        context,
        accepted ? 'İşi kabul ettiniz' : 'İşi reddettiniz',
      );
      await refreshWork();
    } on ApiException catch (error) {
      if (!mounted) return;
      // Atama başka cihazdan cevaplanmış ya da iptal edilmiş olabilir; liste
      // eskimiş, yenilenir.
      AppToast.error(context, error.message);
      if (error.type.serverStateMoved) await refreshWork();
    } finally {
      if (mounted) setState(() => respondingAssignmentId = null);
    }
  }

  /// Geri alınamaz: atama kapanır, iş başkasına gider.
  Future<void> confirmReject(MyJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text('İşi reddet', style: dialogContext.textTheme.titleMedium),
        content: Text(
          '"${job.title}" işini reddederseniz bu iş size kapanır ve geri '
          'alamazsınız. İşveren başka birini seçebilir.',
          style: dialogContext.textTheme.bodyMedium?.copyWith(
            color: dialogContext.textSecondary,
            height: _dialogLineHeight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await respondToAssignment(job, accepted: false);
  }
}
