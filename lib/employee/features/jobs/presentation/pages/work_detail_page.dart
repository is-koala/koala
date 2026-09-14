import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/employer_type_badge.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/core/widgets/job_location_card.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/models/work_timeline.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_actions_pagemodel.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/cancellation_card.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/employer_card.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/timesheet_queue_status.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/work_timeline_view.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/messaging_gate_note.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'work_detail_pagemodel.dart';

/// Üst menüdeki ikincil eylemler.
enum _WorkMenuAction { cancel, dispute, withdraw }

/// Bir işin — başvurunun ya da atamanın — detay sayfası.
///
/// İşlerim'in her satırı ve Kazançlar'daki her ödeme buraya açılıyor
/// (is-koala/koala#177). Satır bir özet; burada ilanın açık adresi (atama
/// kurulduysa), işverenin kimliği, ücret dökümü, ödemenin durumu, zaman
/// çizelgesi, iptal kaydı ve satırdaki eylemlerin aynısı var. Eylemler
/// [WorkActionsPagemodel]'den geliyor; İşlerim'le aynı akış, aynı kurallar.
class WorkDetailPage extends StatefulWidget {
  const WorkDetailPage({
    super.key,
    required this.job,
    this.assignmentService,
    this.chatService,
    this.jobService,
  });

  /// Açılan kayıt. [MyJob.assignment] ya da [MyJob.application] dolu olmalı;
  /// sayfa çizelgeyi ve işvereni satırdan değil kaynaktan okuyor.
  final MyJob job;

  /// Testler için: verilmezse üretimdeki tekil servisler kullanılıyor.
  final AssignmentService? assignmentService;
  final ChatService? chatService;
  final JobService? jobService;

  @override
  State<WorkDetailPage> createState() => _WorkDetailPageState();
}

class _WorkDetailPageState extends WorkDetailPagemodel {
  /// Alt çubuktaki butonların yüksekliği.
  static const double _actionButtonHeight = 48;

  /// Buton içindeki bekleme halkasının kalınlığı.
  static const double _spinnerStroke = 2;

  /// Fiyat snapshot'ı (`pricing`) gelmediğinde tutarın para birimi; ilan
  /// ücreti `salary` birim taşımıyor ve uygulama yalnız TRY'de çalışıyor.
  static const String _defaultCurrency = 'TRY';

  @override
  Widget build(BuildContext context) {
    final entries = WorkTimeline.build(
      job,
      sessions: sessions,
      cancellation: cancellation,
    );
    final cancellationRecord = cancellation ?? job.assignment?.cancellation;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: 'İş Detayı', actions: [?_menu()]),
      body: RefreshIndicator(
        onRefresh: refreshWork,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppPadding.primaryAll,
          children: [
            if (detailError != null) ...[
              _detailErrorStrip(),
              const SizedBox(height: AppSizes.space),
            ],
            _headerCard(),
            const SizedBox(height: AppSizes.space),
            _employerCard(),
            const SizedBox(height: AppSizes.space),
            _addressCard(),
            if (job.paymentStatus != null) ...[
              const SizedBox(height: AppSizes.space),
              _paymentCard(),
            ],
            if (entries.isNotEmpty) ...[
              const SizedBox(height: AppSizes.space),
              _card(
                title: 'Zaman Çizelgesi',
                child: WorkTimelineView(entries: entries),
              ),
            ],
            if (cancellationRecord != null) ...[
              const SizedBox(height: AppSizes.space),
              CancellationCard(cancellation: cancellationRecord),
            ],
            if (_canReview) ...[
              const SizedBox(height: AppSizes.space),
              _reviewCard(),
            ],
            if (job.offersChat) ...[
              const SizedBox(height: AppSizes.space),
              _messageCard(),
            ],
            ..._queueStatus(),
            SizedBox(height: context.padding.bottom + AppSizes.spaceLarge),
          ],
        ),
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  // ------------------------------------------------------------- Üst menü

  /// İkincil eylemler: iptal, sorun bildirme, başvuruyu geri çekme.
  ///
  /// Koşullar İşlerim satırındaki menüyle aynı; iş kapandıysa menü yok.
  Widget? _menu() {
    final canCancel =
        job.assignmentId != null &&
        (job.status == MyJobStatus.approved ||
            job.status == MyJobStatus.inProgress);
    final canDispute =
        job.assignmentId != null &&
        job.isPaymentSecured &&
        (job.status == MyJobStatus.inProgress ||
            job.status == MyJobStatus.completed);
    final canWithdraw =
        job.status == MyJobStatus.pending && job.assignmentId == null;

    if (!canCancel && !canDispute && !canWithdraw) return null;

    final busy =
        assignmentActionId != null ||
        refreshing ||
        context.watch<ApplyProvider>().withdrawingId != null;

    return PopupMenuButton<_WorkMenuAction>(
      key: const ValueKey('work-detail-menu'),
      enabled: !busy,
      icon: AppIcon(AppIcons.more, color: context.textPrimary),
      onSelected: (action) => switch (action) {
        _WorkMenuAction.cancel => cancelAssignment(job),
        _WorkMenuAction.dispute => openDispute(job),
        _WorkMenuAction.withdraw => withdraw(),
      },
      itemBuilder: (_) => [
        if (canCancel)
          const PopupMenuItem(
            value: _WorkMenuAction.cancel,
            child: Text('İşi İptal Et'),
          ),
        if (canDispute)
          const PopupMenuItem(
            value: _WorkMenuAction.dispute,
            child: Text('Sorun Bildir'),
          ),
        if (canWithdraw)
          const PopupMenuItem(
            value: _WorkMenuAction.withdraw,
            child: Text('Başvurumu Geri Çek'),
          ),
      ],
    );
  }

  // ------------------------------------------------------------- Kartlar

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textTheme.titleSmall),
          const SizedBox(height: AppSizes.space),
          child,
        ],
      ),
    );
  }

  /// İlan detayı çekilemediğinde üstte duran şerit; sayfa kalanıyla çalışıyor.
  Widget _detailErrorStrip() {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'İlan bilgileri alınamadı: $detailError',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          TextButton(onPressed: _loadDetail, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }

  /// Başlık kartı: durum, ilan başlığı, kategori, ücret ve tarih.
  Widget _headerCard() {
    final summary = summaryJob;
    final description = detail?.description ?? job.description;

    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusChip(),
              const Spacer(),
              EmployerTypeBadge(type: job.employerType),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            job.status.description,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.space),
          Text(
            job.title,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Row(
              children: [
                AppIcon(
                  summary.category.icon,
                  size: AppSizes.iconSmall,
                  color: summary.category.color,
                ),
                const SizedBox(width: AppSizes.spaceTiny),
                Text(
                  '${summary.category.displayName} · '
                  '${summary.type.displayName}',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.space),
          _dateLine(summary),
          const SizedBox(height: AppSizes.space),
          _priceBlock(),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space),
            Text(
              description,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('work-detail-open-job'),
                onPressed: () => JobDetailBottomSheet.show(context, summary),
                icon: AppIcon(
                  AppIcons.fileText,
                  size: AppSizes.iconSmall,
                  color: context.accentColor,
                ),
                label: const Text('İlanı görüntüle'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip() {
    final color = _statusColor(job.status);

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.stadiumCircular,
        border: Border.all(color: color),
      ),
      child: Text(
        job.status.displayName,
        style: context.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(MyJobStatus status) => switch (status) {
    MyJobStatus.pending => AppColors.pending,
    MyJobStatus.awaitingApproval => AppColors.info,
    MyJobStatus.approved => context.accentColor,
    MyJobStatus.inProgress => AppColors.progress,
    MyJobStatus.completed => AppColors.warning,
    MyJobStatus.past => AppColors.successStrong,
    MyJobStatus.rejected ||
    MyJobStatus.applicationRejected ||
    MyJobStatus.cancelled => AppColors.danger,
    MyJobStatus.withdrawn || MyJobStatus.unknown => context.textTertiary,
  };

  /// İşin tarihi: ilanın başlangıç–bitiş anı, o yoksa satırdaki tarih.
  Widget _dateLine(Job? summary) {
    final start = summary?.startDateTime;
    final end = summary?.endDateTime;
    final String label;
    if (start != null && end != null) {
      label = start.day == end.day && start.month == end.month
          ? '${start.asShortDate} · ${start.asShortTime} – ${end.asShortTime}'
          : '${start.asShortDateTime} – ${end.asShortDateTime}';
    } else if (start != null) {
      label = start.asShortDateTime;
    } else {
      label = job.date.isEmpty ? 'Tarih belirtilmemiş' : job.date;
    }

    return Row(
      children: [
        AppIcon(
          AppIcons.calendar,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
      ],
    );
  }

  /// Ücret: atamada `pricing.*` dökümü, başvuruda ilan ücreti.
  ///
  /// Döküm sunucunun yayımlarken sabitlediği snapshot; hizmet bedeli burada
  /// yeniden hesaplanmıyor, dizeler olduğu gibi yazılıyor.
  Widget _priceBlock() {
    final pricing = job.assignment?.pricing;
    final currency = pricing?.currency ?? _defaultCurrency;
    final payoutLabel = pricing == null
        ? TurkishMoneyFormatter.format(job.price.toStringAsFixed(2), currency)
        : TurkishMoneyFormatter.format(pricing.workerPayout, currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIcon(
              AppIcons.moneyBag,
              size: AppSizes.iconSmall,
              color: context.accentColor,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Text(
              job.assignment == null ? 'İlan ücreti' : 'Kazancınız',
              style: context.textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              payoutLabel,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.accentColor,
              ),
            ),
          ],
        ),
        if (pricing != null) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          _breakdownRow(
            'Hizmet bedeli (%${_percent(pricing.serviceFeeRate)})',
            TurkishMoneyFormatter.format(pricing.serviceFeeAmount, currency),
          ),
          _breakdownRow(
            'İşverenin ödediği toplam',
            TurkishMoneyFormatter.format(pricing.employerTotal, currency),
          ),
        ],
      ],
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// `0.075` → `7,5`; oran ondalık dize olarak geliyor.
  static String _percent(String rate) {
    final value = double.tryParse(rate);
    if (value == null) return rate;
    final percent = value * 100;
    final text = percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }

  /// İşveren kartı: şirket ilanında ad + logo + bağlantı, bireyselde ad +
  /// fotoğraf. Kaynak sırası: atamanın kendi alanları (koala-backend#282),
  /// sonra ilan detayı, sonra özetteki şirket adı.
  Widget _employerCard() {
    final assignment = job.assignment;
    final isCompany = job.employerType == JobEmployerType.company;

    final String? name;
    final String? imageUrl;
    if (isCompany) {
      name = assignment?.company?.name ?? detail?.company?.name ?? job.company;
      imageUrl =
          assignment?.company?.logoUrl ??
          detail?.company?.logoUrl ??
          summaryJob?.companyLogoUrl;
    } else {
      final person = assignment?.employer ?? detail?.creator;
      final fullName = person?.fullName;
      name = fullName == null || fullName.isEmpty ? null : fullName;
      imageUrl = person?.profilePictureUrl;
    }

    return EmployerCard(
      employerType: job.employerType,
      name: name,
      imageUrl: imageUrl,
      onOpenCompany: isCompany ? openCompany : null,
    );
  }

  /// Adres: sunucu `EXACT` verdiyse açık adres ve tarif, vermediyse ilçe/il.
  ///
  /// Kesinliğe **detay** karar veriyor; özet yalnızca ilçe/il taşıyor.
  /// Detay gelmeden ya da gelemezse özetin kesinliği geçerli — o da
  /// bilinmiyorsa yaklaşık, çünkü kanıtlanmamış yetki kesin sayılmaz.
  Widget _addressCard() {
    final address = detail?.address;
    final precision = detail?.addressPrecision ?? summaryJob?.addressPrecision;
    final label =
        detail?.addressLabel ??
        summaryJob?.locationLabel ??
        address?.shortLabel ??
        'Konum belirtilmemiş';

    return JobLocationCard(
      precision: precision ?? AddressPrecision.approximate,
      label: label,
      directions: address?.components?.additionalDirections,
    );
  }

  /// Ödeme durumu: dört hâlin her biri kendi cümlesiyle.
  Widget _paymentCard() {
    final status = job.paymentStatus!;
    final payout = job.assignment?.payout;
    final completedAt = payout?.completedAt;

    return _card(
      title: 'Ödeme',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status.workerLabel,
            key: const ValueKey('work-detail-payment-status'),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _paymentColor(status),
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            status.workerNote,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
          if (payout != null && !status.isPaid) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              'Hakediş: ${payout.status.displayName}',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
          if (completedAt != null) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              'Hakediş ${completedAt.toLocal().asShortDateTime} tarihinde '
              'ödendi.',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _paymentColor(PaymentStatus status) => switch (status) {
    PaymentStatus.pendingCollection => AppColors.warning,
    PaymentStatus.heldInEscrow => AppColors.progress,
    PaymentStatus.releasedToWorker => AppColors.successStrong,
    PaymentStatus.failed || PaymentStatus.refunded => AppColors.danger,
  };

  /// Değerlendirme: tamamlanmış atamada durum ve düğme.
  ///
  /// Sunucu "değerlendirdim mi" demiyor; [ReviewProvider] cihazda tutuyor.
  bool get _canReview =>
      job.assignmentId != null &&
      (job.status == MyJobStatus.completed || job.status == MyJobStatus.past);

  Widget _reviewCard() {
    final reviewed = context.watch<ReviewProvider>().hasReviewed(
      job.assignmentId,
    );

    return _card(
      title: 'Değerlendirme',
      child: Row(
        children: [
          AppIcon(
            reviewed ? AppIcons.checkCircle : AppIcons.star,
            size: AppSizes.iconMedium,
            color: reviewed ? AppColors.success : AppColors.rating,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              reviewed
                  ? 'Bu işi değerlendirdiniz.'
                  : 'İşvereni henüz değerlendirmediniz.',
              style: context.textTheme.bodyMedium,
            ),
          ),
          if (!reviewed)
            TextButton(
              key: const ValueKey('work-detail-review'),
              onPressed: () => context.push('/review', extra: job),
              child: const Text('Değerlendir'),
            ),
        ],
      ),
    );
  }

  /// Mesaj kapısı: açıksa düğme, kapalıysa sebebi.
  Widget _messageCard() {
    final note = job.messaging.noteFor(asEmployer: false);

    return _card(
      title: 'İletişim',
      child: job.messaging.isAvailable
          ? SizedBox(
              width: double.infinity,
              height: _actionButtonHeight,
              child: OutlinedButton.icon(
                key: const ValueKey('work-detail-chat'),
                onPressed: openingChatJobId != null
                    ? null
                    : () => openChat(job),
                icon: openingChatJobId == job.jobId
                    ? const SizedBox.square(
                        dimension: AppSizes.iconSmall,
                        child: CircularProgressIndicator(
                          strokeWidth: _spinnerStroke,
                        ),
                      )
                    : AppIcon(
                        AppIcons.chat,
                        size: AppSizes.iconMedium,
                        color: context.accentColor,
                      ),
                label: const Text('İşverenle mesajlaş'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.accentColor,
                  side: BorderSide(color: context.accentColor),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.smallCircular,
                  ),
                ),
              ),
            )
          : MessagingGateNote(
              key: const ValueKey('work-detail-chat-note'),
              message: note ?? 'Mesajlaşma şu an kapalı.',
            ),
    );
  }

  /// Çevrimdışı kuyrukta bekleyen mesai kayıtları.
  List<Widget> _queueStatus() {
    final assignmentId = job.assignmentId;
    if (assignmentId == null) return const [];
    final events = context.watch<TimesheetQueueProvider>().eventsForAssignment(
      assignmentId,
    );
    if (events.isEmpty) return const [];

    return [
      const SizedBox(height: AppSizes.space),
      TimesheetQueueStatus(
        events: events,
        onSupport: () => openTimesheetSupport(job),
      ),
    ];
  }

  // ---------------------------------------------------------- Alt çubuk

  /// Birincil eylem, satırdakiyle aynı koşullarla.
  ///
  /// Cevap bekleyen atamada iki karar butonu; onaylanmış işte mesai (ücret
  /// emanetteyse); süren işte çıkış. Ödeme bekleyen işte sebep zaten ödeme
  /// kartında yazıyor, çubuk çizilmiyor.
  Widget? _actionBar() {
    final content = switch (job.status) {
      MyJobStatus.awaitingApproval => _respondButtons(),
      MyJobStatus.approved => job.isPaymentSecured ? _timesheetButton() : null,
      MyJobStatus.inProgress => _timesheetButton(),
      _ => null,
    };
    if (content == null) return null;

    return Container(
      padding: AppPadding.bottomBar.copyWith(
        bottom: context.padding.bottom + AppPadding.bottomBar.bottom,
      ),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        border: Border(top: BorderSide(color: context.dividerColor)),
      ),
      child: content,
    );
  }

  Widget _respondButtons() {
    if (job.assignmentId == null) return const SizedBox.shrink();
    final isResponding = respondingAssignmentId == job.assignmentId;
    final isLocked = respondingAssignmentId != null || refreshing;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: _actionButtonHeight,
            child: OutlinedButton(
              key: const ValueKey('work-detail-reject'),
              onPressed: isLocked ? null : () => confirmReject(job),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
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
            height: _actionButtonHeight,
            child: ElevatedButton(
              key: const ValueKey('work-detail-accept'),
              onPressed: isLocked
                  ? null
                  : () => respondToAssignment(job, accepted: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: context.onAccentColor,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.smallCircular,
                ),
              ),
              child: isResponding
                  ? SizedBox.square(
                      dimension: AppSizes.iconSmall,
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
    );
  }

  /// Mesai butonu: açık oturum (ya da kuyrukta bekleyen giriş) varsa
  /// "Mesaiyi Bitir", yoksa "Mesaiyi Başlat". Destek gerektiren kuyruk
  /// kaydı varken buton yok; kuyruk şeridi yolu gösteriyor.
  Widget? _timesheetButton() {
    final assignmentId = job.assignmentId;
    if (assignmentId == null) return null;

    final queued = context.watch<TimesheetQueueProvider>().eventsForAssignment(
      assignmentId,
    );
    final lastQueued = queued.lastOrNull?.action;
    if (queued.any((event) => event.requiresSupport)) return null;
    if (lastQueued == TimesheetEventAction.checkOut) return null;

    final isCheckOut =
        lastQueued == TimesheetEventAction.checkIn ||
        (lastQueued == null &&
            (openSession != null || job.status == MyJobStatus.inProgress));
    final busy = timesheetBusyAssignmentId != null || refreshing;
    final session = openSession;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session?.checkInAt != null) ...[
          Text(
            "${session!.checkInAt!.toLocal().asShortTime}'de başladınız · "
            '${session.elapsed.asWorkDuration}',
            style: context.textTheme.labelMedium?.copyWith(
              color: AppColors.progress,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
        ],
        SizedBox(
          height: _actionButtonHeight,
          child: ElevatedButton.icon(
            key: ValueKey(
              isCheckOut ? 'work-detail-check-out' : 'work-detail-check-in',
            ),
            onPressed: busy
                ? null
                : () => isCheckOut ? checkOut(job) : checkIn(job),
            icon: timesheetBusyAssignmentId == assignmentId
                ? SizedBox.square(
                    dimension: AppSizes.iconSmall,
                    child: CircularProgressIndicator(
                      strokeWidth: _spinnerStroke,
                      color: context.onAccentColor,
                    ),
                  )
                : AppIcon(
                    isCheckOut ? AppIcons.close : AppIcons.clock,
                    size: AppSizes.iconMedium,
                    color: context.onAccentColor,
                  ),
            label: Text(isCheckOut ? 'Mesaiyi Bitir' : 'Mesaiyi Başlat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCheckOut
                  ? AppColors.progress
                  : context.accentColor,
              foregroundColor: context.onAccentColor,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.smallCircular,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
