import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/widgets/messaging_gate_note.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/business/core/load_result.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/models/b_payment_attempt.dart';
import 'package:koala/business/features/home/models/b_pricing_breakdown.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/widgets/b_job_gallery_section.dart';
import 'package:koala/business/features/home/presentation/widgets/b_talent_pool_button.dart';
import 'package:koala/business/features/home/presentation/widgets/b_payment_attempts_section.dart';
import 'package:koala/business/features/home/presentation/widgets/b_pricing_breakdown_card.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/business/features/home/services/b_payment_browser.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/review_state_row.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/account/account_navigation.dart';
import 'package:koala/product/features/account/models/address_required_error_codes.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

part 'b_job_detail_pagemodel.dart';

/// İşverenin kendi ilanının detayı ve o ilana gelen başvurular.
///
/// İki kaynaktan besleniyor: ilanın kendisi `GET /jobs/{id}`'den, başvurular
/// [BJobsProvider] üzerinden `GET /jobs/{id}/applications`'tan.
class BJobDetailPage extends StatefulWidget {
  const BJobDetailPage({
    super.key,
    required this.jobId,
    this.jobService,
    this.employerJobService,
    this.assignmentService,
    this.paymentService,
    this.paymentBrowser,
    this.galleryProvider,
    this.chatService,
    this.openExternalUrl,
  });

  final String jobId;
  final JobService? jobService;
  final EmployerJobService? employerJobService;
  final AssignmentService? assignmentService;
  final BPaymentService? paymentService;
  final BPaymentBrowser? paymentBrowser;
  final JobGalleryProvider? galleryProvider;

  /// Testler için; verilmezse üretimdeki tekil servis.
  final ChatService? chatService;

  /// Özgeçmiş bağlantısını açan kapı; verilmezse harici tarayıcı
  /// (`url_launcher`). Testler sahte bir açıcı geçiyor.
  final Future<bool> Function(Uri url)? openExternalUrl;

  @override
  State<BJobDetailPage> createState() => _BJobDetailPageState();
}

class _BJobDetailPageState extends BJobDetailPageModel {
  @override
  Widget build(BuildContext context) {
    final jobsProvider = context.watch<BJobsProvider>();
    final post = jobsProvider.getPostByJobId(widget.jobId);
    final company = context.watch<BCompanyProvider>().company;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: "İlan Detayı",
        actions: [?_saveAsTemplateAction()],
      ),
      body: _body(
        post,
        companyImages: company?.images ?? const [],
        jobsError: jobsProvider.errorMessage,
        jobsLoading: jobsProvider.isLoading,
        jobsHaveLoaded: jobsProvider.hasLoaded,
      ),
    );
  }

  Widget _body(
    BJobPost? post, {
    required List<GalleryImage> companyImages,
    required String? jobsError,
    required bool jobsLoading,
    required bool jobsHaveLoaded,
  }) {
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
    final isActive = job.status == JobStatus.open;

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
                BJobGallerySection(
                  jobId: widget.jobId,
                  canManage: post != null,
                  companyImages: job.company == null ? const [] : companyImages,
                  provider: widget.galleryProvider,
                ),
                const SizedBox(height: AppSizes.spaceLarge),
                _sectionTitle(context, "Detaylar"),
                const SizedBox(height: AppSizes.space),
                _detailsCard(context, job),
                const SizedBox(height: AppSizes.spaceLarge),
                ..._timesheetSection(),
                ..._peopleSection(
                  post,
                  isActive: isActive,
                  jobsError: jobsError,
                  jobsLoading: jobsLoading,
                  jobsHaveLoaded: jobsHaveLoaded,
                ),
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
    if (assignment == null) {
      if (_hasLoadedAssignments &&
          !_isAssignmentLoading &&
          _assignmentLoadError == null) {
        return const [];
      }
      return [
        _sectionTitle(context, 'İş Takibi'),
        const SizedBox(height: AppSizes.space),
        _assignmentLoadStatePanel(),
        const SizedBox(height: AppSizes.spaceLarge),
      ];
    }

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
            if (!_isAssignmentStateVerified) ...[
              _assignmentLoadStatePanel(),
              const SizedBox(height: AppSizes.spaceMedium),
            ],
            if (_assignments.length > 1) ...[
              Text('Çalışan seç', style: context.textTheme.labelMedium),
              const SizedBox(height: AppSizes.spaceTiny),
              DropdownButton<String>(
                key: const ValueKey('assignment-selector'),
                value: assignment.id,
                isExpanded: true,
                items: [
                  for (var index = 0; index < _assignments.length; index++)
                    DropdownMenuItem(
                      value: _assignments[index].id,
                      child: Text(
                        _assignments[index].worker?.fullName.isNotEmpty == true
                            ? _assignments[index].worker!.fullName
                            : 'Çalışan ${index + 1}',
                      ),
                    ),
                ],
                onChanged:
                    _isRunningAssignmentAction || !_isAssignmentListVerified
                    ? null
                    : (id) {
                        if (id != null) unawaited(_selectAssignment(id));
                      },
              ),
              const SizedBox(height: AppSizes.space),
            ],
            _assignmentStatusRow(assignment),
            const SizedBox(height: AppSizes.spaceSmall),
            _assignmentTimelineRow(assignment),
            if (_workSessions.isNotEmpty) ...[
              const SizedBox(height: AppSizes.space),
              ..._workSessions.map(_workSessionRow),
              const SizedBox(height: AppSizes.spaceSmall),
              _totalWorkedRow(),
            ] else if (_workSessionsError == null) ...[
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                'Çalışan henüz mesai başlatmadı.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
            ?_openDisputeBanner(),
            if (!_isDisputeStateVerified) ...[
              const SizedBox(height: AppSizes.spaceMedium),
              _disputeStatePanel(assignment),
            ],
            if (assignment.needsEmployerPayment) ...[
              const SizedBox(height: AppSizes.spaceMedium),
              if (_canStartPayment)
                _paymentButton()
              else
                _paymentPendingPanel(),
            ],
            if (_canCompleteAssignment(assignment)) ...[
              const SizedBox(height: AppSizes.spaceMedium),
              _completeButton(),
            ],
            if (_canReviewWorker(assignment)) ...[
              const SizedBox(height: AppSizes.spaceMedium),
              _reviewRow(assignment),
            ],
            ..._assignmentActions(assignment),
          ],
        ),
      ),
      const SizedBox(height: AppSizes.spaceLarge),
      _sectionTitle(context, 'Ödeme Denemeleri'),
      const SizedBox(height: AppSizes.space),
      BPaymentAttemptsSection(
        attempts: _paymentAttempts,
        isLoading: _arePaymentAttemptsLoading,
        errorMessage: _paymentAttemptsError,
        onRetry: () => _loadPaymentAttempts(),
      ),
      const SizedBox(height: AppSizes.spaceLarge),
    ];
  }

  Widget _assignmentLoadStatePanel() {
    final error = _isAssignmentLoading ? null : _assignmentSnapshotError;
    return Container(
      key: error == null
          ? const ValueKey('assignment-loading')
          : const ValueKey('assignment-load-error'),
      width: double.infinity,
      padding: AppPadding.card,
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              error ?? 'Atama bilgileri güncelleniyor.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          if (error != null)
            TextButton(
              key: const ValueKey('retry-assignment-load'),
              onPressed: _loadAssignment,
              child: const Text('Tekrar Dene'),
            ),
        ],
      ),
    );
  }

  Widget _disputeStatePanel(Assignment assignment) {
    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _areDisputesLoading
                  ? 'Uyuşmazlık durumu kontrol ediliyor.'
                  : 'Uyuşmazlık durumu doğrulanamadı.',
            ),
          ),
          if (!_areDisputesLoading)
            TextButton(
              onPressed: () => _loadDisputes(assignment.id),
              child: const Text('Yenile'),
            ),
        ],
      ),
    );
  }

  Widget _paymentPendingPanel() {
    final message = _arePaymentAttemptsLoading
        ? 'Ödeme denemeleri kontrol ediliyor.'
        : _paymentAttemptsError != null
        ? 'Ödeme durumu doğrulanamadı. Yeni ödeme başlatmadan önce yenile.'
        : 'Ödeme sonucu doğrulanıyor.';

    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          if (!_arePaymentAttemptsLoading)
            TextButton(
              onPressed: () => _loadPaymentAttempts(),
              child: const Text('Yenile'),
            ),
        ],
      ),
    );
  }

  Widget _paymentButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        key: const ValueKey('start-payment'),
        onPressed: _isStartingPayment ? null : _requestPayment,
        icon: _isStartingPayment
            ? const SizedBox.square(
                dimension: AppSizes.iconSmall,
                child: CircularProgressIndicator(
                  strokeWidth: BJobDetailPageModel._spinnerStroke,
                ),
              )
            : const AppIcon(AppIcons.shield, size: AppSizes.iconSmall),
        label: const Text('Güvenli Ödemeyi Tamamla'),
      ),
    );
  }

  @override
  Future<bool?> _confirmPayment(BPricingBreakdown breakdown) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text(
          'Ödemeyi Onayla',
          style: dialogContext.textTheme.titleMedium,
        ),
        content: SingleChildScrollView(
          child: BPricingBreakdownCard(breakdown: breakdown),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ödemeye geç'),
          ),
        ],
      ),
    );
  }

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

  /// Atamanın zaman çizelgesi tek satırda: başvuru, kabul, ödeme durumu ve
  /// tamamlanma.
  ///
  /// Damgalar `MyAssignmentDto`'nun koala-backend#282 alanları
  /// ([Assignment.application], [Assignment.paymentSecuredAt],
  /// [Assignment.payout]); göndermeyen sunucuda değerin yerine "—" yazılıyor
  /// ki satırın hangi bilgiyi taşıdığı yine okunsun. Kabul anı sözleşmedeki
  /// gibi başvurunun `answeredDateTime`'ı. Ödeme sütunu durumun metniyle
  /// birlikte emanete alınma anını, para çalışana geçtiyse hesaba ulaştığı
  /// anı söylüyor.
  Widget _assignmentTimelineRow(Assignment assignment) {
    final application = assignment.application;
    final securedAt = assignment.paymentSecuredAt;
    final paidOutAt = assignment.payout?.completedAt;
    final paymentDetail = assignment.paymentStatus.isPaid && paidOutAt != null
        ? ' (hesaba geçti: ${paidOutAt.toLocal().asShortDateTime})'
        : securedAt != null
        ? ' (emanete alındı: ${securedAt.toLocal().asShortDateTime})'
        : '';

    return Text(
      'Başvuru: ${_stamp(application?.applicationDateTime)}'
      ' · Kabul: ${_stamp(application?.answeredDateTime)}'
      ' · Ödeme: ${assignment.paymentStatus.displayName}$paymentDetail'
      ' · Tamamlandı: ${_stamp(assignment.actualCompletionDateTime)}',
      key: const ValueKey('assignment-timeline'),
      style: context.textTheme.bodySmall?.copyWith(
        color: context.textSecondary,
        height: BJobDetailPageModel._multilineHeight,
      ),
    );
  }

  /// Zaman damgasının satırdaki hâli; yoksa "—".
  static String _stamp(DateTime? value) =>
      value?.toLocal().asShortDateTime ?? '—';

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
    final canCancel = _canCompleteAssignment(assignment);
    final canDispute = _canOpenDisputeFor(assignment);

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

  /// Değerlendirme: tamamlanmış atamada durum ve düğme.
  ///
  /// Çalışan kabuğundaki `WorkDetailPage._reviewCard`'ın işveren karşılığı;
  /// aynı [ReviewStateRow]. "Değerlendirdim mi" sunucudan (`myReview`),
  /// içerik de oradan; [ReviewProvider] yalnız az önce gönderilenin boşluğunu
  /// dolduruyor. Çalışan işvereni değerlendirdiyse küçük rozet.
  Widget _reviewRow(Assignment assignment) {
    final reviews = context.watch<ReviewProvider>();

    return KeyedSubtree(
      key: const ValueKey('assignment-review'),
      child: ReviewStateRow(
        ownReview: reviews.ownReviewFor(assignment),
        hasReviewed: reviews.hasReviewed(assignment),
        counterpartyReviewed: assignment.counterpartyReviewed,
        pendingText: 'Çalışanı henüz değerlendirmediniz.',
        buttonLabel: 'Çalışanı Değerlendirin',
        buttonKey: const ValueKey('assignment-review-button'),
        onReview: _isRunningAssignmentAction
            ? null
            : () => _reviewWorker(assignment),
      ),
    );
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
            height: BJobDetailPageModel._multilineHeight,
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
  List<Widget> _peopleSection(
    BJobPost? post, {
    required bool isActive,
    required String? jobsError,
    required bool jobsLoading,
    required bool jobsHaveLoaded,
  }) {
    final sectionTitle = isActive ? 'Başvuranlar' : 'Yapan Kişi';
    if (post == null) {
      return [
        _sectionTitle(context, sectionTitle),
        const SizedBox(height: AppSizes.space),
        if (jobsError != null)
          _applicantsErrorPanel(jobsError)
        else if (jobsLoading || !jobsHaveLoaded)
          const Center(child: CircularProgressIndicator())
        else
          _applicantsErrorPanel('Başvuran bilgisi bu ilan için alınamadı'),
      ];
    }

    final errorMessage = post.applicantsError;
    if (!post.applicantsLoaded && errorMessage == null) {
      return [
        _sectionTitle(context, sectionTitle),
        const SizedBox(height: AppSizes.space),
        const Center(child: CircularProgressIndicator()),
      ];
    }

    if (!post.applicantsLoaded) {
      return [
        _sectionTitle(context, sectionTitle),
        const SizedBox(height: AppSizes.space),
        _applicantsErrorPanel(errorMessage!),
      ];
    }

    if (!isActive) {
      return [
        _sectionTitle(context, sectionTitle),
        const SizedBox(height: AppSizes.space),
        if (errorMessage != null) ...[
          _applicantsErrorPanel(errorMessage),
          const SizedBox(height: AppSizes.space),
        ],
        if (post.worker != null || errorMessage == null)
          _workerSection(context, post.worker),
      ];
    }

    final accepted = post.acceptedApplicants;
    // Geri çekilen ve durumu tanınmayan başvurular da bu listede: sunucu
    // kaydı silmiyor ve işverenin listesinde tutuyor. Kartları çiziliyor,
    // yalnızca kabul/ret butonları çıkmıyor.
    final unanswered = post.unansweredApplicants;

    return [
      if (errorMessage != null) ...[
        _applicantsErrorPanel(errorMessage),
        const SizedBox(height: AppSizes.spaceLarge),
      ],
      if (accepted.isNotEmpty) ...[
        _sectionTitle(context, "Onaylananlar (${accepted.length})"),
        const SizedBox(height: AppSizes.space),
        for (final applicant in accepted)
          _applicantCard(context, applicant, isAccepted: true),
        const SizedBox(height: AppSizes.spaceLarge),
      ],
      if (unanswered.isNotEmpty || errorMessage == null) ...[
        _sectionTitle(context, "Başvuranlar (${unanswered.length})"),
        const SizedBox(height: AppSizes.space),
        _applicantsList(
          context,
          unanswered,
          hasAccepted: accepted.isNotEmpty,
          canRespond: errorMessage == null && !post.applicantsLoading,
        ),
      ],
    ];
  }

  Widget _applicantsErrorPanel(String message) {
    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: context.textTheme.bodyMedium),
          const SizedBox(height: AppSizes.spaceSmall),
          OutlinedButton(
            key: const ValueKey('applicants-retry'),
            onPressed: _retryApplicants,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
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
    final isLive = status == JobStatus.open;
    final color = switch (status) {
      JobStatus.open => AppColors.success,
      JobStatus.cancelled => AppColors.danger,
      _ => context.textTertiary,
    };

    return _labelBadge(
      context,
      label: status.displayName,
      tint: color,
      textColor: isLive ? color : context.textSecondary,
    );
  }

  /// Renkli zemin üstünde kalın, küçük bir etiket taşıyan rozet.
  ///
  /// İlanın ve başvurunun durum rozetleri aynı biçimi kuruyordu; ikisi de
  /// buradan geçiyor ki bir gün biçim değişirse tek yerde değişsin.
  Widget _labelBadge(
    BuildContext context, {
    required String label,
    required Color tint,
    required Color textColor,
  }) {
    return _badge(
      context,
      color: tint,
      child: Text(
        label,
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
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
    bool canRespond = true,
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
        for (final applicant in applicants)
          _applicantCard(context, applicant, canRespond: canRespond),
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
    bool canRespond = true,
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
                context.push(BusinessRoutes.userProfile, extra: applicant),
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
                BTalentPoolButton(
                  worker: applicant.user,
                  iconSize: AppSizes.iconSmall,
                ),
                _applicantDates(context, applicant),
              ],
            ),
          ),
          if (applicant.hasCv) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _applicantCvLink(context, applicant),
          ],
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
          ..._applicantMessaging(context, applicant),
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
          // Butonlar başvurunun durumuna bakıyor, yalnızca [isAccepted]
          // bayrağına değil: geri çekilmiş ya da durumu tanınmayan bir
          // başvuruya basmak sunucudan `409` getirirdi. Bekleyenler listesi
          // zaten süzüyor, bu kartın kendi güvencesi.
          else if (applicant.isPending)
            _applicantActions(context, applicant, enabled: canRespond)
          else
            _applicationStatusBadge(context, applicant.status),
        ],
      ),
    );
  }

  /// Kartın sağ üst köşesindeki tarihler: başvuru ve — sunucu gönderiyorsa —
  /// yanıt anı. Kabul edilen kartta yanıt kabul tarihidir.
  Widget _applicantDates(BuildContext context, JobApplicant applicant) {
    final answeredAt = applicant.answeredDateTime;
    final style = context.textTheme.labelMedium?.copyWith(
      color: context.textTertiary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(applicant.applicationDateTime?.asShortDate ?? '', style: style),
        if (answeredAt != null)
          Text(
            '${applicant.status == ApplicationStatus.accepted ? 'Kabul' : 'Yanıt'}: '
            '${answeredAt.toLocal().asShortDate}',
            key: ValueKey('applicant-answered-${applicant.id}'),
            style: style,
          ),
      ],
    );
  }

  /// Özgeçmiş bağlantısı. Adres doğrudan dosya değil, sunucunun sahipliği
  /// doğrulayıp kısa ömürlü imzalı adrese yönlendirdiği bir yol; profil
  /// ekranıyla aynı biçimde harici tarayıcıda açılıyor.
  Widget _applicantCvLink(BuildContext context, JobApplicant applicant) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: ValueKey('applicant-cv-${applicant.id}'),
        onPressed: () => _openCv(applicant),
        style: TextButton.styleFrom(
          padding: AppPadding.badge,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const AppIcon(AppIcons.fileText, size: AppSizes.iconSmall),
        label: const Text('Özgeçmişi Görüntüle'),
      ),
    );
  }

  /// Adayla mesajlaşma: düğme ya da düğmenin yerine geçen açıklama.
  ///
  /// Kapı adayın bu ilandaki atamasından okunuyor (`messagingAvailable`).
  /// **Atama yoksa hiçbir şey çizilmiyor**: bekleyen, reddedilen ya da geri
  /// çekilen başvuranla mesajlaşma yolu yok ve "ödemeyi tamamlayınca açılır"
  /// demek işverene ödenecek bir şey varmış gibi yanlış bir vaat olurdu.
  /// Atama varken ödeme bekleniyorsa açıklama, atama ödenebilir durumdaysa
  /// yanında ödeme akışına kısayol; pencere kapandıysa yalnızca "Bu sohbet
  /// kapandı". Atama listesi ilk kez yüklenirken de hiçbir şey çizilmiyor:
  /// bir an "ödeme bekleniyor" deyip hemen düğmeye dönmek yanlış bir
  /// izlenim bırakırdı.
  List<Widget> _applicantMessaging(
    BuildContext context,
    JobApplicant applicant,
  ) {
    if (_isAssignmentLoading && !_hasLoadedAssignments) return const [];

    final assignment = _assignmentOf(applicant);
    if (assignment == null) return const [];

    final messaging = assignment.messaging;
    final note = messaging.noteFor(asEmployer: true);

    if (note == null) {
      return [
        const SizedBox(height: AppSizes.space),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: ValueKey('applicant-chat-${applicant.user.id}'),
            onPressed: _openingChatUserId != null
                ? null
                : () => _openChat(applicant),
            icon: _openingChatUserId == applicant.user.id
                ? const SizedBox.square(
                    dimension: AppSizes.iconSmall,
                    child: CircularProgressIndicator(
                      strokeWidth: BJobDetailPageModel._spinnerStroke,
                    ),
                  )
                : const AppIcon(AppIcons.chat, size: AppSizes.iconSmall),
            label: const Text('Mesaj Gönder'),
          ),
        ),
        const SizedBox(height: AppSizes.spaceSmall),
      ];
    }

    final canPay = messaging.needsPayment && assignment.needsEmployerPayment;

    return [
      const SizedBox(height: AppSizes.space),
      MessagingGateNote(
        key: ValueKey('applicant-chat-note-${applicant.user.id}'),
        message: note,
        action: canPay
            ? TextButton(
                key: ValueKey('applicant-pay-${applicant.user.id}'),
                onPressed: _isStartingPayment
                    ? null
                    : () => _openPaymentFor(assignment),
                child: const Text('Ödemeye Git'),
              )
            : null,
      ),
      const SizedBox(height: AppSizes.spaceSmall),
    ];
  }

  /// Yanıtlanamayan bir başvurunun durumunu yazan nötr rozet.
  ///
  /// Kabul rozetinin yeşili yalnızca kabule ait; reddedilen ya da geri
  /// çekilen başvuruyu aynı renkle çizmek yanlış bilgi olurdu.
  Widget _applicationStatusBadge(
    BuildContext context,
    ApplicationStatus status,
  ) {
    return _labelBadge(
      context,
      label: status.displayName,
      tint: context.textTertiary,
      textColor: context.textSecondary,
    );
  }

  Widget _applicantActions(
    BuildContext context,
    JobApplicant applicant, {
    required bool enabled,
  }) {
    const padding = EdgeInsets.symmetric(vertical: AppSizes.spaceSmall);
    const shape = RoundedRectangleBorder(borderRadius: AppRadius.smallCircular);

    // Yanıt beklenirken bütün butonlar kapanıyor: aynı başvuru iki kez
    // yanıtlanırsa sunucu 400 döndürüyor.
    final isBusy = !enabled || _respondingApplicationId != null;

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
      onTap: () => context.push(BusinessRoutes.userProfile, extra: worker),
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
