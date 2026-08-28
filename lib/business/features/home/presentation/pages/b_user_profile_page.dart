import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
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
import 'package:url_launcher/url_launcher.dart';

part 'b_user_profile_pagemodel.dart';

/// İşverenin bir adayın kartına dokununca açtığı profil.
///
/// İki kaynaktan besleniyor: [applicant] başvuru listesinden geliyor ve ekran
/// açılır açılmaz ad, fotoğraf, ön yazı ve tarihi çizebiliyor; meslek,
/// hakkında, konum ve özgeçmiş `GET /users/{userId}`'den arkadan doluyor.
///
/// Sunucu bu uçta tam adres döndürmüyor — yalnızca il/ilçe — ve `cvUrl`'i
/// sadece bu ilanın işverenine veriyor.
class BUserProfilePage extends StatefulWidget {
  const BUserProfilePage({super.key, required this.applicant});

  final JobApplicant applicant;

  @override
  State<BUserProfilePage> createState() => _BUserProfilePageState();
}

class _BUserProfilePageState extends BUserProfilePageModel {
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
                  if (_errorMessage != null) ...[
                    _errorNotice(),
                    const SizedBox(height: AppSizes.spaceLarge),
                  ],
                  _coverLetterSection(context),
                  const SizedBox(height: AppSizes.spaceLarge),
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

  /// Profil çekilemediğinde ekranın üstüne konan şerit.
  ///
  /// Ekranı kaplayan bir hata göstermek yerine: başvurudan gelen ad, fotoğraf
  /// ve ön yazı zaten elde ve işverenin işine yarıyor.
  Widget _errorNotice() {
    return Container(
      width: double.infinity,
      padding: AppPadding.chip,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.alert,
            size: AppSizes.iconSmall,
            color: context.textTertiary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceTiny),
                GestureDetector(
                  onTap: _loadProfile,
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
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- Kapak

  /// Kapak marka yeşili bir gradyan; üstündeki her şey temadan bağımsız beyaz.
  Widget _profileHeader(BuildContext context) {
    final jobTitle = _jobTitle;
    final location = _profile?.locationLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceXLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor,
            AppColors.primaryColor.withValues(
              alpha: BUserProfilePageModel._gradientEndAlpha,
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.secondaryCircular,
              border: Border.all(
                color: AppColors.onAccent,
                width: BUserProfilePageModel._avatarBorder,
              ),
            ),
            child: ProfileAvatar(
              imageUrl:
                  _profile?.profilePictureUrl ??
                  widget.applicant.profilePictureUrl,
              size: BUserProfilePageModel._avatarSize,
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            _profile?.fullName ?? widget.applicant.fullName,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onAccent,
            ),
          ),
          if (jobTitle != null && jobTitle.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              jobTitle,
              style: context.textTheme.bodyLarge?.copyWith(
                color: AppColors.onAccent.withValues(
                  alpha: BUserProfilePageModel._onCoverMuted,
                ),
              ),
            ),
          ],
          if (location != null) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _locationBadge(context, location),
          ],
        ],
      ),
    );
  }

  Widget _locationBadge(BuildContext context, String location) {
    final muted = AppColors.onAccent.withValues(
      alpha: BUserProfilePageModel._onCoverMuted,
    );

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(
          alpha: BUserProfilePageModel._onCoverSurface,
        ),
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
            location,
            style: context.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Bölümler

  /// Adayın bu ilana yazdığı ön yazı. Uydurulmuyor: boşsa öyle yazıyor.
  Widget _coverLetterSection(BuildContext context) {
    final notes = widget.applicant.notes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Ön Yazı'),
        const SizedBox(height: AppSizes.spaceSmall),
        Container(
          width: double.infinity,
          padding: AppPadding.primaryAll,
          decoration: _panelDecoration(context),
          child: Text(
            notes?.isNotEmpty == true ? notes! : 'Aday bir ön yazı bırakmamış.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Adayın profilindeki "Hakkında" metni.
  Widget _aboutSection(BuildContext context) {
    final about = _profile?.about;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Hakkında'),
        const SizedBox(height: AppSizes.spaceSmall),
        Container(
          width: double.infinity,
          padding: AppPadding.primaryAll,
          decoration: _panelDecoration(context),
          child: _isLoading
              ? _loadingLine()
              : Text(
                  about?.isNotEmpty == true
                      ? about!
                      : 'Aday profiline bir açıklama eklememiş.',
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
              _infoRow(
                context,
                AppIcons.user,
                'Ad Soyad',
                _profile?.fullName ?? widget.applicant.fullName,
              ),
              _infoRow(
                context,
                AppIcons.work,
                'Meslek',
                _jobTitle ?? BUserProfilePageModel._missing,
              ),
              _infoRow(
                context,
                AppIcons.calendar,
                'Başvuru Tarihi',
                widget.applicant.applicationDateTime?.asShortDate ??
                    BUserProfilePageModel._missing,
              ),
              _infoRow(
                context,
                AppIcons.location,
                'Konum',
                // Sunucu tam adres döndürmüyor; il/ilçe kadarı geliyor.
                _profile?.locationLabel ?? BUserProfilePageModel._missing,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Özgeçmiş

  /// Özgeçmiş kartı.
  ///
  /// Bağlantı yoksa aday özgeçmiş yüklememiş demektir; sunucu adresi zaten
  /// yalnızca yetkili görene döndürüyor.
  Widget _cvSection(BuildContext context) {
    final hasCv = _cvUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Özgeçmiş'),
        const SizedBox(height: AppSizes.space),
        Material(
          color: context.tileColor,
          borderRadius: AppRadius.innerCircular,
          child: InkWell(
            borderRadius: AppRadius.innerCircular,
            onTap: hasCv ? _openCv : null,
            child: Padding(
              padding: AppPadding.primaryAll,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.spaceSmall),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(
                        alpha: hasCv ? 0.15 : 0.06,
                      ),
                      borderRadius: AppRadius.smallCircular,
                    ),
                    child: AppIcon(
                      AppIcons.fileText,
                      size: AppSizes.icon,
                      color: hasCv ? context.accentColor : context.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSizes.space),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasCv ? 'Özgeçmişi Görüntüle' : 'Özgeçmiş yok',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSizes.smallGap),
                        Text(
                          hasCv
                              ? 'Tarayıcıda açılır'
                              : 'Aday henüz özgeçmiş yüklememiş',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isOpeningCv)
                    SizedBox(
                      width: AppSizes.iconMedium,
                      height: AppSizes.iconMedium,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.accentColor,
                        ),
                      ),
                    )
                  else if (hasCv)
                    AppIcon(
                      AppIcons.arrowRight,
                      size: AppSizes.iconMedium,
                      color: context.accentColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------- Ortak parçalar

  /// Profil beklenirken metnin yerini tutan çubuk.
  Widget _loadingLine() {
    return Row(
      children: [
        SizedBox(
          width: AppSizes.iconMedium,
          height: AppSizes.iconMedium,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Text(
          'Profil yükleniyor...',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: context.textTheme.titleMedium);

  BoxDecoration _panelDecoration(BuildContext context) => BoxDecoration(
    color: context.tileColor,
    borderRadius: AppRadius.innerCircular,
  );

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
            width: BUserProfilePageModel._infoLabelWidth,
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
}
