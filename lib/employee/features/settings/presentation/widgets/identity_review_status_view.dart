import 'package:flutter/material.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Personel incelemesinin **karar bekleyen** ve **onaylanmış** hâlleri.
///
/// Red ayrı bir görünüm değil: reddedilen kullanıcı aynı formu yeniden
/// dolduracağı için gerekçe formun üstünde [IdentityRejectionNotice] olarak
/// duruyor.
class IdentityReviewStatusView extends StatelessWidget {
  /// Bekleyen inceleme: ne olduğu, tahmini süre ve gönderim anı.
  const IdentityReviewStatusView.pending({
    super.key,
    required this.review,
    required this.onRefresh,
    required this.onLeave,
    this.isRefreshing = false,
  }) : _approved = false;

  /// Onaylanmış inceleme: kullanıcıyı profil rozetine geri yolluyor.
  const IdentityReviewStatusView.approved({super.key, required this.onLeave})
    : review = null,
      onRefresh = null,
      isRefreshing = false,
      _approved = true;

  final IdentityReview? review;

  /// Durumu sunucudan yeniden okur; yalnız bekleyen görünümde.
  final VoidCallback? onRefresh;

  /// Ekrandan ayrılma: bekleyende "Tamam", onaylıda "Profile Dön".
  final VoidCallback onLeave;

  final bool isRefreshing;

  final bool _approved;

  /// Personelin inceleme süresi için kullanıcıya verilen tahmin. Ölçülmüş
  /// bir değer değil, ürünün taahhüdü; değişirse metin buradan değişir.
  static const String estimatedDuration =
      'İnceleme genellikle 1 iş günü içinde tamamlanır; yoğun günlerde biraz '
      'daha uzun sürebilir.';

  /// Bilgilendirme metinlerinin satır aralığı; kimlik ekranlarındakiyle aynı.
  static const double _lineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.spaceLarge),
          AppIcon(
            _approved ? AppIcons.checkCircle : AppIcons.clock,
            size: AppSizes.iconHuge,
            color: _approved ? AppColors.success : AppColors.pending,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            _approved ? 'Kimliğin doğrulandı' : 'Belgelerin inceleniyor',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            _approved
                ? 'Personel gönderdiğin fotoğrafları onayladı. Artık ilanlara '
                      'başvurabilir, şirket kurabilir ve ilan açabilirsin.'
                : 'Dört kimlik fotoğrafın personel kuyruğuna alındı. '
                      '$estimatedDuration Sonuçlanmadan yeni bir yükleme '
                      'yapılamaz; onaylanınca hesabın doğrulanmış olur.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: _lineHeight,
            ),
          ),
          if (!_approved && review?.createdAt != null) ...[
            const SizedBox(height: AppSizes.spaceMedium),
            _submittedAt(context, review!.createdAt!),
          ],
          const SizedBox(height: AppSizes.spaceLarge),
          if (_approved)
            MyButton(onPressed: onLeave, title: 'Profile Dön')
          else ...[
            MyButton(
              onPressed: onRefresh,
              title: 'Durumu Yenile',
              isLoading: isRefreshing,
            ),
            const SizedBox(height: AppSizes.space),
            MyButton(onPressed: onLeave, title: 'Tamam', isReversed: true),
          ],
          const SizedBox(height: AppSizes.navBarClearance),
        ],
      ),
    );
  }

  Widget _submittedAt(BuildContext context, DateTime at) {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Gönderim',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Text(
            at.asShortDateTime,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reddedilen incelemenin gerekçesi; formun üstünde duruyor.
class IdentityRejectionNotice extends StatelessWidget {
  const IdentityRejectionNotice({super.key, required this.review});

  final IdentityReview review;

  /// Kırmızı zeminin saydamlığı: uyarı okunsun ama form kırmızıya boyanmasın.
  static const double _surfaceAlpha = 0.1;

  @override
  Widget build(BuildContext context) {
    final reason = review.rejectionReason;
    final at = review.rejectedAt;

    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: _surfaceAlpha),
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(
                AppIcons.alert,
                size: AppSizes.iconMedium,
                color: AppColors.danger,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: Text(
                  'Belgelerin reddedildi',
                  style: context.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            reason == null
                ? 'Personel bir gerekçe yazmadı. Dört kareyi rehbere uygun '
                      'biçimde yeniden çekip tekrar gönderebilirsin.'
                : 'Personel gerekçesi: $reason',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          if (at != null) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              'Karar: ${at.asShortDateTime}',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            'Yeni fotoğraflarla aşağıdan tekrar gönderebilirsin.',
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
