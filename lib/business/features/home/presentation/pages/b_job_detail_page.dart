import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class BJobDetailPage extends StatelessWidget {
  final String jobId;

  const BJobDetailPage({super.key, required this.jobId});

  /// Rozet zeminlerinin opaklığı.
  static const double _tintAlpha = 0.12;

  /// Detay satırındaki etiket sütununun genişliği; değerler hizalı dursun
  /// diye sabit.
  static const double _detailLabelWidth = 80;

  /// Başvuran satırındaki avatar.
  static const double _applicantAvatar = 48;

  /// Geçmiş işi yapan kişinin avatarı; başvuranınkinden büyük çünkü tek
  /// başına duruyor.
  static const double _workerAvatar = 56;

  @override
  Widget build(BuildContext context) {
    final bJobsProvider = context.watch<BJobsProvider>();
    final applyProvider = context.watch<ApplyProvider>();

    // Senkronize et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bJobsProvider.syncApplicantsFromApplyProvider(applyProvider);
    });

    final post = bJobsProvider.getPostByJobId(jobId);

    if (post == null) {
      return Scaffold(
        appBar: MyAppbar(title: "İlan Detayı"),
        body: Center(
          child: Text('İlan bulunamadı', style: context.textTheme.titleSmall),
        ),
      );
    }

    final job = post.job;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: "İlan Detayı"),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _jobInfoCard(context, post),
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
                      style: context.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceLarge),
                  ],
                  _sectionTitle(context, "Detaylar"),
                  const SizedBox(height: AppSizes.space),
                  _detailsCard(context, post),
                  const SizedBox(height: AppSizes.spaceLarge),
                  // Geçmiş iş → Yapan Kişi, Aktif iş → Başvuranlar
                  if (!post.isActive) ...[
                    _sectionTitle(context, "Yapan Kişi"),
                    const SizedBox(height: AppSizes.space),
                    _workerSection(context, post),
                  ] else ...[
                    _sectionTitle(
                      context,
                      "Başvuranlar (${post.applicants.length})",
                    ),
                    const SizedBox(height: AppSizes.space),
                    _applicantsList(context, post),
                  ],
                  const SizedBox(height: AppSizes.navBarClearance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- İlan kartı

  Widget _jobInfoCard(BuildContext context, BJobPost post) {
    final job = post.job;

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
          Row(
            children: [
              _categoryBadge(context, job),
              const SizedBox(width: AppSizes.spaceSmall),
              _statusBadge(context, isActive: post.isActive),
              const SizedBox(width: AppSizes.spaceSmall),
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
        color: color.withValues(alpha: _tintAlpha),
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

  Widget _statusBadge(BuildContext context, {required bool isActive}) {
    return _badge(
      context,
      color: isActive ? AppColors.success : context.textTertiary,
      child: Text(
        isActive ? 'Aktif' : 'Geçmiş',
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.successStrong : context.textSecondary,
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
        Text(job.addressLabel ?? 'Ankara', style: context.textTheme.bodyMedium),
      ],
    );
  }

  // ---------------------------------------------------------------- Detaylar

  Widget _detailsCard(BuildContext context, BJobPost post) {
    final job = post.job;

    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration(context),
      child: Column(
        children: [
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
            job.experienceRequired == true ? 'Gerekli' : 'Gerekli Değil',
          ),
          _detailRow(
            context,
            AppIcons.shield,
            'Sigorta',
            job.insuranceRequired == true ? 'Gerekli' : 'Gerekli Değil',
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
            width: _detailLabelWidth,
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

  Widget _applicantsList(BuildContext context, BJobPost post) {
    if (post.applicants.isEmpty) {
      return _emptyPanel(
        context,
        icon: AppIcons.userMultiple,
        title: 'Henüz başvuru yok',
        subtitle: 'Başvurular geldiğinde burada görünecek',
      );
    }

    return Column(
      children: [
        for (final applicant in post.applicants)
          _applicantCard(context, post, applicant),
      ],
    );
  }

  Widget _applicantCard(
    BuildContext context,
    BJobPost post,
    BApplicant applicant,
  ) {
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
                _avatar(applicant.profileImage, _applicantAvatar),
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
                      Text(
                        applicant.jobTitle,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  applicant.appliedDate,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (applicant.coverLetter != null) ...[
            const SizedBox(height: AppSizes.space),
            Container(
              width: double.infinity,
              padding: AppPadding.card,
              decoration: BoxDecoration(
                color: context.tileColor,
                borderRadius: AppRadius.smallCircular,
              ),
              child: Text(
                applicant.coverLetter!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.space),
          _applicantActions(context, post, applicant),
        ],
      ),
    );
  }

  Widget _applicantActions(
    BuildContext context,
    BJobPost post,
    BApplicant applicant,
  ) {
    const padding = EdgeInsets.symmetric(vertical: AppSizes.spaceSmall);
    const shape = RoundedRectangleBorder(borderRadius: AppRadius.smallCircular);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              context.read<BJobsProvider>().rejectApplicant(
                post.job.id,
                applicant.id,
              );
              AppToast.error(context, '${applicant.fullName} reddedildi');
            },
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
            onPressed: () {
              context.read<BJobsProvider>().approveApplicant(
                post.job.id,
                applicant,
              );
              AppToast.success(context, '${applicant.fullName} onaylandı!');
            },
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

  // --------------------------------------------- Geçmiş işler: yapan kişi

  Widget _workerSection(BuildContext context, BJobPost post) {
    final worker = post.worker;

    if (worker == null) {
      return _emptyPanel(
        context,
        icon: AppIcons.user,
        title: 'Yapan kişi bilgisi yok',
      );
    }

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
            _avatar(
              worker.profileImage,
              _workerAvatar,
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            const SizedBox(width: AppSizes.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.fullName, style: context.textTheme.titleSmall),
                  const SizedBox(height: AppSizes.smallGap),
                  Text(worker.jobTitle, style: context.textTheme.bodySmall),
                  const SizedBox(height: AppSizes.spaceTiny),
                  _badge(
                    context,
                    color: AppColors.success,
                    child: Text(
                      'İşi Tamamladı',
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

  Widget _avatar(String imagePath, double size, {BoxBorder? border}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadius.innerCircular,
        border: border,
        image: DecorationImage(fit: BoxFit.cover, image: AssetImage(imagePath)),
      ),
    );
  }

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
