import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/business/features/home/models/employer_stats.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'b_profile_pagemodel.dart';

/// İşverenin kendi profili.
///
/// İki hâli var ve ikisi de geçerli: şirket üyeliği olan işveren **şirketini**
/// görüyor, olmayan **kendini**. Bireysel işveren bir eksiklik değil — backend
/// `POST /users/me/jobs` ile bireysel ilan açtırıyor.
class BProfilePage extends StatefulWidget {
  const BProfilePage({super.key});

  @override
  State<BProfilePage> createState() => _BProfilePageState();
}

class _BProfilePageState extends BProfilePageModel {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final companyProvider = context.watch<BCompanyProvider>();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: "Profilim",
        isLarge: true,
        showBackButton: false,
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: AppIcon(AppIcons.settings, color: context.textPrimary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        color: context.accentColor,
        child: _body(user, companyProvider),
      ),
    );
  }

  Widget _body(CurrentUser? user, BCompanyProvider companyProvider) {
    final isLoading =
        context.watch<UserProvider>().isLoading || companyProvider.isLoading;

    if (user == null || (isLoading && !companyProvider.hasLoaded)) {
      return isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorState(
              context.watch<UserProvider>().errorMessage ??
                  'Profil yüklenemedi',
            );
    }

    final message = companyProvider.errorMessage;
    if (message != null) return _errorState(message);

    final company = companyProvider.company;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileHeader(user, company, companyProvider.stats),
          Padding(
            padding: AppPadding.primaryHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.spaceLarge),
                _aboutSection(company),
                const SizedBox(height: AppSizes.spaceLarge),
                _contactInfoSection(user, company),
                const SizedBox(height: AppSizes.spaceLarge),
                ..._addressSection(user, company),
                _statsSection(companyProvider),
                const SizedBox(height: BProfilePageModel._bottomClearance),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    // Kaydırılabilir kalmalı: aşağı çekip yenileme bu ekranda da çalışıyor.
    return ListView(
      padding: AppPadding.primaryAll,
      children: [
        SizedBox(height: context.dynamicHeight(0.25)),
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
        Center(
          child: OutlinedButton(
            onPressed: () => _load(force: true),
            child: const Text('Tekrar Dene'),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------- Kapak

  /// Kapak marka yeşili; üstündeki her şey temadan bağımsız beyaz.
  Widget _profileHeader(
    CurrentUser user,
    Company? company,
    EmployerStats? stats,
  ) {
    final memberSince = stats?.memberSince;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.accentColor,
        borderRadius: AppRadius.secondaryBottom,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppPadding.primary,
        AppSizes.spaceSmall,
        AppPadding.primary,
        AppSizes.spaceLarge,
      ),
      child: Column(
        children: [
          _logo(company?.logoUrl ?? user.profilePictureUrl),
          const SizedBox(height: AppSizes.space),
          Text(
            company?.name ?? user.fullName,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onAccent,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          _typeBadge(company),
          const SizedBox(height: AppSizes.spaceSmall),
          _statusRow(user, company),
          if (memberSince != null) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              '${memberSince.asMonthYear} tarihinden beri üye',
              style: context.textTheme.labelMedium?.copyWith(
                color: AppColors.onAccent.withValues(
                  alpha: BProfilePageModel._onCoverMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logo(String? imageUrl) {
    return Container(
      width: BProfilePageModel._logoSize,
      height: BProfilePageModel._logoSize,
      decoration: BoxDecoration(
        color: AppColors.onAccent,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.onAccent,
          width: BProfilePageModel._logoBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.mapShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl == null || imageUrl.isEmpty
            ? _logoPlaceholder()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _logoPlaceholder(),
              ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      color: context.tileColor,
      child: AppIcon(
        AppIcons.building,
        size: AppSizes.iconLarge,
        color: context.textTertiary,
      ),
    );
  }

  /// Şirketin hukuki türü; şirketi olmayan işverende "Bireysel İşveren".
  Widget _typeBadge(Company? company) {
    final label = company == null
        ? 'Bireysel İşveren'
        : company.type?.displayName ?? 'İşletme';

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(
          alpha: BProfilePageModel._onCoverSurface,
        ),
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Text(
        label,
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.onAccent,
        ),
      ),
    );
  }

  /// Şirketi olanda şirketin onayı, olmayanda kişinin kimlik doğrulaması.
  ///
  /// İkisi de aynı şeyi anlatıyor: bu hesap ilan yayınlayabilir mi.
  Widget _statusRow(CurrentUser user, Company? company) {
    final isVerified = company?.isApproved ?? user.identityVerified;
    final label = company != null
        ? (isVerified ? 'Onaylı İşletme' : 'Onay Bekliyor')
        : (isVerified ? 'Kimliği Doğrulanmış' : 'Kimlik Doğrulanmadı');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(
          isVerified ? AppIcons.checkCircle : AppIcons.alert,
          color: AppColors.onAccent,
          size: AppSizes.iconSmall,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: AppColors.onAccent.withValues(
              alpha: BProfilePageModel._onCoverMuted,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Bölümler

  Widget _aboutSection(Company? company) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Hakkımızda"),
        const SizedBox(height: AppSizes.spaceSmall),
        Text(
          company?.description?.isNotEmpty == true
              ? company!.description!
              : 'Henüz bir açıklama eklenmemiş.',
          style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  /// İletişim bilgileri: şirket varsa şirketin, yoksa kişinin.
  Widget _contactInfoSection(CurrentUser user, Company? company) {
    final email = company?.email ?? user.email;
    final phone = company?.phoneNumber ?? user.phoneNumber;
    final website = company?.website;
    final taxNumber = company?.taxNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("İletişim Bilgileri"),
        const SizedBox(height: AppSizes.space),
        _infoCard([
          if (email.isNotEmpty) _infoRow(AppIcons.mail, "E-posta", email),
          if (phone != null && phone.isNotEmpty)
            _infoRow(AppIcons.call, "Telefon", phone),
          if (website != null && website.isNotEmpty)
            _infoRow(AppIcons.globe, "Website", website),
          if (taxNumber != null && taxNumber.isNotEmpty)
            _infoRow(AppIcons.file, "Vergi No", taxNumber),
        ]),
      ],
    );
  }

  /// Adres bölümü. Şirketin adresi yoksa kişininki gösteriliyor; ikisi de
  /// yoksa bölüm hiç çizilmiyor.
  List<Widget> _addressSection(CurrentUser user, Company? company) {
    final address = company?.address ?? user.address;
    if (address == null) return const [];

    final locality = [
      address.districtName,
      address.cityName,
      address.countryName,
    ].where((part) => part.isNotEmpty).join(', ');

    return [
      _sectionTitle("Adres"),
      const SizedBox(height: AppSizes.space),
      Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: _panelDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              AppIcons.location,
              size: AppSizes.iconMedium,
              color: context.accentColor,
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.displayAddress?.isNotEmpty == true)
                    Text(
                      address.displayAddress!,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (locality.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.smallGap),
                    Text(locality, style: context.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSizes.spaceLarge),
    ];
  }

  /// İstatistikler `GET /users/{id}/employer-stats`'tan geliyor ve **kişiye**
  /// bağlı: şirket adına açılan ilan da onu açan kullanıcının sayısına
  /// yazılıyor.
  Widget _statsSection(BCompanyProvider provider) {
    final stats = provider.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("İstatistikler"),
        const SizedBox(height: AppSizes.space),
        if (stats == null)
          _statsNotice(provider.statsErrorMessage)
        else
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: AppIcons.work,
                  value: '${stats.jobsPosted}',
                  label: "İlan",
                ),
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: _statCard(
                  icon: AppIcons.checkCircle,
                  value: '${stats.completedJobs}',
                  label: "Tamamlanan",
                ),
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: _statCard(
                  icon: AppIcons.star,
                  // Hiç değerlendirme yokken "0.0" yazmak kötü puan almış
                  // gibi görünürdü.
                  value: stats.hasRating
                      ? stats.averageRating.toStringAsFixed(1)
                      : '—',
                  label: stats.hasRating
                      ? '${stats.reviewCount} değerlendirme'
                      : "Puan yok",
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Sayılar gelmediğinde onların yerine geçen kutu. Profilin geri kalanı
  /// çizilmeye devam ediyor.
  Widget _statsNotice(String? message) {
    return Container(
      width: double.infinity,
      padding: AppPadding.chip,
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? 'İstatistikler alınamadı.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          GestureDetector(
            onTap: () => _load(force: true),
            child: Text(
              'Tekrar dene',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required AppIconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.spaceMedium,
        horizontal: AppSizes.spaceSmall,
      ),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: context.accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          AppIcon(icon, size: AppSizes.icon, color: context.accentColor),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.smallGap),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: context.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- Ortak parçalar

  Widget _sectionTitle(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  BoxDecoration get _panelDecoration => BoxDecoration(
    color: context.tileColor,
    borderRadius: AppRadius.innerCircular,
  );

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration,
      child: Column(spacing: AppSizes.spaceMedium, children: children),
    );
  }

  Widget _infoRow(AppIconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: AppSizes.iconMedium, color: context.accentColor),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.textTertiary,
                ),
              ),
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
    );
  }
}
