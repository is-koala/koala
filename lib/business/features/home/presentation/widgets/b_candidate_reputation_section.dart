import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/rating_summary_badge.dart';
import 'package:koala/product/widgets/review_tile.dart';

/// Adayın itibarı: puan, tamamlanan iş, rozetler, son yorumlar. Boş ile hatalı
/// ayrı çiziliyor ("henüz puan yok" / "puan alınamadı"); hata gelse de elde
/// olan parçalar duruyor.
class BCandidateReputationSection extends StatelessWidget {
  const BCandidateReputationSection({
    super.key,
    required this.isLoading,
    required this.onRetry,
    this.summary,
    this.summaryFailed = false,
    this.reviews = const [],
    this.badges,
    this.badgesFailed = false,
    this.completedJobCount,
    this.errorMessage,
  });

  /// Hiç değerlendirilmemişse `null`.
  final RatingSummary? summary;

  final bool summaryFailed;

  final List<Review> reviews;

  /// Gelmediyse `null`, hiç yoksa boş.
  final List<UserBadge>? badges;

  final bool badgesFailed;

  /// Sunucu göndermiyorsa `null`, satır çizilmez.
  final int? completedJobCount;

  final bool isLoading;

  final String? errorMessage;
  final VoidCallback onRetry;

  static const double _badgeIconSize = 18;

  static const double _tintAlpha = 0.12;

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

  Widget _header(BuildContext context) {
    final summary = this.summary;
    final muted = context.textTheme.labelMedium?.copyWith(
      color: context.textTertiary,
    );

    return Row(
      children: [
        Text('Değerlendirmeler', style: context.textTheme.titleMedium),
        const Spacer(),
        // Değerlendirmesiz adaya "0.0" yazmak kötü puan gibi görünür.
        if (summary != null && summary.hasRating)
          KeyedSubtree(
            key: const ValueKey('candidate-rating-summary'),
            child: RatingSummaryBadge(summary: summary),
          )
        else if (summaryFailed)
          Text(
            'Puan alınamadı',
            key: const ValueKey('candidate-rating-failed'),
            style: muted,
          )
        else if (!isLoading)
          Text(
            'Henüz puan yok',
            key: const ValueKey('candidate-no-rating'),
            style: muted,
          ),
      ],
    );
  }

  Widget _statsPanel(BuildContext context) {
    final count = completedJobCount;

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
          _badgesBody(context),
        ],
      ),
    );
  }

  Widget _badgesBody(BuildContext context) {
    final badges = this.badges;
    final muted = context.textTheme.bodySmall?.copyWith(
      color: context.textSecondary,
    );

    if (badges == null) {
      if (badgesFailed) {
        return Text(
          'Rozetler alınamadı.',
          key: const ValueKey('candidate-badges-failed'),
          style: muted,
        );
      }
      return Text(
        isLoading ? 'Rozetler yükleniyor...' : 'Rozet bilgisi yok.',
        key: const ValueKey('candidate-badges-pending'),
        style: context.textTheme.bodySmall?.copyWith(
          color: context.textTertiary,
        ),
      );
    }
    if (badges.isEmpty) {
      return Text(
        'Henüz rozet kazanmamış.',
        key: const ValueKey('candidate-no-badges'),
        style: muted,
      );
    }
    return Wrap(
      spacing: AppSizes.spaceSmall,
      runSpacing: AppSizes.spaceSmall,
      children: [for (final badge in badges) _badgeChip(context, badge)],
    );
  }

  Widget _badgeChip(BuildContext context, UserBadge badge) {
    final tier = badge.tier.label;

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
            _badgeVisual(context, badge),
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

  /// Önce yerel varlık, yoksa sunucu ikonu, o da yoksa yıldız.
  Widget _badgeVisual(BuildContext context, UserBadge badge) {
    final asset = badge.localAsset;
    final url = badge.iconUrl;
    final fallback = AppIcon(
      AppIcons.star,
      filled: true,
      size: _badgeIconSize,
      color: context.accentColor,
    );

    if (asset != null) {
      return Image.asset(asset, width: _badgeIconSize, height: _badgeIconSize);
    }
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: _badgeIconSize,
        height: _badgeIconSize,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return fallback;
  }

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
                  KeyedSubtree(
                    key: ValueKey('candidate-review-${reviews[index].id}'),
                    child: ReviewTile(review: reviews[index]),
                  ),
                  if (index != reviews.length - 1)
                    const SizedBox(height: AppSizes.space),
                ],
              ],
            ),
    );
  }

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
