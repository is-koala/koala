import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:koala/product/widgets/report_sheet.dart';
import 'package:provider/provider.dart';

/// Bir iş satırı üzerinde yapılabilen eylemlerin ortak gövdesi.
///
/// Kabul/ret, mesai giriş-çıkışı, iptal, sorun bildirme, başvuruyu geri
/// çekme ve işverenle sohbet — hepsi bir zamanlar yalnızca "İşlerim"
/// sayfasının `Pagemodel`'indeydi. İş detayı sayfası aynı eylemleri aynı
/// kurallarla sunuyor (is-koala/koala#177); akışları kopyalamak iki yerde
/// ayrışan iki `409` davranışı demek olurdu. Bu yüzden iki sayfanın
/// `Pagemodel`'i de bu tabandan türüyor: sayfa yalnızca servislerini ve
/// eylem sonrası nasıl tazeleneceğini söylüyor.
///
/// Her eylem aynı iskeleti izliyor: ilgili kimliği kilitle, isteği at,
/// sonucu `AppToast` ile söyle, [refreshWork] ile ekranı tazele; `409` gibi
/// "sunucudaki durum değişmiş" hatalarında da tazele, çünkü elde tutulan
/// kayıt bayat demektir.
abstract class WorkActionsPagemodel<T extends StatefulWidget> extends State<T> {
  /// Uyarı metninin satır aralığı; çok satırlı gövde sıkışık duruyordu.
  static const double _dialogLineHeight = 1.4;

  AssignmentService get assignmentService;
  ChatService get chatService;

  /// Bir eylem tamamlandıktan sonra ekranın kendi verisini yeniden çeker.
  ///
  /// "İşlerim" bütün listeyi, iş detayı tek atamayı tazeliyor; eylemler
  /// hangisi olduğunu bilmiyor.
  Future<void> refreshWork();

  /// Mesai isteği sunucuya gitmiş atamanın id'si; butonu kilitliyor.
  String? timesheetBusyAssignmentId;

  /// İptal ya da uyuşmazlık isteği sunucuya gitmiş atamanın id'si.
  String? assignmentActionId;

  /// Cevabı sunucuya gitmiş atamanın id'si; iki butonu da kilitliyor.
  ///
  /// Tek bir alan yetiyor çünkü kullanıcı aynı anda tek bir atamaya cevap
  /// veriyor ve cevap dönene kadar liste tazelenmiyor.
  String? respondingAssignmentId;

  /// İlan sohbeti açılırken ikinci navigasyonu engeller.
  String? openingChatJobId;

  TimesheetQueueProvider? _timesheetQueue;
  int _timesheetDeliveryRevision = 0;

  /// Çevrimdışı mesai kuyruğuna bağlanır ve oturum sahibi için başlatır.
  ///
  /// `initState` içinden, ilk kare çizildikten sonra çağrılır; provider'lar
  /// o zaman okunabiliyor. Kuyruk bir kaydı teslim ettiğinde
  /// [announceTimesheetDelivery] üzerinden haber veriyor.
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

  /// Kuyruk dinleyicisini bırakır; `dispose` içinden çağrılır.
  void disposeTimesheetQueue() {
    _timesheetQueue?.removeListener(_onTimesheetQueueChanged);
    _timesheetQueue = null;
  }

  void _onTimesheetQueueChanged() {
    final queue = _timesheetQueue;
    if (!mounted || queue == null) return;
    announceTimesheetDelivery(queue);
  }

  /// Kuyruk bir mesai kaydını teslim ettiyse bir kez söyler ve tazeler.
  void announceTimesheetDelivery(TimesheetQueueProvider queue) {
    if (!mounted) return;
    if (queue.deliveryRevision == _timesheetDeliveryRevision) return;
    _timesheetDeliveryRevision = queue.deliveryRevision;
    if (queue.takeDeliveryAcknowledgement() == null) return;
    AppToast.success(context, 'Mesai kaydı gönderildi.');
    unawaited(refreshWork());
  }

  /// Başvurunun veya atamanın bağlı olduğu ilan üzerinden işverenle konuşur.
  ///
  /// Sunucu kapıyı kapattıysa (`403 MESSAGING_PAYMENT_REQUIRED`,
  /// `409 MESSAGING_WINDOW_CLOSED`) düğmenin yerine yazılan metnin aynısı
  /// gösteriliyor ve liste yeniden çekiliyor: düğme görünüyorsa elimizdeki
  /// atama bayat demek — ödeme iade edilmiş ya da iş iptal olmuş olabilir.
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

  /// Başvuruyu geri çeker.
  ///
  /// Gerekçe sorulmuyor — sunucu istemiyor ve kullanıcıdan kendi başvurusunu
  /// geri çekmek için açıklama beklemek gereksiz — o yüzden [ReasonDialog]
  /// değil [ConfirmDialog].
  ///
  /// İstek [ApplyProvider] üzerinden gidiyor: liste o provider'da duruyor ve
  /// geri çekilen satır orada güncelleniyor, atamalar yeniden çekilmiyor.
  /// Başarılıysa `true` döner.
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

    // `409` alındıysa provider listeyi zaten tazeledi; burada yalnızca
    // sunucunun Türkçe mesajı gösteriliyor.
    AppToast.error(context, provider.errorMessage ?? 'Başvuru geri çekilemedi');
    return false;
  }

  /// Atamayı iptal eder.
  ///
  /// Kutu açılmadan önce kesinti önizlemesi çekiliyor: çalışanın iptalinde
  /// kesinti çıkmıyor ama bunu kullanıcıya **tahmin ettirmek** yerine
  /// sunucuya sormak doğrusu — oranlar sunucu ayarından geliyor ve
  /// değişebilir.
  ///
  /// Önizleme alınamazsa akış durmuyor: kutu kuralı kelimeyle anlatıyor.
  /// Kesintiyi öğrenememek iptal hakkını kaldırmamalı.
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

    // Sunucu iptale kapalı atamada hata yerine bu bayrağı döndürüyor.
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

  /// İptal kutusunun gövdesi.
  ///
  /// Önizleme geldiyse tutar yazılıyor, gelmediyse kural. Her iki durumda da
  /// tutarın bağlayıcı olmadığı söyleniyor: kesinti işin başlamasına kalan
  /// süreye bağlı ve sunucu iptal anında yeniden hesaplıyor.
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

  /// Uyuşmazlık açar.
  ///
  /// Yalnızca para emanetteyken açılabiliyor. Açık uyuşmazlık emanetteki
  /// parayı donduruyor: ödeme durur, sunucunun kendiliğinden tamamlaması da
  /// durur. Yani kullanıcıya "ödemen hızlanır" diye sunulacak bir şey değil.
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

    await _runAssignmentAction(
      job,
      action: (id) async {
        await assignmentService.openDispute(assignmentId: id, reason: reason);
        return 'Sorun bildirildi, Koala inceleyecek';
      },
    );
  }

  /// İptal ve uyuşmazlığın ortak gövdesi: kilit, hata ve tazeleme.
  Future<void> _runAssignmentAction(
    MyJob job, {
    required Future<String> Function(String assignmentId) action,
  }) async {
    final assignmentId = job.assignmentId;
    if (assignmentId == null || assignmentActionId != null) return;

    setState(() => assignmentActionId = assignmentId);

    try {
      final message = await action(assignmentId);
      if (!mounted) return;
      AppToast.success(context, message);
      await refreshWork();
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      // 409: durum sunucuda değişmiş — iş zaten iptal edilmiş ya da emanette
      // para kalmamış olabilir. Doğrusunu göstermek için tazeleniyor.
      if (error.type.serverStateMoved) await refreshWork();
    } finally {
      if (mounted) setState(() => assignmentActionId = null);
    }
  }

  /// Mesaiye başlar.
  ///
  /// Konum isteğe bağlı; alınamazsa giriş yine yapılıyor. Konumun yokluğu
  /// yüzünden çalışanın mesaisi başlamamazlık edemez.
  Future<void> checkIn(MyJob job) => _runTimesheetAction(
    job,
    action: (queue, id, position) => queue.recordCheckIn(
      assignmentId: id,
      latitude: position?.latitude,
      longitude: position?.longitude,
    ),
  );

  /// Açık mesai oturumunu kapatır.
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
          // Listener normalde ACK sırasında bildirir; sayfa kuyruğa henüz
          // bağlanmadıysa aynı tek-tüketim yolunu burada tamamla.
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

  /// Cihazın konumu; alınamazsa `null`.
  ///
  /// Sunucu konumsuz mesai kaydını kabul ediyor, o yüzden izin reddi ya da
  /// GPS hatası burada yutuluyor — akışı durduracak bir şey değil.
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
      // 409: atama bu durumdan çıkmış — başka bir cihazdan cevaplanmış ya da
      // işveren iptal etmiş olabilir. Mesaj sunucudan Türkçe geliyor, ama
      // liste eskimiş demektir; yenilemek doğru olanı gösteriyor.
      AppToast.error(context, error.message);
      if (error.type.serverStateMoved) await refreshWork();
    } finally {
      if (mounted) setState(() => respondingAssignmentId = null);
    }
  }

  /// Reddetme geri alınamıyor: atama kapanıyor ve iş başkasına gidiyor.
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
