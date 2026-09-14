import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_badge.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Adayın itibarı: puan özeti, tamamlanan iş sayısı, rozetler ve son
/// yorumlar. Salt çizim; veriyi sayfa çekiyor ve her parça tek tek boş
/// olabiliyor.
///
/// Boş ile hatalı ayrı: hiç değerlendirilmemiş aday "henüz puan yok"
/// görüyor, uç cevap vermediğinde ise şerit ve *Tekrar dene*. Hata gelse de
/// elde olan parçalar çiziliyor — puan gelmiş yorum gelmemişse puan durur.
class BCandidateReputationSection extends StatelessWidget {
  const BCandidateReputationSection({
    super.key,
    required this.isLoading,
    required this.onRetry,
    this.summary,
    this.reviews = const [],
    this.badges,
    this.completedJobCount,
    this.errorMessage,
  });

  /// Puan özeti; hiç değerlendirilmemiş adayda `null`.
  final RatingSummary? summary;

  /// Son yorumlar, yeniden eskiye; sayfa kaç tane istediyse o kadar.
  final List<Review> reviews;

  /// Rozetler; sunucudan henüz gelmediyse `null`, hiç yoksa boş liste.
  final List<BBadge>? badges;

  /// Tamamlanan iş sayısı; sunucu göndermiyorsa `null` ve satır çizilmiyor.
  final int? completedJobCount;

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  /// Puan rozetindeki yıldız.
  static const double _summaryStarSize = 20;

  /// Yorum satırındaki yazar fotoğrafı.
  static const double _authorAvatarSize = 36;

  /// Rozet çipindeki görsel.
  static const double _badgeIconSize = 18;

  /// Rozet çipinin zemin opaklığı; diğer rozetlerle aynı.
  static const double _tintAlpha = 0.12;

  static const int _maxRating = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: AppSizes.space),
        if (isLoading && reviews.isEmpty && badges == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (errorMessage != null) ...[
            _errorStrip(context, errorMessage!),
            const SizedBox(height: AppSizes.space),
          ],
          _statsPanel(context),
          const SizedBox(height: AppSizes.space),
          _reviewsPanel(context),
        ],
      ],
    );
  }

  /// Başlık ve puan rozeti aynı satırda.
  Widget _header(BuildContext context) {
    final summary = this.summary;

    return Row(
      children: [
        Text('Değerlendirmeler', style: context.textTheme.titleMedium),
        const Spacer(),
        // Değerlendirmesi olmayana "0.0" yazmak onu kötü puanlı gösterirdi.
        if (summary != null && summary.hasRating)
          _summaryBadge(context, summary)
        else if (!isLoading)
          Text(
            'Henüz puan yok',
            key: const ValueKey('candidate-no-rating'),
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
      ],
    );
  }

  Widget _summaryBadge(BuildContext context, RatingSummary summary) {
    return Row(
      key: const ValueKey('candidate-rating-summary'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(
          AppIcons.star,
          filled: true,
          color: AppColors.rating,
          size: _summaryStarSize,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          summary.averageRating.toStringAsFixed(1),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          '(${summary.reviewCount})',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Tamamlanan iş sayısı ve rozetler.
  Widget _statsPanel(BuildContext context) {
    final count = completedJobCount;
    final badges = this.badges;

    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (count != null) ...[
            Row(
              children: [
                AppIcon(
                  AppIcons.checkCircle,
                  size: AppSizes.iconSmall,
                  color: context.accentColor,
                ),
                const SizedBox(width: AppSizes.spaceSmall),
                Text(
                  'Tamamlanan iş: $count',
                  key: const ValueKey('candidate-completed-jobs'),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space),
          ],
          Text(
            'Rozetler',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          if (badges == null)
            Text(
              'Rozetler yükleniyor...',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
            )
          else if (badges.isEmpty)
            Text(
              'Henüz rozet kazanmamış.',
              key: const ValueKey('candidate-no-badges'),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: AppSizes.spaceSmall,
              runSpacing: AppSizes.spaceSmall,
              children: [
                for (final badge in badges) _badgeChip(context, badge),
              ],
            ),
        ],
      ),
    );
  }

  /// Tek rozet: görsel (yoksa yıldız), ad ve kademe.
  Widget _badgeChip(BuildContext context, BBadge badge) {
    final iconUrl = badge.iconUrl;
    final tier = badge.tierLabel;

    return Tooltip(
      message: badge.description ?? badge.name,
      child: Container(
        key: ValueKey('candidate-badge-${badge.code}'),
        padding: AppPadding.badge,
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: _tintAlpha),
          borderRadius: AppRadius.stadiumCircular,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconUrl != null && iconUrl.isNotEmpty)
              Image.network(
                iconUrl,
                width: _badgeIconSize,
                height: _badgeIconSize,
                errorBuilder: (_, _, _) => _badgeFallbackIcon(context),
              )
            else
              _badgeFallbackIcon(context),
            const SizedBox(width: AppSizes.spaceTiny),
            Text(
              tier == null ? badge.name : '${badge.name} · $tier',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeFallbackIcon(BuildContext context) => AppIcon(
    AppIcons.star,
    filled: true,
    size: _badgeIconSize,
    color: context.accentColor,
  );

  /// Son yorumlar; yoksa öyle yazıyor.
  Widget _reviewsPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration(context),
      child: reviews.isEmpty
          ? Text(
              'Henüz değerlendirme yok. Aday işleri tamamladıkça işverenler '
              'buraya yazabilir.',
              key: const ValueKey('candidate-no-reviews'),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < reviews.length; index++) ...[
                  _reviewTile(context, reviews[index]),
                  if (index != reviews.length - 1)
                    const SizedBox(height: AppSizes.space),
                ],
              ],
            ),
    );
  }

  Widget _reviewTile(BuildContext context, Review review) {
    return Row(
      key: ValueKey('candidate-review-${review.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Anonim değerlendirmede yazar gelmiyor; boş durum varsayılan koala.
        ProfileAvatar(
          imageUrl: review.author?.profilePictureUrl,
          size: _authorAvatarSize,
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.authorLabel,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: review.isAnonymous
                            ? context.textSecondary
                            : null,
                        fontStyle: review.isAnonymous ? FontStyle.italic : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (review.createdAt != null)
                    Text(
                      review.createdAt!.asShortDate,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.smallGap),
              _stars(context, review.rating),
              if (review.hasComment) ...[
                const SizedBox(height: AppSizes.spaceTiny),
                Text(
                  review.comment!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stars(BuildContext context, int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_maxRating, (index) {
        final isFilled = index < rating;

        return AppIcon(
          AppIcons.star,
          filled: isFilled,
          color: isFilled ? AppColors.rating : context.dividerColor,
          size: AppSizes.iconSmall,
        );
      }),
    );
  }

  /// Uçlar cevap vermediğinde: mesaj ve tekrar deneme. Profilin geri kalanı
  /// yerinde kalıyor.
  Widget _errorStrip(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('candidate-reputation-retry'),
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration(BuildContext context) => BoxDecoration(
    color: context.tileColor,
    borderRadius: AppRadius.innerCircular,
  );
}
