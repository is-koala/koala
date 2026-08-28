import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/fake_business_company.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

class BHomePage extends StatelessWidget {
  const BHomePage({super.key});

  /// Appbar'ın yüksekliği; iki satırlık marka bloğunu taşıyor.
  static const double _appBarHeight = 70;

  /// Appbar'daki logo kutusu.
  static const double _appBarLogo = 42;

  /// Karşılama bloğundaki maskot kutusu ve görseli.
  static const double _mascotBox = 72;
  static const double _mascotImage = 56;

  /// İstatistik ve satır kartlarındaki ikon kutuları.
  static const double _statIconBox = 40;
  static const double _rowIconBox = 44;

  /// Rozet ve kart zeminlerinin opaklıkları.
  static const double _tintAlpha = 0.12;
  static const double _panelAlpha = 0.08;

  /// Karşılama bloğu üzerindeki içeriğin opaklıkları.
  static const double _onCoverMuted = 0.9;
  static const double _onCoverSurface = 0.2;

  /// Ana sayfada listelenen en fazla kayıt sayısı; devamı ilgili sekmede.
  static const int _previewCount = 3;

  /// Navbar'ın altında kalmasın diye sayfanın sonuna eklenen pay.
  static const double _bottomClearance = 120;

  @override
  Widget build(BuildContext context) {
    final company = FakeBusinessCompany.instance;
    final bJobsProvider = context.watch<BJobsProvider>();
    final activePosts = bJobsProvider.activePosts;
    final pastPosts = bJobsProvider.pastPosts;
    final totalApplicants = activePosts.fold<int>(
      0,
      (sum, post) => sum + post.applicants.length,
    );

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _appBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppPadding.primaryHorizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSizes.spaceSmall),
                  _welcomeBanner(context, company.name),
                  const SizedBox(height: AppSizes.spaceLarge),
                  _statsRow(
                    context,
                    activeCount: activePosts.length,
                    pastCount: pastPosts.length,
                    applicantCount: totalApplicants,
                  ),
                  const SizedBox(height: AppSizes.spaceXLarge),
                  _recentApplicantsSection(context, bJobsProvider),
                  const SizedBox(height: AppSizes.spaceXLarge),
                  _activePostsSection(context, activePosts),
                  const SizedBox(height: _bottomClearance),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ AppBar

  SliverAppBar _appBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: context.backgroundColor,
      surfaceTintColor: context.backgroundColor,
      elevation: 0,
      toolbarHeight: _appBarHeight,
      title: Row(
        children: [
          Container(
            width: _appBarLogo,
            height: _appBarLogo,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: _tintAlpha),
              borderRadius: AppRadius.innerCircular,
            ),
            child: ClipRRect(
              borderRadius: AppRadius.innerCircular,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.spaceTiny),
                child: Image.asset(AppAssets.koalaLogo, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KOALA',
                style: context.textTheme.titleLarge?.copyWith(
                  color: context.accentColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'İşveren Paneli',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/business/notifications'),
          icon: Badge(
            smallSize: AppSizes.badgeDot,
            backgroundColor: AppColors.danger,
            child: AppIcon(
              AppIcons.notification,
              color: context.textSecondary,
              size: AppSizes.icon,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spaceTiny),
      ],
    );
  }

  // -------------------------------------------------------- Karşılama bloğu

  /// Zemin marka yeşili bir gradyan; üstündeki her şey temadan bağımsız beyaz.
  Widget _welcomeBanner(BuildContext context, String companyName) {
    return Container(
      width: double.infinity,
      padding: AppPadding.sheet,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor,
            AppColors.primaryColor.withValues(alpha: 0.8),
            AppColors.primaryDeep,
          ],
        ),
        borderRadius: AppRadius.secondaryCircular,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoş geldin! 👋',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onAccent.withValues(alpha: _onCoverMuted),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceTiny),
                Text(
                  companyName,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                ),
                const SizedBox(height: AppSizes.space),
                _approvedBadge(context),
              ],
            ),
          ),
          _mascot(context),
        ],
      ),
    );
  }

  Widget _approvedBadge(BuildContext context) {
    final muted = AppColors.onAccent.withValues(alpha: _onCoverMuted);

    return Container(
      padding: AppPadding.chip,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(alpha: _onCoverSurface),
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: AppSizes.iconSmall, color: muted),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            'Onaylı İşveren',
            style: context.textTheme.labelMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _mascot(BuildContext context) {
    return Container(
      width: _mascotBox,
      height: _mascotBox,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(alpha: _onCoverSurface),
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Center(
        child: Image.asset(
          AppAssets.koalaBusiness,
          width: _mascotImage,
          height: _mascotImage,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => AppIcon(
            AppIcons.building,
            size: AppSizes.iconLarge,
            color: AppColors.onAccent.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- İstatistikler

  Widget _statsRow(
    BuildContext context, {
    required int activeCount,
    required int pastCount,
    required int applicantCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            icon: AppIcons.work,
            label: 'Aktif İlan',
            value: '$activeCount',
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: _statCard(
            context,
            icon: AppIcons.userMultiple,
            label: 'Başvuru',
            value: '$applicantCount',
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: _statCard(
            context,
            icon: AppIcons.checkCircle,
            label: 'Tamamlanan',
            value: '$pastCount',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required AppIconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.spaceMedium,
        horizontal: AppSizes.space,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _panelAlpha),
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: _statIconBox,
            height: _statIconBox,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.innerCircular,
            ),
            child: AppIcon(icon, size: AppSizes.iconMedium, color: color),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            value,
            style: context.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: AppSizes.smallGap),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- Hızlı işlemler

  // Park edilmiş bölüm: tasarımı hazır ama henüz hiçbir yerden çağrılmıyor.
  // Silmek yerine ignore ediliyor; bağlanacağı akış netleşince kaldırılır.
  // ignore: unused_element
  Widget _quickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Hızlı İşlemler'),
        const SizedBox(height: AppSizes.space),
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                context,
                icon: AppIcons.plus,
                label: 'Yeni İlan',
                subtitle: 'İlan oluştur',
                color: context.accentColor,
                onTap: () => context.push('/business/create'),
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: _quickActionCard(
                context,
                icon: AppIcons.work,
                label: 'İlanlarım',
                subtitle: 'Tümünü gör',
                color: AppColors.info,
                onTap: () => context.go('/business/posts'),
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: _quickActionCard(
                context,
                icon: AppIcons.user,
                label: 'Profilim',
                subtitle: 'Düzenle',
                color: AppColors.warning,
                onTap: () => context.go('/business/profile'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionCard(
    BuildContext context, {
    required AppIconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.spaceMedium,
          horizontal: AppSizes.spaceSmall,
        ),
        decoration: _cardDecoration(context),
        child: Column(
          children: [
            Container(
              width: _rowIconBox,
              height: _rowIconBox,
              decoration: BoxDecoration(
                color: color.withValues(alpha: _tintAlpha),
                borderRadius: AppRadius.innerCircular,
              ),
              child: AppIcon(icon, size: AppSizes.iconMedium, color: color),
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.smallGap),
            Text(
              subtitle,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- Son başvurular

  Widget _recentApplicantsSection(
    BuildContext context,
    BJobsProvider provider,
  ) {
    // Tüm aktif ilanlardan son başvuranları topla
    final recentApplicants = [
      for (final post in provider.activePosts)
        for (final applicant in post.applicants)
          _RecentApplicant(applicant: applicant, post: post),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Son Başvurular'),
        const SizedBox(height: AppSizes.space),
        if (recentApplicants.isEmpty)
          _emptyPanel(
            context,
            icon: AppIcons.userMultiple,
            title: 'Henüz başvuru yok',
            subtitle: 'İlanlara başvuru geldiğinde burada görünecek',
          )
        else
          ...recentApplicants
              .take(_previewCount)
              .map((ra) => _recentApplicantCard(context, ra)),
      ],
    );
  }

  Widget _recentApplicantCard(BuildContext context, _RecentApplicant ra) {
    return GestureDetector(
      onTap: () => context.push('/business/job-detail', extra: ra.post.job.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
        padding: AppPadding.selectionCard,
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            Container(
              width: _rowIconBox,
              height: _rowIconBox,
              decoration: BoxDecoration(
                borderRadius: AppRadius.innerCircular,
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: AssetImage(ra.applicant.profileImage),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ra.applicant.fullName,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.smallGap),
                  Text(
                    ra.post.job.title,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _categoryBadge(context, ra.post.job),
            const SizedBox(width: AppSizes.spaceSmall),
            Icon(
              Icons.chevron_right,
              size: AppSizes.iconMedium,
              color: context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- Aktif ilanlar

  Widget _activePostsSection(BuildContext context, List<BJobPost> activePosts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          'Aktif İlanlar',
          action: activePosts.isEmpty
              ? null
              : GestureDetector(
                  onTap: () => context.go('/business/posts'),
                  child: Text(
                    'Tümünü Gör',
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.accentColor,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AppSizes.space),
        if (activePosts.isEmpty)
          _emptyPanel(
            context,
            icon: AppIcons.work,
            title: 'Aktif ilan yok',
            action: GestureDetector(
              onTap: () => context.push('/business/create'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppPadding.primary,
                  vertical: AppSizes.spaceSmall,
                ),
                decoration: BoxDecoration(
                  color: context.accentColor,
                  borderRadius: AppRadius.smallCircular,
                ),
                child: Text(
                  'Hemen İlan Oluştur',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.onAccentColor,
                  ),
                ),
              ),
            ),
          )
        else
          ...activePosts
              .take(_previewCount)
              .map((post) => _activePostCard(context, post)),
      ],
    );
  }

  Widget _activePostCard(BuildContext context, BJobPost post) {
    final job = post.job;

    return GestureDetector(
      onTap: () => context.push('/business/job-detail', extra: job.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.space),
        padding: AppPadding.primaryAll,
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _categoryBadge(context, job, withIcon: true),
                const SizedBox(width: AppSizes.spaceSmall),
                _activeBadge(context),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconMedium,
                  color: context.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space),
            Text(
              job.title,
              style: context.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              job.subtitle,
              style: context.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.space),
            _postFooterRow(context, post),
          ],
        ),
      ),
    );
  }

  Widget _postFooterRow(BuildContext context, BJobPost post) {
    final job = post.job;
    final hasApplicants = post.applicants.isNotEmpty;
    final applicantColor = hasApplicants
        ? AppColors.info
        : context.textTertiary;

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
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: AppSizes.spaceMedium),
        Icon(
          Icons.location_on_outlined,
          size: AppSizes.iconSmall,
          color: context.textTertiary,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: Text(
            job.addressLabel ?? 'Ankara',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Container(
          padding: AppPadding.badge,
          decoration: BoxDecoration(
            color: hasApplicants
                ? AppColors.info.withValues(alpha: 0.1)
                : context.tileColor,
            borderRadius: AppRadius.smallCircular,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.userMultiple,
                size: AppSizes.iconSmall,
                color: applicantColor,
              ),
              const SizedBox(width: AppSizes.spaceTiny),
              Text(
                '${post.applicants.length}',
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: applicantColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------- Ortak parçalar

  BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
    color: context.backgroundColor,
    borderRadius: AppRadius.secondaryCircular,
    border: Border.all(color: context.dividerColor),
    boxShadow: [
      BoxShadow(
        color: AppColors.barShadow,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _sectionHeader(BuildContext context, String title, {Widget? action}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: context.textTheme.titleMedium),
        ?action,
      ],
    );
  }

  Widget _categoryBadge(
    BuildContext context,
    JobDetail job, {
    bool withIcon = false,
  }) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: job.category.color.withValues(alpha: _tintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withIcon) ...[
            AppIcon(
              job.category.icon,
              size: AppSizes.iconSmall,
              color: job.category.color,
            ),
            const SizedBox(width: AppSizes.spaceTiny),
          ],
          Text(
            job.category.displayName,
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: job.category.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeBadge(BuildContext context) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        'Aktif',
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.successStrong,
        ),
      ),
    );
  }

  Widget _emptyPanel(
    BuildContext context, {
    required AppIconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spaceLarge),
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        children: [
          AppIcon(icon, size: AppSizes.iconLarge, color: context.dividerColor),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            title,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              subtitle,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            action,
          ],
        ],
      ),
    );
  }
}

/// Başvuran + ait olduğu ilan çifti (dahili yardımcı sınıf)
class _RecentApplicant {
  final BApplicant applicant;
  final BJobPost post;

  const _RecentApplicant({required this.applicant, required this.post});
}
