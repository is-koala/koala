import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/company_detail/presentation/widgets/company_gallery_strip.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';

part 'company_detail_pagemodel.dart';

class CompanyDetailPage extends StatefulWidget {
  /// Şirketin kimliği. Ekran kaydı kendisi çekiyor: bir ilandan, bir işten
  /// ya da bir sohbetten gelinebiliyor ve hepsinin elinde şirketin tam hâli
  /// olmuyor — yalnızca kimliği oluyor.
  final String companyId;

  const CompanyDetailPage({super.key, required this.companyId});

  /// Kapak alanının açık yüksekliği. Logo, şirket adı ve tür rozetini
  /// birlikte taşıyacak kadar.
  static const double appBarExpandedHeight = 180;

  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends CompanyDetailPagemodel {
  /// Kapaktaki şirket logosunun kenar uzunluğu.
  static const double _logoSize = 80;

  /// Eylem butonlarının yüksekliği; sayfa butonlarından alçak çünkü yan
  /// yana iki tane duruyorlar.
  static const double _actionButtonHeight = 48;

  /// Kapak üstündeki tür rozetinin zemin opaklığı.
  static const double _badgeAlpha = 0.25;

  /// Kategori rozetinin zemin opaklığı.
  static const double _categoryTintAlpha = 0.15;

  @override
  Widget build(BuildContext context) {
    final loaded = company;

    if (loaded == null) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: MyAppbar(title: 'Şirket'),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorState(errorMessage ?? 'Şirket bulunamadı'),
      );
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: RefreshIndicator(
        onRefresh: load,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            appBar(context, titleOpacity, loaded),
            actionButtons(context, loaded),
            SliverToBoxAdapter(child: _content(loaded)),
          ],
        ),
      ),
    );
  }

  /// Şirket çekilemediğinde: mesaj ve tekrar deneme.
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
            OutlinedButton(onPressed: load, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ İçerik

  Widget _content(Company company) {
    return Padding(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!company.isApproved) _approvalWarning(),
          if (company.description != null) ...[
            _buildSectionTitle('Hakkında'),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              company.description!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLarge),
          ],
          if (company.images.isNotEmpty) ...[
            _buildSectionTitle('Galeri'),
            const SizedBox(height: AppSizes.space),
            // Galerisi olmayan şirkette bölüm hiç çizilmiyor: boş bir başlık
            // eksik bir sayfa gibi okunurdu.
            CompanyGalleryStrip(images: company.images),
            const SizedBox(height: AppSizes.spaceLarge),
          ],
          _buildSectionTitle('İletişim Bilgileri'),
          const SizedBox(height: AppSizes.space),
          _buildInfoCard([
            if (company.email != null)
              _buildInfoRow(AppIcons.mail, 'E-posta', company.email!),
            if (company.phoneNumber != null)
              _buildInfoRow(AppIcons.call, 'Telefon', company.phoneNumber!),
            if (company.website != null)
              _buildInfoRow(AppIcons.antenna, 'Website', company.website!),
          ]),
          if (company.address != null) ...[
            const SizedBox(height: AppSizes.spaceLarge),
            _buildSectionTitle('Adres'),
            const SizedBox(height: AppSizes.space),
            _buildInfoCard([
              // Sunucu şirketin tam adresini döndürüyor; adres satırı
              // yoksa il/ilçe yazılıyor.
              _buildInfoRow(
                AppIcons.location,
                'Adres',
                company.address!.displayAddress ??
                    company.address!.shortLabel ??
                    '—',
              ),
            ]),
          ],
          const SizedBox(height: AppSizes.spaceLarge),
          _buildSectionTitle('İlanlar'),
          const SizedBox(height: AppSizes.space),
          _buildJobsSection(),
          const SizedBox(height: AppSizes.sectionSpace),
        ],
      ),
    );
  }

  Widget _approvalWarning() {
    return Container(
      padding: AppPadding.card,
      margin: const EdgeInsets.only(bottom: AppSizes.spaceMedium),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.innerCircular,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AppIcon(
            AppIcons.alert,
            color: AppColors.warning,
            size: AppSizes.iconMedium,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Text(
              'Bu şirket henüz onaylanmamıştır',
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- Eylem butonları

  SliverToBoxAdapter actionButtons(BuildContext context, Company company) {
    return SliverToBoxAdapter(
      child: Container(
        padding: AppPadding.primaryAll,
        color: context.backgroundColor,
        child: Row(
          children: [
            Expanded(child: _followButton(company)),
            const SizedBox(width: AppSizes.space),
            Expanded(child: _messageButton(company)),
          ],
        ),
      ),
    );
  }

  Widget _followButton(Company company) {
    return SizedBox(
      height: _actionButtonHeight,
      child: ElevatedButton.icon(
        onPressed: isTogglingFollow ? null : toggleFollow,
        icon: AppIcon(
          company.isFollowing ? AppIcons.userCheck : AppIcons.userAdd,
          size: AppSizes.iconSmall,
        ),
        label: Text(company.isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
        style: ElevatedButton.styleFrom(
          backgroundColor: company.isFollowing
              ? context.tileColor
              : context.accentColor,
          foregroundColor: company.isFollowing
              ? context.textSecondary
              : context.onAccentColor,
          elevation: 0,
          textStyle: context.textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.innerCircular,
            side: company.isFollowing
                ? BorderSide(color: context.dividerColor)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _messageButton(Company company) {
    return SizedBox(
      height: _actionButtonHeight,
      child: OutlinedButton.icon(
        onPressed: openChat,
        icon: const AppIcon(AppIcons.message, size: AppSizes.iconSmall),
        label: const Text('Mesaj At'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.accentColor,
          side: BorderSide(color: context.accentColor, width: 1.5),
          textStyle: context.textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.innerCircular,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Kapak

  SliverAppBar appBar(
    BuildContext context,
    double clampedOpacity,
    Company company,
  ) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: CompanyDetailPage.appBarExpandedHeight,
      backgroundColor: context.accentColor,
      // Kapak marka yeşili; üstündeki her şey temadan bağımsız beyaz.
      leading: IconButton(
        icon: const AppIcon(AppIcons.arrowLeft, color: AppColors.onAccent),
        onPressed: () => context.pop(),
      ),
      centerTitle: false,
      title: Opacity(
        opacity: clampedOpacity,
        child: Text(
          company.name,
          style: context.textTheme.titleMedium?.copyWith(
            color: AppColors.onAccent,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceMedium),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _logo(company),
                const SizedBox(height: AppSizes.space),
                Text(
                  company.name,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (company.type != null) ...[
                  const SizedBox(height: AppSizes.spaceTiny),
                  _typeBadge(company),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(Company company) {
    final placeholder = Icon(
      Icons.business,
      size: AppSizes.iconLarge,
      color: context.textTertiary,
    );

    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: AppRadius.secondaryCircular,
        boxShadow: [
          BoxShadow(
            color: AppColors.mapShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: company.logoUrl != null
          ? ClipRRect(
              borderRadius: AppRadius.secondaryCircular,
              child: Image.network(
                company.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
            )
          : placeholder,
    );
  }

  Widget _typeBadge(Company company) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(alpha: _badgeAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        company.type!.displayName,
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.onAccent,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ İlanlar

  Widget _buildJobsSection() {
    return FutureBuilder<List<Job>>(
      future: companyJobsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _centered(
            CircularProgressIndicator(color: context.accentColor),
          );
        }

        if (snapshot.hasError) {
          return _centered(
            Text(
              'İlanlar yüklenirken bir hata oluştu',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          );
        }

        final companyJobs = snapshot.data ?? [];
        if (companyJobs.isEmpty) {
          return _centered(
            Column(
              children: [
                AppIcon(
                  AppIcons.search,
                  size: AppSizes.iconHuge,
                  color: context.dividerColor,
                ),
                const SizedBox(height: AppSizes.spaceMedium),
                Text(
                  'Henüz ilan yok',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final job in companyJobs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.space),
                child: _buildJobCard(job),
              ),
          ],
        );
      },
    );
  }

  Widget _centered(Widget child) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.spaceXLarge),
      child: child,
    ),
  );

  Widget _buildJobCard(Job job) {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _categoryBadge(job),
              const SizedBox(width: AppSizes.spaceSmall),
              _typeChip(job),
            ],
          ),
          const SizedBox(height: AppSizes.space),
          Text(
            job.title,
            style: context.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            job.subtitle,
            style: context.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSizes.space),
          _priceAndLocationRow(job),
        ],
      ),
    );
  }

  Widget _categoryBadge(Job job) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: job.category.color.withValues(alpha: _categoryTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
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
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: job.category.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(Job job) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        job.type.displayName,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.textSecondary,
        ),
      ),
    );
  }

  Widget _priceAndLocationRow(Job job) {
    return Row(
      children: [
        AppIcon(
          AppIcons.moneyBag,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          '₺${job.price.toStringAsFixed(0)}',
          style: context.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: AppSizes.spaceMedium),
        AppIcon(
          AppIcons.location,
          size: AppSizes.iconSmall,
          color: context.textSecondary,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: Text(
            job.locationLabel ?? '-',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Ortak parçalar

  Widget _buildSectionTitle(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(AppIconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: AppSizes.iconMedium, color: context.accentColor),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textTheme.labelMedium),
                const SizedBox(height: AppSizes.smallGap),
                Text(
                  value,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
