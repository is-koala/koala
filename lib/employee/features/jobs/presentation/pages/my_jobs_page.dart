import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/chat/presentation/widgets/messaging_gate_note.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/timesheet_queue_status.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/notification_bell.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:koala/product/widgets/report_sheet.dart';
import 'package:provider/provider.dart';

part 'my_jobs_pagemodel.dart';

/// Atama satırındaki menünün seçenekleri.
enum _AssignmentAction { cancel, dispute }

/// Başvuru satırındaki menünün seçenekleri.
enum _ApplicationAction { withdraw }

class MyJobsPage extends StatefulWidget {
  const MyJobsPage({super.key, this.assignmentService, this.chatService});

  /// Testler için: verilmezse üretimdeki tekil servisler kullanılıyor.
  final AssignmentService? assignmentService;
  final ChatService? chatService;

  @override
  State<MyJobsPage> createState() => _MyJobsPageState();
}

class _MyJobsPageState extends MyJobsPagemodel {
  /// "Değerlendir" butonunun yüksekliği; satır içinde durduğu için sayfa
  /// butonlarından belirgin biçimde alçak.
  static const double _inlineButtonHeight = 36;

  /// Bölüm zeminine göre soluklaştırılmış metinlerin opaklıkları.
  static const double _mutedAlpha = 0.5;
  static const double _dividerAlpha = 0.2;
  static const double _dateAlpha = 0.6;
  static const double _linkAlpha = 0.7;

  /// Buton içindeki bekleme halkasının kalınlığı; varsayılan 4 bu boyutta
  /// dolu bir daire gibi görünüyor.
  static const double _spinnerStroke = 2;

  /// Uyarı metninin satır aralığı; çok satırlı gövde sıkışık duruyordu.
  static const double _dialogLineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final queuedEvents = context.watch<TimesheetQueueProvider>().events;
    if (loading) {
      return Scaffold(
        appBar: MyAppbar(
          title: 'İşlerim',
          showBackButton: false,
          actions: const [NotificationBell(route: '/notifications')],
        ),
        body: queuedEvents.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _queueLoadState(queuedEvents, showLoading: true),
      );
    }

    // Elde hiç iş yokken hata varsa boş liste değil hata gösterilmeli;
    // kullanıcı "hiç işim yok" ile "yüklenemedi"yi ayırt edebilmeli.
    final error = errorMessage;
    if (error != null && allJobs.isEmpty) {
      return Scaffold(
        appBar: MyAppbar(
          title: 'İşlerim',
          showBackButton: false,
          actions: const [NotificationBell(route: '/notifications')],
        ),
        body: _errorState(error, queuedEvents: queuedEvents),
      );
    }

    final appliedJobs = context.watch<ApplyProvider>().appliedJobs;

    final pendingJobs = jobsByStatus(
      MyJobStatus.pending,
      extraJobs: appliedJobs,
    );
    final inProgressJobs = jobsByStatus(
      MyJobStatus.inProgress,
      extraJobs: appliedJobs,
    );
    final awaitingJobs = jobsByStatus(
      MyJobStatus.awaitingApproval,
      extraJobs: appliedJobs,
    );
    final approvedJobs = jobsByStatus(
      MyJobStatus.approved,
      extraJobs: appliedJobs,
    );
    final completedJobs = jobsByStatus(
      MyJobStatus.completed,
      extraJobs: appliedJobs,
    );
    // Geçmiş, kapanmış her işi topluyor: tamamlanan, iptal edilen, reddedilen,
    // geri çekilen ve durumu tanınmayan. Hepsinde yapılacak bir şey kalmadı,
    // ayrı bölümler sayfayı gereksiz uzatırdı.
    //
    // Hangi durumun kapalı sayıldığına tek yerde karar veriliyor:
    // [MyJob.isClosed]. Burası eskiden durumları elle sayıyordu ve derleyici
    // uyarmadığı için yeni bir durum hiçbir bölüme girmeden ekrandan
    // düşebiliyordu. Atamalar önce: ödeme alınan işler listenin başında
    // kalsın, kapanmış başvurular altta.
    final closedJobs = [
      ...allJobs.where((job) => job.isClosed),
      ...appliedJobs.where((job) => job.isClosed),
    ];

    // Bölümlerin hepsi boşsa sayfa yalnızca başlıktan ibaret kalırdı; kullanıcı
    // "yüklenmedi mi" ile "hiç işim yok"u ayırt edemezdi.
    final isEmpty =
        pendingJobs.isEmpty &&
        inProgressJobs.isEmpty &&
        awaitingJobs.isEmpty &&
        approvedJobs.isEmpty &&
        completedJobs.isEmpty &&
        closedJobs.isEmpty;

    if (isEmpty) {
      return Scaffold(
        appBar: MyAppbar(
          title: 'İşlerim',
          showBackButton: false,
          actions: const [NotificationBell(route: '/notifications')],
        ),
        body: queuedEvents.isEmpty
            ? RefreshIndicator(
                onRefresh: reload,
                child: const EmptyState(
                  icon: AppIcons.work,
                  title: 'Henüz bir işin yok',
                  description:
                      'Bir ilana başvurduğunda başvurun ve işlerin burada '
                      'görünecek.',
                ),
              )
            : _queueLoadState(queuedEvents),
      );
    }

    return Scaffold(
      appBar: MyAppbar(
        title: 'İşlerim',
        showBackButton: false,
        actions: const [NotificationBell(route: '/notifications')],
      ),
      body: RefreshIndicator(
        onRefresh: reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: AppPadding.primaryHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Süren iş en üstte: kullanıcı o an oradadır, çıkış butonu
                // en kısa yoldan elinin altında olmalı.
                if (inProgressJobs.isNotEmpty) ...[
                  _inProgressSection(inProgressJobs),
                  const SizedBox(height: AppSizes.spaceLarge),
                ],
                // Sonra cevap bekleyen atamalar: iş onaylanmadan başlamıyor.
                if (awaitingJobs.isNotEmpty) ...[
                  _awaitingSection(awaitingJobs),
                  const SizedBox(height: AppSizes.spaceLarge),
                ],
                // Onaylanmış işler - en üstte ve belirgin
                if (approvedJobs.isNotEmpty) ...[
                  _approvedSection(approvedJobs),
                  const SizedBox(height: AppSizes.spaceLarge),
                ],
                if (completedJobs.isNotEmpty) ...[
                  _completedSection(completedJobs),
                  const SizedBox(height: AppSizes.spaceLarge),
                ],
                if (pendingJobs.isNotEmpty) ...[
                  _pendingSection(pendingJobs),
                  const SizedBox(height: AppSizes.spaceLarge),
                ],
                if (closedJobs.isNotEmpty) _pastJobsSection(closedJobs),
                const SizedBox(height: AppSizes.navBarClearance),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// İşler çekilemediğinde: mesaj ve tekrar deneme.
  Widget _errorState(
    String message, {
    List<TimesheetEvent> queuedEvents = const [],
  }) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (queuedEvents.isNotEmpty) ...[
              TimesheetQueueStatus(
                events: queuedEvents,
                onSupport: () => context.push('/reports'),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(onPressed: reload, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }

  Widget _queueLoadState(
    List<TimesheetEvent> events, {
    bool showLoading = false,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppPadding.primaryAll,
      children: [
        TimesheetQueueStatus(
          events: events,
          onSupport: () => context.push('/reports'),
        ),
        if (showLoading) ...[
          const SizedBox(height: AppSizes.spaceLarge),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  // ------------------------------------------------------------- Bölümler

  Widget _approvedSection(List<MyJob> jobs) {
    // Zemin marka yeşili; üstündeki her şey temadan bağımsız beyaz.
    return _sectionCard(
      background: context.accentColor,
      foreground: AppColors.onAccent,
      header: _sectionHeader(
        icon: Icons.directions_walk_rounded,
        title: 'Gitmeniz Gereken İşler',
        count: jobs.length,
        foreground: AppColors.onAccent,
        chipColor: AppColors.onAccent,
        chipTextColor: context.accentColor,
      ),
      child: _jobList(
        jobs: jobs,
        foreground: AppColors.onAccent,
        itemBuilder: _approvedTile,
      ),
    );
  }

  Widget _inProgressSection(List<MyJob> jobs) {
    return _sectionCard(
      background: context.progressSurface,
      foreground: context.textPrimary,
      header: _sectionHeader(
        icon: Icons.timer_outlined,
        title: 'Devam Eden İş',
        count: jobs.length,
        foreground: context.textPrimary,
        chipColor: AppColors.progress,
        chipTextColor: AppColors.onAccent,
      ),
      child: _jobList(
        jobs: jobs,
        foreground: context.textPrimary,
        itemBuilder: _inProgressTile,
      ),
    );
  }

  Widget _awaitingSection(List<MyJob> jobs) {
    return _sectionCard(
      background: context.awaitingSurface,
      foreground: context.textPrimary,
      header: _sectionHeader(
        icon: Icons.how_to_reg_rounded,
        title: 'Onayını Bekleyen İşler',
        count: jobs.length,
        foreground: context.textPrimary,
        chipColor: AppColors.info,
        chipTextColor: AppColors.onAccent,
      ),
      child: _jobList(
        jobs: jobs,
        foreground: context.textPrimary,
        itemBuilder: _awaitingTile,
      ),
    );
  }

  Widget _pendingSection(List<MyJob> jobs) {
    return _sectionCard(
      background: context.pendingSurface,
      foreground: context.textPrimary,
      header: _sectionHeader(
        icon: Icons.hourglass_top_rounded,
        title: 'Başvurularım',
        count: jobs.length,
        foreground: context.textPrimary,
        chipColor: AppColors.pending,
        chipTextColor: AppColors.onAccent,
      ),
      child: _jobList(
        jobs: jobs,
        foreground: context.textPrimary,
        itemBuilder: (job) => _jobTile(
          job,
          context.textPrimary,
          menu: _applicationMenu(job, context.textPrimary),
        ),
      ),
    );
  }

  Widget _completedSection(List<MyJob> jobs) {
    final reviewProvider = context.watch<ReviewProvider>();

    return _sectionCard(
      background: context.payoutSurface,
      foreground: context.textPrimary,
      header: _sectionHeader(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Ödeme Bekleniyor',
        count: jobs.length,
        foreground: context.textPrimary,
        chipColor: AppColors.warning,
        chipTextColor: AppColors.onAccent,
      ),
      child: _jobList(
        jobs: jobs,
        foreground: context.textPrimary,
        itemBuilder: (job) => _completedTile(
          job,
          alreadyReviewed: reviewProvider.hasReviewed(job.assignmentId),
        ),
      ),
    );
  }

  Widget _pastJobsSection(List<MyJob> pastJobs) {
    final visibleCount = showAllPastJobs
        ? pastJobs.length
        : MyJobsPagemodel.collapsedPastJobCount;
    final hiddenCount = pastJobs.length - MyJobsPagemodel.collapsedPastJobCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(
          icon: Icons.history_rounded,
          title: 'Geçmiş',
          count: pastJobs.length,
          foreground: context.textPrimary,
          chipColor: context.textTertiary,
          chipTextColor: AppColors.onAccent,
        ),
        const SizedBox(height: AppSizes.space),
        _jobList(
          jobs: pastJobs.take(visibleCount).toList(),
          foreground: context.textPrimary,
          itemBuilder: _pastJobTile,
        ),
        if (hiddenCount > 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSizes.spaceSmall),
              child: TextButton.icon(
                onPressed: togglePastJobs,
                icon: Icon(
                  showAllPastJobs
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: context.accentColor,
                ),
                label: Text(
                  showAllPastJobs
                      ? "Daha az göster"
                      : "Daha fazla göster ($hiddenCount daha)",
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------- Ortak parçalar

  Widget _sectionCard({
    required Color background,
    required Color foreground,
    required Widget header,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        borderRadius: AppRadius.secondaryCircular,
        color: background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: AppSizes.space),
          child,
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color foreground,
    required Color chipColor,
    required Color chipTextColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: foreground, size: AppSizes.icon),
        const SizedBox(width: AppSizes.spaceSmall),
        Text(
          title,
          style: context.textTheme.titleLarge?.copyWith(color: foreground),
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceSmall,
            vertical: AppSizes.smallGap,
          ),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: AppRadius.innerCircular,
          ),
          child: Text(
            '$count',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: chipTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _jobList({
    required List<MyJob> jobs,
    required Color foreground,
    required Widget Function(MyJob job) itemBuilder,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: AppPadding.zero,
      itemCount: jobs.length,
      separatorBuilder: (context, index) => Divider(
        color: foreground.withValues(alpha: _dividerAlpha),
        thickness: 1,
        height: 1,
      ),
      itemBuilder: (context, index) => itemBuilder(jobs[index]),
    );
  }

  /// Şirket adı; şirket kaydı varsa detaya gider ve altı çizilir.
  Widget _tappableCompanyName(MyJob job, Color foreground) {
    final hasTapAction = job.companyId != null;
    // Yeşil zeminde bağlantı beyaz, açık zeminde marka yeşili.
    final linkColor = foreground == AppColors.onAccent
        ? AppColors.onAccent
        : context.accentColor;

    return GestureDetector(
      onTap: hasTapAction ? () => navigateToCompany(job) : null,
      child: Text(
        job.company,
        style: context.textTheme.bodySmall?.copyWith(
          color: hasTapAction
              ? linkColor
              : foreground.withValues(alpha: _linkAlpha),
          fontWeight: hasTapAction ? FontWeight.w600 : FontWeight.w400,
          decoration: hasTapAction
              ? TextDecoration.underline
              : TextDecoration.none,
          decorationColor: hasTapAction ? linkColor : null,
        ),
      ),
    );
  }

  Widget _tileTitle(String title, Color foreground) => Text(
    title,
    style: context.textTheme.titleSmall?.copyWith(color: foreground),
  );

  Widget _tileSubtitle(MyJob job, Color foreground, {int? maxLines}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tappableCompanyName(job, foreground),
        const SizedBox(height: AppSizes.smallGap),
        Text(
          job.subtitle,
          style: context.textTheme.labelMedium?.copyWith(
            color: foreground.withValues(alpha: _mutedAlpha),
          ),
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Satırlar

  /// Satır; sohbet açık değilse altına sebebini yazan bir satır ekleniyor.
  ///
  /// Düğme yalnızca sunucu "açık" dediğinde çiziliyor
  /// (`messagingAvailable`). Ödeme bekleniyorsa ya da pencere kapandıysa
  /// düğmenin yerini [MessagingGateNote] alıyor; düğmeyi bırakıp `403`
  /// yedirmek yerine kullanıcı sebebi önden görüyor.
  Widget _jobTile(
    MyJob job,
    Color foreground, {
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      vertical: AppSizes.spaceTiny,
    ),
    Widget? menu,
  }) {
    final offersChat = _canChat(job);
    final gateNote = offersChat
        ? job.messaging.noteFor(asEmployer: false)
        : null;

    final tile = ListTile(
      contentPadding: contentPadding,
      title: _tileTitle(job.title, foreground),
      subtitle: _tileSubtitle(job, foreground, maxLines: 1),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _priceAndDate(job, foreground),
          if (offersChat && job.messaging.isAvailable)
            IconButton(
              key: ValueKey('job-chat-${job.jobId}'),
              tooltip: 'İşverenle mesajlaş',
              onPressed: openingChatJobId != null ? null : () => openChat(job),
              icon: openingChatJobId == job.jobId
                  ? const SizedBox.square(
                      dimension: AppSizes.iconSmall,
                      child: CircularProgressIndicator(
                        strokeWidth: MyJobsPagemodel._spinnerStroke,
                      ),
                    )
                  : AppIcon(
                      AppIcons.chat,
                      color: foreground,
                      size: AppSizes.icon,
                    ),
            ),
          ?menu,
        ],
      ),
    );

    if (gateNote == null) return tile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceTiny),
          child: MessagingGateNote(
            key: ValueKey('job-chat-note-${job.jobId}'),
            message: gateNote,
            color: foreground.withValues(alpha: _dateAlpha),
          ),
        ),
      ],
    );
  }

  /// Bu satırda sohbet teklif ediliyor mu — kapalı işlerde hiç edilmiyor.
  ///
  /// Kapının açık olup olmadığı ayrı bir soru ([MyJob.messaging]); burası
  /// yalnızca satırın durumuna bakıyor.
  bool _canChat(MyJob job) {
    return job.jobId != null &&
        switch (job.status) {
          MyJobStatus.pending ||
          MyJobStatus.awaitingApproval ||
          MyJobStatus.approved ||
          MyJobStatus.inProgress ||
          MyJobStatus.completed => true,
          _ => false,
        };
  }

  Widget _priceAndDate(MyJob job, Color foreground) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '₺${job.price.toStringAsFixed(0)}',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
        Text(
          job.date,
          style: context.textTheme.labelMedium?.copyWith(
            color: foreground.withValues(alpha: _dateAlpha),
          ),
        ),
      ],
    );
  }

  /// Atamanın ikincil eylemleri: iptal ve sorun bildirme.
  ///
  /// İkisi de nadir ve geri dönüşü zor; birincil butonların yanında değil
  /// menünün içinde duruyorlar. Kapanmış işlerde menü hiç çıkmıyor.
  Widget? _assignmentMenu(MyJob job, Color foreground) {
    final canCancel =
        job.status == MyJobStatus.approved ||
        job.status == MyJobStatus.inProgress;
    // Uyuşmazlık yalnızca para emanetteyken açılabiliyor.
    final canDispute =
        job.isPaymentSecured &&
        (job.status == MyJobStatus.inProgress ||
            job.status == MyJobStatus.completed);

    if (job.assignmentId == null || (!canCancel && !canDispute)) return null;

    return PopupMenuButton<_AssignmentAction>(
      enabled: assignmentActionId == null,
      icon: Icon(Icons.more_vert, color: foreground),
      onSelected: (action) => switch (action) {
        _AssignmentAction.cancel => cancelAssignment(job),
        _AssignmentAction.dispute => openDispute(job),
      },
      itemBuilder: (_) => [
        if (canCancel)
          const PopupMenuItem(
            value: _AssignmentAction.cancel,
            child: Text('İşi İptal Et'),
          ),
        if (canDispute)
          const PopupMenuItem(
            value: _AssignmentAction.dispute,
            child: Text('Sorun Bildir'),
          ),
      ],
    );
  }

  /// Bekleyen başvurunun tek ikincil eylemi: geri çekme.
  ///
  /// Menü yalnızca "Başvuru Bekliyor" satırında çıkıyor; sunucu da geri
  /// çekmeyi yalnızca `APPLIED` durumdan kabul ediyor. Atamadan gelen
  /// satırlar eleniyor: geri çekme **başvurunun** kimliğini istiyor ve o
  /// satırlarda [MyJob.id] atamanın kimliği olur.
  Widget? _applicationMenu(MyJob job, Color foreground) {
    if (job.status != MyJobStatus.pending || job.assignmentId != null) {
      return null;
    }

    return PopupMenuButton<_ApplicationAction>(
      // Bir başvuru geri çekilirken diğerlerinin menüsü de kapanıyor:
      // provider tek bir isteği izliyor ve arada ikinci istek gitmiyor.
      enabled: context.watch<ApplyProvider>().withdrawingId == null,
      icon: AppIcon(AppIcons.more, color: foreground),
      onSelected: (action) => switch (action) {
        _ApplicationAction.withdraw => withdrawApplication(job),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ApplicationAction.withdraw,
          child: Text('Başvurumu Geri Çek'),
        ),
      ],
    );
  }

  /// Cevap bekleyen atama: ücret, tarih ve iki karar butonu.
  ///
  /// Butonlar satırın altına alındı; `trailing`'e sığmıyorlar ve reddetme
  /// geri alınamadığı için kabul butonuyla yan yana durmaları gerekiyor.
  Widget _awaitingTile(MyJob job) {
    final foreground = context.textPrimary;
    final isResponding = respondingAssignmentId == job.assignmentId;
    // Bir atama cevaplanırken diğerlerinin butonları da kapanıyor: liste
    // cevaptan sonra baştan çekiliyor, arada ikinci bir cevap tutarsız olurdu.
    final isLocked = respondingAssignmentId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: AppPadding.zero,
            title: _tileTitle(job.title, foreground),
            subtitle: _tileSubtitle(job, foreground, maxLines: 1),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₺${job.price.toStringAsFixed(0)}',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                Text(
                  job.date,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: foreground.withValues(alpha: _dateAlpha),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: _inlineButtonHeight,
                  child: OutlinedButton(
                    onPressed: isLocked ? null : () => _confirmReject(job),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: AppPadding.zero,
                      textStyle: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.smallCircular,
                      ),
                    ),
                    child: const Text('Reddet'),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: SizedBox(
                  height: _inlineButtonHeight,
                  child: ElevatedButton(
                    onPressed: isLocked
                        ? null
                        : () => respondToAssignment(job, accepted: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentColor,
                      foregroundColor: context.onAccentColor,
                      elevation: 0,
                      padding: AppPadding.zero,
                      textStyle: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.smallCircular,
                      ),
                    ),
                    child: isResponding
                        ? SizedBox(
                            width: AppSizes.iconSmall,
                            height: AppSizes.iconSmall,
                            child: CircularProgressIndicator(
                              strokeWidth: _spinnerStroke,
                              color: context.onAccentColor,
                            ),
                          )
                        : const Text('Kabul Et'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Reddetme geri alınamıyor: atama kapanıyor ve iş başkasına gidiyor.
  Future<void> _confirmReject(MyJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text('İşi reddet', style: dialogContext.textTheme.titleMedium),
        content: Text(
          '"${job.title}" işini reddedersen bu iş sana kapanır ve geri '
          'alamazsın. İşveren başka birini seçebilir.',
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

  /// Onaylanmış iş: satırın altında mesai başlatma butonu.
  ///
  /// Buton yalnızca atamadan gelen satırlarda çıkıyor; başvurudan gelen bir
  /// satırın atama kimliği yok ve mesaisi de olamaz.
  Widget _approvedTile(MyJob job) {
    if (job.assignmentId == null) return _jobTile(job, AppColors.onAccent);
    final queuedEvents = context
        .watch<TimesheetQueueProvider>()
        .eventsForAssignment(job.assignmentId!);
    final lastQueuedAction = queuedEvents.lastOrNull?.action;
    final needsSupport = queuedEvents.any((event) => event.requiresSupport);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jobTile(
            job,
            AppColors.onAccent,
            contentPadding: AppPadding.zero,
            menu: _assignmentMenu(job, AppColors.onAccent),
          ),
          if (queuedEvents.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            TimesheetQueueStatus(
              events: queuedEvents,
              onSupport: () => openTimesheetSupport(job),
            ),
          ],
          const SizedBox(height: AppSizes.spaceSmall),
          // Sunucu, para emanete geçmeden mesai başlatmıyor. Butonu açık
          // bırakıp 409 yedirmek yerine sebebi burada yazılıyor.
          if (!job.isPaymentSecured)
            Text(
              'İşveren ücreti henüz güvenceye almadı; mesaiyi o zaman '
              'başlatabilirsin.',
              style: context.textTheme.labelMedium?.copyWith(
                color: AppColors.onAccent.withValues(alpha: _dateAlpha),
              ),
            )
          else if (!needsSupport &&
              lastQueuedAction != TimesheetEventAction.checkOut)
            SizedBox(
              width: double.infinity,
              height: _inlineButtonHeight,
              child: ElevatedButton.icon(
                onPressed: timesheetBusyAssignmentId != null
                    ? null
                    : () => lastQueuedAction == TimesheetEventAction.checkIn
                          ? checkOut(job)
                          : checkIn(job),
                icon: _timesheetIcon(
                  job,
                  icon: lastQueuedAction == TimesheetEventAction.checkIn
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  color: context.accentColor,
                ),
                label: Text(
                  lastQueuedAction == TimesheetEventAction.checkIn
                      ? 'Mesaiyi Bitir'
                      : 'Mesaiyi Başlat',
                ),
                style: _timesheetButtonStyle(
                  background: AppColors.onAccent,
                  foreground: context.accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Süren iş: mesainin ne zaman başladığı ve çıkış butonu.
  Widget _inProgressTile(MyJob job) {
    final foreground = context.textPrimary;
    final session = openSessions[job.assignmentId];
    final queuedEvents = job.assignmentId == null
        ? const <TimesheetEvent>[]
        : context.watch<TimesheetQueueProvider>().eventsForAssignment(
            job.assignmentId!,
          );
    final lastQueuedAction = queuedEvents.lastOrNull?.action;
    final needsSupport = queuedEvents.any((event) => event.requiresSupport);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jobTile(
            job,
            foreground,
            contentPadding: AppPadding.zero,
            menu: _assignmentMenu(job, foreground),
          ),
          if (session != null) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _sessionLine(session),
          ],
          if (queuedEvents.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            TimesheetQueueStatus(
              events: queuedEvents,
              onSupport: () => openTimesheetSupport(job),
            ),
          ],
          const SizedBox(height: AppSizes.spaceSmall),
          if (!needsSupport &&
              lastQueuedAction != TimesheetEventAction.checkOut)
            SizedBox(
              width: double.infinity,
              height: _inlineButtonHeight,
              child: ElevatedButton.icon(
                onPressed: timesheetBusyAssignmentId != null
                    ? null
                    : () => checkOut(job),
                icon: _timesheetIcon(
                  job,
                  icon: Icons.stop_rounded,
                  color: AppColors.onAccent,
                ),
                label: const Text('Mesaiyi Bitir'),
                style: _timesheetButtonStyle(
                  background: AppColors.progress,
                  foreground: AppColors.onAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Açık oturumun başlangıcı ve o ana kadarki süresi.
  ///
  /// Başlangıç saati kesin; süre `DateTime.now()` ile hesaplandığı için
  /// dakikada bir yeniden çiziliyor (`_syncElapsedTicker`).
  Widget _sessionLine(WorkSession session) {
    final startedAt = session.checkInAt;

    return Row(
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: AppSizes.iconSmall,
          color: AppColors.progress,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          startedAt == null
              ? session.elapsed.asWorkDuration
              : "${startedAt.asShortTime}'de başladın · "
                    '${session.elapsed.asWorkDuration}',
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.progress,
          ),
        ),
      ],
    );
  }

  /// Mesai butonunun ikonu; istek sürerken yerini bekleme halkası alıyor.
  Widget _timesheetIcon(
    MyJob job, {
    required IconData icon,
    required Color color,
  }) {
    if (timesheetBusyAssignmentId != job.assignmentId) {
      return Icon(icon, size: AppSizes.icon, color: color);
    }

    return SizedBox(
      width: AppSizes.iconSmall,
      height: AppSizes.iconSmall,
      child: CircularProgressIndicator(
        strokeWidth: _spinnerStroke,
        color: color,
      ),
    );
  }

  ButtonStyle _timesheetButtonStyle({
    required Color background,
    required Color foreground,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      padding: AppPadding.zero,
      textStyle: context.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.smallCircular,
      ),
    );
  }

  Widget _completedTile(MyJob job, {required bool alreadyReviewed}) {
    final foreground = context.textPrimary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSizes.spaceTiny),
      title: _tileTitle(job.title, foreground),
      subtitle: _tileSubtitle(job, foreground),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          alreadyReviewed
              ? _reviewedBadge()
              : _reviewButton(job, background: AppColors.warning),
          ?_assignmentMenu(job, foreground),
        ],
      ),
    );
  }

  /// "Değerlendir" butonu. Bir işi değerlendirmek sunucuda atama
  /// tamamlandıktan sonra serbest, ödemenin serbest bırakılmasını
  /// beklemiyor — bu yüzden hem "Ödeme Bekleniyor" hem "Geçmiş" satırında
  /// çıkıyor. Zemini bölüme göre değişiyor.
  Widget _reviewButton(MyJob job, {required Color background}) {
    return SizedBox(
      height: _inlineButtonHeight,
      child: ElevatedButton(
        onPressed: () => context.push('/review', extra: job),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          padding: AppPadding.primaryHorizontal,
          textStyle: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smallCircular,
          ),
        ),
        child: const Text('Değerlendir'),
      ),
    );
  }

  Widget _reviewedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space,
        vertical: AppSizes.spaceSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: AppSizes.iconSmall,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            'Değerlendirildi',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.successStrong,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastJobTile(MyJob job) {
    final foreground = context.textPrimary;
    // Ödeme serbest bırakıldığında iş buraya taşınıyor; değerlendirme hakkı
    // orada bitmiyor. Buton yalnızca burada olmasaydı, hızlı ödeyen bir
    // işvereni değerlendirmek hiç mümkün olmazdı.
    //
    // İptal ve red edilen işler değerlendirilemiyor: sunucu yalnızca
    // tamamlanmış atamaya değerlendirme kabul ediyor.
    final canReview =
        job.status == MyJobStatus.past &&
        job.assignmentId != null &&
        !context.watch<ReviewProvider>().hasReviewed(job.assignmentId);

    if (canReview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _pastJobRow(job, foreground),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
            child: _reviewButton(job, background: context.accentColor),
          ),
        ],
      );
    }

    return _pastJobRow(job, foreground);
  }

  Widget _pastJobRow(MyJob job, Color foreground) {
    // Tamamlanan işte para kazanıldı, iptal ve reddedilende kazanılmadı;
    // ikisini aynı yeşil tutarla göstermek yanlış bilgi olurdu.
    final isDone = job.status == MyJobStatus.past;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSizes.spaceTiny),
      title: _tileTitle(job.title, foreground),
      subtitle: _tileSubtitle(job, foreground, maxLines: 1),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isDone
                ? '₺${job.price.toStringAsFixed(0)}'
                : job.status.displayName,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDone ? AppColors.successStrong : AppColors.danger,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(job.date, style: context.textTheme.labelMedium),
              const SizedBox(width: AppSizes.spaceTiny),
              Icon(
                isDone ? Icons.check_circle : Icons.cancel,
                color: isDone ? AppColors.success : AppColors.danger,
                size: AppSizes.iconSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
