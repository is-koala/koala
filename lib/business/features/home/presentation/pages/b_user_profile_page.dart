import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';

class BUserProfilePage extends StatelessWidget {
  final BApplicant applicant;

  const BUserProfilePage({super.key, required this.applicant});

  /// Kapaktaki profil fotoğrafı ve çevresindeki beyaz halka.
  static const double _avatarSize = 100;
  static const double _avatarBorder = 3;

  /// Bilgi satırındaki etiket sütununun genişliği; değerler hizalı dursun
  /// diye sabit.
  static const double _infoLabelWidth = 100;

  /// Kapaktaki gradyanın koyu ucu.
  static const double _gradientEndAlpha = 0.8;

  /// Kapak üzerindeki ikincil metin ve rozetlerin opaklıkları.
  static const double _onCoverMuted = 0.9;
  static const double _onCoverSurface = 0.2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: "Profil"),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _profileHeader(context),
            Padding(
              padding: AppPadding.primaryAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSizes.spaceSmall),
                  _aboutSection(context),
                  const SizedBox(height: AppSizes.spaceLarge),
                  _infoSection(context),
                  const SizedBox(height: AppSizes.spaceLarge),
                  _cvSection(context),
                  const SizedBox(height: AppSizes.navBarClearance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- Kapak

  /// Kapak marka yeşili bir gradyan; üstündeki her şey temadan bağımsız beyaz.
  Widget _profileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceXLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor,
            AppColors.primaryColor.withValues(alpha: _gradientEndAlpha),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: BoxDecoration(
              borderRadius: AppRadius.secondaryCircular,
              border: Border.all(
                color: AppColors.onAccent,
                width: _avatarBorder,
              ),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: AssetImage(applicant.profileImage),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            applicant.fullName,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onAccent,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            applicant.jobTitle,
            style: context.textTheme.bodyLarge?.copyWith(
              color: AppColors.onAccent.withValues(alpha: _onCoverMuted),
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          _locationBadge(context),
        ],
      ),
    );
  }

  Widget _locationBadge(BuildContext context) {
    final muted = AppColors.onAccent.withValues(alpha: _onCoverMuted);

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(alpha: _onCoverSurface),
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: AppSizes.iconSmall,
            color: muted,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            'Ankara, Türkiye',
            style: context.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Bölümler

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: context.textTheme.titleMedium);

  BoxDecoration _panelDecoration(BuildContext context) => BoxDecoration(
    color: context.tileColor,
    borderRadius: AppRadius.innerCircular,
  );

  Widget _aboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Hakkında'),
        const SizedBox(height: AppSizes.spaceSmall),
        Container(
          width: double.infinity,
          padding: AppPadding.primaryAll,
          decoration: _panelDecoration(context),
          child: Text(
            applicant.coverLetter ??
                'Merhaba! Deneyimli bir ${applicant.jobTitle} olarak farklı '
                    'projelerde yer aldım. Ekip çalışmasına yatkın, sorumluluk '
                    'sahibi ve enerjik biriyim.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Bilgiler'),
        const SizedBox(height: AppSizes.space),
        Container(
          width: double.infinity,
          padding: AppPadding.primaryAll,
          decoration: _panelDecoration(context),
          child: Column(
            children: [
              _infoRow(context, AppIcons.user, 'Ad Soyad', applicant.fullName),
              _infoRow(context, AppIcons.work, 'Meslek', applicant.jobTitle),
              _infoRow(
                context,
                AppIcons.calendar,
                'Başvuru Tarihi',
                applicant.appliedDate,
              ),
              _infoRow(context, AppIcons.location, 'Konum', 'Ankara, Türkiye'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
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
            width: _infoLabelWidth,
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

  Widget _cvSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Özgeçmiş'),
        const SizedBox(height: AppSizes.space),
        Container(
          width: double.infinity,
          padding: AppPadding.primaryAll,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.08),
            borderRadius: AppRadius.innerCircular,
            border: Border.all(
              color: context.accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spaceSmall),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.smallCircular,
                ),
                child: AppIcon(
                  AppIcons.fileText,
                  size: AppSizes.icon,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODO(backend): Gerçek CV dosyası bağlanınca indirilebilir
                    // olacak.
                    Text(
                      '${applicant.fullName}_CV.pdf (Demoda indirilemez)',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSizes.smallGap),
                    Text(
                      'PDF • 245 KB',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.download,
                size: AppSizes.iconMedium,
                color: context.accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
