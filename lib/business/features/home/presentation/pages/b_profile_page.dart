import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/services/fake_business_company.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';

class BProfilePage extends StatefulWidget {
  const BProfilePage({super.key});

  @override
  State<BProfilePage> createState() => _BProfilePageState();
}

class _BProfilePageState extends State<BProfilePage> {
  late Company company;

  /// Kapaktaki şirket logosu ve çevresindeki beyaz halka.
  static const double _logoSize = 90;
  static const double _logoBorder = 3;

  /// Kapak üzerindeki ikincil metin ve rozet zeminlerinin opaklıkları.
  static const double _onCoverMuted = 0.9;
  static const double _onCoverSurface = 0.2;

  /// Navbar'ın altında kalmasın diye sayfanın sonuna eklenen pay; profilde
  /// liste değil tek sütun var, o yüzden standart paydan geniş.
  static const double _bottomClearance = 120;

  @override
  void initState() {
    super.initState();
    company = FakeBusinessCompany.instance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: "Profilim",
        isLarge: true,
        showBackButton: false,
        actions: [
          IconButton(
            onPressed: () async {
              await context.push('/business/settings');
              if (!mounted) return;
              setState(() {
                company = FakeBusinessCompany.instance;
              });
            },
            icon: AppIcon(AppIcons.settings, color: context.textPrimary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileHeader(),
            Padding(
              padding: AppPadding.primaryHorizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSizes.spaceLarge),
                  _aboutSection(),
                  const SizedBox(height: AppSizes.spaceLarge),
                  _contactInfoSection(),
                  const SizedBox(height: AppSizes.spaceLarge),
                  _addressSection(),
                  const SizedBox(height: AppSizes.spaceLarge),
                  _statsSection(),
                  const SizedBox(height: _bottomClearance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- Kapak

  /// Kapak marka yeşili; üstündeki her şey temadan bağımsız beyaz.
  Widget _profileHeader() {
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
          _logo(),
          const SizedBox(height: AppSizes.space),
          Text(
            company.name,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onAccent,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          if (company.type != null) _typeBadge(),
          const SizedBox(height: AppSizes.spaceSmall),
          _approvalRow(),
        ],
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        color: AppColors.onAccent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.onAccent, width: _logoBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.mapShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: company.logo != null
            ? Image.network(
                company.logo!.url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _logoPlaceholder(),
              )
            : _logoPlaceholder(),
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

  Widget _typeBadge() {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(alpha: _onCoverSurface),
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Text(
        company.type!.displayName,
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.onAccent,
        ),
      ),
    );
  }

  Widget _approvalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(
          company.isApproved ? AppIcons.checkCircle : AppIcons.alert,
          color: AppColors.onAccent,
          size: AppSizes.iconSmall,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          company.isApproved ? 'Onaylı İşletme' : 'Onay Bekliyor',
          style: context.textTheme.bodySmall?.copyWith(
            color: AppColors.onAccent.withValues(alpha: _onCoverMuted),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Bölümler

  Widget _aboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Hakkımızda"),
        const SizedBox(height: AppSizes.spaceSmall),
        Text(
          company.description ?? 'Henüz bir açıklama eklenmemiş.',
          style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  Widget _contactInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("İletişim Bilgileri"),
        const SizedBox(height: AppSizes.space),
        _infoCard([
          _infoRow(AppIcons.mail, "E-posta", company.email),
          if (company.phoneNumber != null)
            _infoRow(AppIcons.call, "Telefon", company.phoneNumber!),
          if (company.website != null)
            _infoRow(AppIcons.globe, "Website", company.website!),
          if (company.taxNumber != null)
            _infoRow(AppIcons.file, "Vergi No", company.taxNumber!),
        ]),
      ],
    );
  }

  Widget _addressSection() {
    if (company.address == null) return const SizedBox.shrink();

    final locality = [
      company.address!.district,
      company.address!.city,
      company.address!.country,
    ].where((e) => e != null && e.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    if (company.address!.street != null)
                      Text(
                        company.address!.street!,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: AppSizes.smallGap),
                    Text(locality, style: context.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("İstatistikler"),
        const SizedBox(height: AppSizes.space),
        // TODO(backend): Sayılar sabit; gerçek servise bağlanacak.
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: AppIcons.work,
                value: "12",
                label: "Aktif İlan",
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: _statCard(
                icon: AppIcons.userMultiple,
                value: "48",
                label: "Başvuru",
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: _statCard(
                icon: AppIcons.star,
                value: "4.8",
                label: "Puan",
              ),
            ),
          ],
        ),
      ],
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
          Text(label, style: context.textTheme.labelMedium),
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
    border: Border.all(color: context.dividerColor),
  );

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration,
      child: Column(children: children),
    );
  }

  Widget _infoRow(AppIconData icon, String label, String value) {
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
      ),
    );
  }
}
