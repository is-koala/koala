import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:provider/provider.dart';

part 'b_job_detail_pagemodel.dart';

/// İşverenin kendi ilanının detayı ve o ilana gelen başvurular.
///
/// İki kaynaktan besleniyor: ilanın kendisi `GET /jobs/{id}`'den, başvurular
/// [BJobsProvider] üzerinden `GET /jobs/{id}/applications`'tan.
class BJobDetailPage extends StatefulWidget {
  const BJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<BJobDetailPage> createState() => _BJobDetailPageState();
}

class _BJobDetailPageState extends BJobDetailPageModel {
  @override
  Widget build(BuildContext context) {
    final post = context.watch<BJobsProvider>().getPostByJobId(widget.jobId);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: "İlan Detayı"),
      body: _body(post),
    );
  }

  Widget _body(BJobPost? post) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = _errorMessage;
    if (message != null) return _errorState(message);

    final job = _detail;
    if (job == null) {
      return Center(
        child: Text('İlan bulunamadı', style: context.textTheme.titleSmall),
      );
    }

    // İlan yürürlükte mi: karar sunucudaki duruma ait. Provider'daki kayıt
    // henüz gelmemiş olabilir, o yüzden detayın durumuna bakılıyor.
    final isActive =
        job.status == JobStatus.open || job.status == JobStatus.inProgress;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jobInfoCard(context, job, isActive: isActive),
          Padding(
            padding: AppPadding.primaryHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.spaceLarge),
                if (job.description != null) ...[
                  _sectionTitle(context, "Açıklama"),
                  const SizedBox(height: AppSizes.spaceSmall),
                  Text(
                    job.description!,
                    style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSizes.spaceLarge),
                ],
                _sectionTitle(context, "Detaylar"),
                const SizedBox(height: AppSizes.space),
                _detailsCard(context, job),
                const SizedBox(height: AppSizes.spaceLarge),
                ..._timesheetSection(),
                ..._peopleSection(post, isActive: isActive),
                const SizedBox(height: AppSizes.navBarClearance),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// İş takibi: atamanın durumu, mesai oturumları ve tamamlama butonu.
  ///
  /// Yalnızca ataması olan ilanda çiziliyor — başvuru kabul edilmeden ortada
  /// takip edilecek bir iş yok.
  List<Widget> _timesheetSection() {
    final assignment = _assignment;
    if (assignment == null) return const [];

    return [
      _sectionTitle(context, 'İş Takibi'),
      const SizedBox(height: AppSizes.space),
      Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: _panelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _assignmentStatusRow(assignment),
            if (_workSessions.isNotEmpty) ...[
              const SizedBox(height: AppSizes.space),
              ..._workSessions.map(_workSessionRow),
              const SizedBox(height: AppSizes.spaceSmall),
              _totalWorkedRow(),
            ] else ...[
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                'Çalışan henüz mesai başlatmadı.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
            ?_openDisputeBanner(),
            if (_canComplete(assignment)) ...[
              const SizedBox(height: AppSizes.spaceMedium),
              _completeButton(),
            ],
            ..._assignmentActions(assignment),
          ],
        ),
      ),
      const SizedBox(height: AppSizes.spaceLarge),
    ];
  }

  /// Tamamlama yalnızca bu iki durumdan yapılabiliyor; sunucu da aynı
  /// kapıyı tutuyor ve dışından `409` döndürüyor.
  bool _canComplete(Assignment assignment) =>
      assignment.status == AssignmentStatus.confirmed ||
      assignment.status == AssignmentStatus.inProgress;

  Widget _assignmentStatusRow(Assignment assignment) {
    return Row(
      children: [
        Text('Durum', style: context.textTheme.bodyMedium),
        const Spacer(),
        _badge(
          context,
          color: assignment.status == AssignmentStatus.inProgress
              ? AppColors.progress
              : context.accentColor,
          child: Text(
            assignment.status.displayName,
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: assignment.status == AssignmentStatus.inProgress
                  ? AppColors.progress
                  : context.accentColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Tek mesai oturumu: giriş, çıkış ve süre. Açık oturumda çıkış yerine
  /// "sürüyor" yazıyor.
  Widget _workSessionRow(WorkSession session) {
    final start = session.checkInAt;
    final end = session.checkOutAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Row(
        children: [
          Icon(
            session.isOpen
                ? Icons.play_circle_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: AppSizes.iconSmall,
            color: session.isOpen ? AppColors.progress : context.textTertiary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              start == null
                  ? '—'
                  : '${start.asShortDate} · ${start.asShortTime}'
                        ' - ${end?.asShortTime ?? 'sürüyor'}',
              style: context.textTheme.bodyMedium,
            ),
          ),
          Text(
            session.elapsed.asWorkDuration,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Toplam çalışılan süre.
  ///
  /// Açık oturumun süresi de sayılıyor ama sunucudaki `workHours` yalnızca
  /// kapanmış oturumlardan türüyor; ikisi mesai sürerken farklı olabilir.
  Widget _totalWorkedRow() {
    final total = _workSessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.elapsed,
    );

    return Row(
      children: [
        Text(
          'Toplam',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          total.asWorkDuration,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.accentColor,
          ),
        ),
      ],
    );
  }

  /// Açık uyuşmazlık uyarısı.
  ///
  /// Açık uyuşmazlık emanetteki parayı donduruyor; tamamlama butonunun
  /// neden beklediğini söylemek gerekiyor.
  Widget? _openDisputeBanner() {
    final open = _disputes.where((dispute) => dispute.isOpen).firstOrNull;
    if (open == null) return null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spaceMedium),
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(
            alpha: BJobDetailPageModel._tintAlpha,
          ),
          borderRadius: AppRadius.innerCircular,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Açık sorun bildirimi · ${open.status.displayName}',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (open.reason != null) ...[
              const SizedBox(height: AppSizes.spaceTiny),
              Text(
                open.reason!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              'Emanetteki ücret, Koala sonuçlandırana kadar dondurulur.',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// İptal ve sorun bildirme.
  ///
  /// İptal yalnızca iş kapanmadan; sorun bildirme yalnızca para emanetteyken
  /// ve ortada açık bir bildirim yokken. İkisi de sunucunun tuttuğu kapı.
  List<Widget> _assignmentActions(Assignment assignment) {
    final canCancel = _canComplete(assignment);
    final canDispute =
        assignment.paymentStatus == PaymentStatus.heldInEscrow &&
        !_disputes.any((dispute) => dispute.isOpen);

    if (!canCancel && !canDispute) return const [];

    return [
      const SizedBox(height: AppSizes.spaceSmall),
      Row(
        children: [
          if (canDispute)
            Expanded(
              child: TextButton(
                onPressed: _isRunningAssignmentAction ? null : _openDispute,
                child: const Text('Sorun Bildir'),
              ),
            ),
          if (canCancel)
            Expanded(
              child: TextButton(
                onPressed: _isRunningAssignmentAction
                    ? null
                    : _cancelAssignment,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('İşi İptal Et'),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _completeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCompleting ? null : _completeAssignment,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentColor,
          foregroundColor: context.onAccentColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppSizes.space),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.innerCircular,
          ),
          textStyle: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        child: _isCompleting
            ? SizedBox(
                width: AppSizes.icon,
                height: AppSizes.icon,
                child: CircularProgressIndicator(
                  strokeWidth: BJobDetailPageModel._spinnerStroke,
                  color: context.onAccentColor,
                ),
              )
            : const Text('İşi Tamamla'),
      ),
    );
  }

  @override
  Future<bool?> _confirmCompletion(Assignment assignment) {
    final hasOpenSession = _workSessions.any((session) => session.isOpen);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text('İşi tamamla', style: dialogContext.textTheme.titleMedium),
        content: Text(
          hasOpenSession
              ? 'Çalışanın mesaisi hâlâ açık. İşi şimdi tamamlarsan '
                    'emanetteki ücret ödemeye geçer ve bu geri alınamaz.'
              : 'Emanetteki ücret ödemeye geçer ve bu geri alınamaz. '
                    'İşin bittiğinden emin misin?',
          style: dialogContext.textTheme.bodyMedium?.copyWith(
            color: dialogContext.textSecondary,
            height: BJobDetailPageModel._dialogLineHeight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );
  }

  /// Alt bölüm: aktif ilanda onaylananlar ve bekleyen başvurular, kapanmış
  /// ilanda işi alan kişi.
  ///
  /// Başvurular ilan detayından ayrı geliyor; henüz gelmediyse boş liste
  /// yerine yükleme gösteriliyor — "henüz başvuru yok" yanlış bilgi olurdu.
  ///
  /// **Onaylananlar bekleyenlerin üstünde.** Bir başvuruyu kabul etmek ilanı
  /// kapatmıyor (sunucu atama açıp çalışanın onayını bekliyor), o yüzden
  /// kabul edilen aday ilan açıkken de gösterilmeli; önceki hâlinde bekleyen
  /// listesinden düşüp görünmez oluyordu.
  List<Widget> _peopleSection(BJobPost? post, {required bool isActive}) {
    if (post == null || !post.applicantsLoaded) {
      return [
        _sectionTitle(context, isActive ? "Başvuranlar" : "Yapan Kişi"),
        const SizedBox(height: AppSizes.space),
        const Center(child: CircularProgressIndicator()),
      ];
    }

    if (!isActive) {
      return [
        _sectionTitle(context, "Yapan Kişi"),
        const SizedBox(height: AppSizes.space),
        _workerSection(context, post.worker),
      ];
    }

    final accepted = post.acceptedApplicants;

    return [
      if (accepted.isNotEmpty) ...[
        _sectionTitle(context, "Onaylananlar (${accepted.length})"),
        const SizedBox(height: AppSizes.space),
        for (final applicant in accepted)
          _applicantCard(context, applicant, isAccepted: true),
        const SizedBox(height: AppSizes.spaceLarge),
      ],
      _sectionTitle(context, "Başvuranlar (${post.applicants.length})"),
      const SizedBox(height: AppSizes.space),
      _applicantsList(
        context,
        post.applicants,
        hasAccepted: accepted.isNotEmpty,
      ),
    ];
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              AppIcons.alert,
              size: AppSizes.iconLarge,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppSizes.space),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(
              onPressed: _loadDetail,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- İlan kartı

  Widget _jobInfoCard(
    BuildContext context,
    JobDetail job, {
    required bool isActive,
  }) {
    return Container(
      width: double.infinity,
      margin: AppPadding.primaryHorizontal,
      padding: AppPadding.sheet,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: context.accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSizes.spaceSmall,
            runSpacing: AppSizes.spaceSmall,
            children: [
              _categoryBadge(context, job),
              _statusBadge(context, job.status),
              _typeBadge(context, job),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            job.title,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(job.subtitle, style: context.textTheme.bodyMedium),
          const SizedBox(height: AppSizes.spaceMedium),
          _priceAndLocationRow(context, job),
        ],
      ),
    );
  }

  Widget _badge(
    BuildContext context, {
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: BJobDetailPageModel._tintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: child,
    );
  }

  Widget _categoryBadge(BuildContext context, JobDetail job) {
    return _badge(
      context,
      color: job.category.color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            job.category.icon,
            size: AppSizes.iconSmall,
            color: job.category.color,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            job.category.displayName,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: job.category.color,
            ),
          ),
        ],
      ),
    );
  }

  /// İlanın sunucudaki durumu. "Aktif / Geçmiş" yerine gerçek durum
  /// yazılıyor: kapanmış bir ilanla iptal edilmiş bir ilan aynı şey değil.
  Widget _statusBadge(BuildContext context, JobStatus status) {
    final isLive = status == JobStatus.open || status == JobStatus.inProgress;
    final color = switch (status) {
      JobStatus.open => AppColors.success,
      JobStatus.inProgress => AppColors.info,
      JobStatus.cancelled => AppColors.danger,
      _ => context.textTertiary,
    };

    return _badge(
      context,
      color: color,
      child: Text(
        status.displayName,
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isLive ? color : context.textSecondary,
        ),
      ),
    );
  }

  Widget _typeBadge(BuildContext context, JobDetail job) {
    return _badge(
      context,
      color: AppColors.info,
      child: Text(
        job.type.displayName,
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.info,
        ),
      ),
    );
  }

  Widget _priceAndLocationRow(BuildContext context, JobDetail job) {
    return Row(
      children: [
        Icon(
          Icons.monetization_on_outlined,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          '₺${job.price.toStringAsFixed(0)}',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: AppSizes.spaceLarge),
        Icon(
          Icons.location_on_outlined,
          size: AppSizes.iconSmall,
          color: context.textSecondary,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: Text(
            job.addressLabel ?? '—',
            style: context.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Detaylar

  Widget _detailsCard(BuildContext context, JobDetail job) {
    final start = job.startDateTime;
    final end = job.endDateTime;

    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration(context),
      child: Column(
        children: [
          if (start != null)
            _detailRow(
              context,
              AppIcons.calendar,
              'Başlangıç',
              start.asShortDateTime,
            ),
          if (end != null)
            _detailRow(context, AppIcons.clock, 'Bitiş', end.asShortDateTime),
          _detailRow(
            context,
            AppIcons.moneyBag,
            'Ücret Tipi',
            job.salaryType.displayName,
          ),
          if (job.sector != null)
            _detailRow(context, AppIcons.building, 'Sektör', job.sector!),
          if (job.position != null)
            _detailRow(context, AppIcons.user, 'Pozisyon', job.position!),
          if (job.duties != null)
            _detailRow(context, AppIcons.task, 'Görevler', job.duties!),
          if (job.dressCode != null)
            _detailRow(context, AppIcons.dress, 'Kıyafet', job.dressCode!),
          if (job.minAge != null || job.maxAge != null)
            _detailRow(
              context,
              AppIcons.userMultiple,
              'Yaş Aralığı',
              '${job.minAge ?? '-'} - ${job.maxAge ?? '-'} yaş',
            ),
          _detailRow(
            context,
            AppIcons.work,
            'Deneyim',
            job.experienceRequired ? 'Gerekli' : 'Gerekli Değil',
          ),
          _detailRow(
            context,
            AppIcons.shield,
            'Sigorta',
            job.insuranceRequired ? 'Gerekli' : 'Gerekli Değil',
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    AppIconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: AppSizes.iconSmall, color: context.accentColor),
          const SizedBox(width: AppSizes.space),
          SizedBox(
            width: BJobDetailPageModel._detailLabelWidth,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Başvuranlar

  /// Yanıt bekleyen başvurular.
  ///
  /// [hasAccepted] doluyken boş durum metni değişiyor: yukarıda onaylanmış
  /// bir aday dururken "henüz başvuru yok" demek yanlış olurdu.
  Widget _applicantsList(
    BuildContext context,
    List<JobApplicant> applicants, {
    bool hasAccepted = false,
  }) {
    if (applicants.isEmpty) {
      return _emptyPanel(
        context,
        icon: AppIcons.userMultiple,
        title: hasAccepted ? 'Bekleyen başvuru yok' : 'Henüz başvuru yok',
        subtitle: hasAccepted
            ? 'Yeni başvurular geldiğinde burada görünecek'
            : 'Başvurular geldiğinde burada görünecek',
      );
    }

    return Column(
      children: [
        for (final applicant in applicants) _applicantCard(context, applicant),
      ],
    );
  }

  /// Aday kartı.
  ///
  /// [isAccepted] iken kabul/ret butonları yerine yeşil bir rozet çiziliyor:
  /// yanıtlanmış bir başvuru ikinci kez yanıtlanamıyor, sunucu `400`
  /// döndürüyor.
  Widget _applicantCard(
    BuildContext context,
    JobApplicant applicant, {
    bool isAccepted = false,
  }) {
    final jobTitle = applicant.jobTitle;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space),
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: AppRadius.innerCircular,
        border: Border.all(color: context.dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.barShadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profil satırı — tıklanabilir
          GestureDetector(
            onTap: () =>
                context.push('/business/user-profile', extra: applicant),
            child: Row(
              children: [
                ProfileAvatar(
                  imageUrl: applicant.profilePictureUrl,
                  size: BJobDetailPageModel._applicantAvatar,
                ),
                const SizedBox(width: AppSizes.space),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applicant.fullName,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (jobTitle != null)
                        Text(jobTitle, style: context.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  applicant.applicationDateTime?.asShortDate ?? '',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (applicant.notes != null && applicant.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space),
            Container(
              width: double.infinity,
              padding: AppPadding.card,
              decoration: BoxDecoration(
                color: context.tileColor,
                borderRadius: AppRadius.smallCircular,
              ),
              child: Text(
                applicant.notes!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.space),
          if (isAccepted)
            _badge(
              context,
              color: AppColors.success,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    AppIcons.checkCircle,
                    size: AppSizes.iconSmall,
                    color: AppColors.successStrong,
                  ),
                  const SizedBox(width: AppSizes.spaceTiny),
                  Text(
                    'Onaylandı',
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.successStrong,
                    ),
                  ),
                ],
              ),
            )
          else
            _applicantActions(context, applicant),
        ],
      ),
    );
  }

  Widget _applicantActions(BuildContext context, JobApplicant applicant) {
    const padding = EdgeInsets.symmetric(vertical: AppSizes.spaceSmall);
    const shape = RoundedRectangleBorder(borderRadius: AppRadius.smallCircular);

    // Yanıt beklenirken bütün butonlar kapanıyor: aynı başvuru iki kez
    // yanıtlanırsa sunucu 400 döndürüyor.
    final isBusy = _respondingApplicationId != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isBusy ? null : () => _reject(applicant),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: shape,
              padding: padding,
              textStyle: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Reddet'),
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: ElevatedButton(
            onPressed: isBusy ? null : () => _approve(applicant),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: context.onAccentColor,
              elevation: 0,
              shape: shape,
              padding: padding,
              textStyle: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Onayla'),
          ),
        ),
      ],
    );
  }

  /// Reddetme gerekçesini soran kutu.
  ///
  /// Gerekçe isteğe bağlı: backend `rejectionReason`'ı zorunlu tutmuyor ve
  /// boş bırakan işvereni engellemenin bir karşılığı yok.
  @override
  Future<String?> _askRejectionReason(JobApplicant applicant) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text(
          'Başvuruyu reddet',
          style: dialogContext.textTheme.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${applicant.fullName} adlı adayın başvurusu reddedilecek.',
              style: dialogContext.textTheme.bodyMedium?.copyWith(
                color: dialogContext.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: 'Gerekçe (isteğe bağlı)',
              controller: controller,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------- Geçmiş işler: yapan kişi

  Widget _workerSection(BuildContext context, JobApplicant? worker) {
    if (worker == null) {
      return _emptyPanel(
        context,
        icon: AppIcons.user,
        title: 'Yapan kişi bilgisi yok',
      );
    }

    final jobTitle = worker.jobTitle;

    return GestureDetector(
      onTap: () => context.push('/business/user-profile', extra: worker),
      child: Container(
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.06),
          borderRadius: AppRadius.innerCircular,
          border: Border.all(color: context.accentColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            ProfileAvatar(
              imageUrl: worker.profilePictureUrl,
              size: BJobDetailPageModel._workerAvatar,
            ),
            const SizedBox(width: AppSizes.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.fullName, style: context.textTheme.titleSmall),
                  if (jobTitle != null) ...[
                    const SizedBox(height: AppSizes.smallGap),
                    Text(jobTitle, style: context.textTheme.bodySmall),
                  ],
                  const SizedBox(height: AppSizes.spaceTiny),
                  _badge(
                    context,
                    color: AppColors.success,
                    child: Text(
                      'Başvurusu Kabul Edildi',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.successStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.accentColor,
              size: AppSizes.icon,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- Ortak parçalar

  BoxDecoration _panelDecoration(BuildContext context) => BoxDecoration(
    color: context.tileColor,
    borderRadius: AppRadius.innerCircular,
  );

  Widget _emptyPanel(
    BuildContext context, {
    required AppIconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spaceXLarge),
      decoration: _panelDecoration(context),
      child: Column(
        children: [
          AppIcon(icon, size: AppSizes.iconLarge, color: context.dividerColor),
          const SizedBox(height: AppSizes.space),
          Text(
            title,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              subtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: context.textTheme.titleMedium);
}
