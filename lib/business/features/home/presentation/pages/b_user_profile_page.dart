import 'package:flutter/material.dart';
import 'package:koala/business/core/load_result.dart';
import 'package:koala/business/features/home/models/b_candidate_profile.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/presentation/widgets/b_candidate_reputation_section.dart';
import 'package:koala/business/features/home/presentation/widgets/b_talent_pool_button.dart';
import 'package:koala/business/features/home/services/b_candidate_profile_service.dart';
import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/models/availability.dart';
import 'package:koala/product/services/availability_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/block_user_action.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/profile_cover.dart';
import 'package:koala/product/widgets/report_sheet.dart';
import 'package:koala/product/widgets/availability_view.dart';
import 'package:url_launcher/url_launcher.dart';

part 'b_user_profile_pagemodel.dart';

/// İşverenin bir adayın kartına dokununca açtığı profil.
///
/// Üç kaynaktan besleniyor: [applicant] başvuru listesinden geliyor ve ekran
/// açılır açılmaz ad, fotoğraf, ön yazı ve tarihi çizebiliyor; meslek,
/// hakkında, konum ve özgeçmiş `GET /users/{userId}`'den, müsaitlik ise
/// `GET /users/{userId}/availability`'den arkadan doluyor. Havuz satırından
/// açılışta [applicant] boştur; kimlik [userId]'den alınır ve başvuruya
/// bağlı bölümler çizilmez.
///
/// Sunucu bu uçta tam adres döndürmüyor — yalnızca il/ilçe — ve `cvUrl`'i
/// sadece bu ilanın işverenine veriyor.
///
/// Puan özeti, son yorumlar ve rozetler kendi uçlarından
/// (`/users/{id}/rating-summary`, `/reviews`, `/badges`) geliyor; tamamlanan
/// iş sayısı ve aynı üçlünün kopyası koala-backend#282 ile profil yanıtında.
class BUserProfilePage extends StatefulWidget {
  const BUserProfilePage({
    super.key,
    this.applicant,
    this.userId,
    this.profileService,
    this.availabilityService,
    this.reviewService,
  }) : assert(
         applicant != null || userId != null,
         'applicant veya userId gerekli',
       );

  /// Rota `extra`'sından sayfayı kurar: başvuran kaydı ya da kullanıcı kimliği.
  factory BUserProfilePage.fromExtra(Object? extra) {
    if (extra is JobApplicant) {
      return BUserProfilePage(applicant: extra);
    }
    if (extra is String) {
      return BUserProfilePage(userId: extra);
    }
    throw ArgumentError.value(
      extra,
      'extra',
      'JobApplicant veya kullanıcı kimliği bekleniyor',
    );
  }

  final JobApplicant? applicant;
  final String? userId;

  /// Testler için; verilmezse üretimdeki tekil servisler.
  final BCandidateProfileService? profileService;
  final AvailabilityService? availabilityService;
  final ReviewService? reviewService;

  @override
  State<BUserProfilePage> createState() => _BUserProfilePageState();
}

class _BUserProfilePageState extends BUserProfilePageModel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: "Profil",
        actions: [
          if (_poolWorker != null) BTalentPoolButton(worker: _poolWorker!),
          ?_reportAction(),
          ?_blockAction(),
        ],
      ),
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
                  if (_isFromApplication) ...[
                    _coverLetterSection(context),
                    const SizedBox(height: AppSizes.spaceLarge),
                  ],
                  _aboutSection(context),
                  const SizedBox(height: AppSizes.spaceLarge),
                  _infoSection(context),
                  const SizedBox(height: AppSizes.spaceLarge),
                  AvailabilityView(
                    availability: _availability,
                    isLoading: _isAvailabilityLoading,
                    errorMessage: _availabilityErrorMessage,
                    onRetry: _loadAvailability,
                  ),
                  const SizedBox(height: AppSizes.spaceLarge),
                  BCandidateReputationSection(
                    summary: _effectiveRatingSummary,
                    summaryFailed: _ratingSummaryFailed,
                    reviews: _reviews,
                    badges: _effectiveBadges,
                    badgesFailed: _badgesFailed,
                    completedJobCount: _candidate?.completedJobCount,
                    isLoading: _isReputationLoading,
                    errorMessage: _reputationErrorMessage,
                    onRetry: _loadReputation,
                  ),
                  if (_showsCvSection) ...[
                    const SizedBox(height: AppSizes.spaceLarge),
                    _cvSection(context),
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

  /// Kapak marka yeşili bir gradyan; çizimi iki ekranın ortak `ProfileCover`'ı.
  Widget _profileHeader(BuildContext context) {
    return ProfileCover(
      name: _displayName,
      imageUrl: _photoUrl,
      subtitle: _jobTitle,
      location: _profile?.locationLabel,
    );
  }

  // ------------------------------------------------------------- Bölümler

  /// Adayın bu ilana yazdığı ön yazı. Uydurulmuyor: boşsa öyle yazıyor.
  Widget _coverLetterSection(BuildContext context) {
    final notes = widget.applicant?.notes;

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
              _infoRow(context, AppIcons.user, 'Ad Soyad', _displayName),
              _infoRow(
                context,
                AppIcons.work,
                'Meslek',
                _jobTitle ?? BUserProfilePageModel._missing,
              ),
              if (_isFromApplication)
                _infoRow(
                  context,
                  AppIcons.calendar,
                  'Başvuru Tarihi',
                  widget.applicant!.applicationDateTime?.asShortDate ??
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
