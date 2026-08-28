import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'my_jobs_pagemodel.dart';

class MyJobsPage extends StatefulWidget {
  const MyJobsPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: MyAppbar(title: 'İşlerim', showBackButton: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Elde hiç iş yokken hata varsa boş liste değil hata gösterilmeli;
    // kullanıcı "hiç işim yok" ile "yüklenemedi"yi ayırt edebilmeli.
    final error = errorMessage;
    if (error != null && allJobs.isEmpty) {
      return Scaffold(
        appBar: MyAppbar(title: 'İşlerim', showBackButton: false),
        body: _errorState(error),
      );
    }

    final appliedJobs = context.watch<ApplyProvider>().appliedJobs;

    final pendingJobs = jobsByStatus(
      MyJobStatus.pending,
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
    final pastJobs = jobsByStatus(MyJobStatus.past, extraJobs: appliedJobs);

    return Scaffold(
      appBar: MyAppbar(title: 'İşlerim', showBackButton: false),
      body: RefreshIndicator(
        onRefresh: reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: AppPadding.primaryHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (pastJobs.isNotEmpty) _pastJobsSection(pastJobs),
                const SizedBox(height: AppSizes.navBarClearance),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// İşler çekilemediğinde: mesaj ve tekrar deneme.
  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        itemBuilder: (job) => _jobTile(job, AppColors.onAccent),
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
        itemBuilder: (job) => _jobTile(job, context.textPrimary),
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
          alreadyReviewed: reviewProvider.hasReviewed(job.id),
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
          job.description,
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

  Widget _jobTile(MyJob job, Color foreground) {
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
    );
  }

  Widget _completedTile(MyJob job, {required bool alreadyReviewed}) {
    final foreground = context.textPrimary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSizes.spaceTiny),
      title: _tileTitle(job.title, foreground),
      subtitle: _tileSubtitle(job, foreground),
      trailing: alreadyReviewed
          ? _reviewedBadge()
          : SizedBox(
              height: _inlineButtonHeight,
              child: ElevatedButton(
                onPressed: () => context.push('/review', extra: job),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
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
            '₺${job.price.toStringAsFixed(0)}',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.successStrong,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(job.date, style: context.textTheme.labelMedium),
              const SizedBox(width: AppSizes.spaceTiny),
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: AppSizes.iconSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
