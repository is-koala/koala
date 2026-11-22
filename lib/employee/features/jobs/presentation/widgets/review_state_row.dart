import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Tamamlanmış atamanın değerlendirme satırı; iki kabuk ortak.
///
/// - [ownReview] doluysa "Değerlendirdiniz: ★N · "yorum"", düğme yok.
/// - [hasReviewed] ama içerik yoksa "Değerlendirdiniz."
/// - Değilse [pendingText] ve düğme.
///
/// [counterpartyReviewed] ise karşı tarafın değerlendirmesinin yalnız
/// **varlığı** rozetle yazılır.
class ReviewStateRow extends StatelessWidget {
  const ReviewStateRow({
    super.key,
    required this.ownReview,
    required this.hasReviewed,
    required this.counterpartyReviewed,
    required this.pendingText,
    required this.buttonLabel,
    required this.onReview,
    this.buttonKey,
  });

  /// `null` "değerlendirilmedi" demek değil.
  final Review? ownReview;

  final bool hasReviewed;

  final bool counterpartyReviewed;

  final String pendingText;

  final String buttonLabel;

  /// `null` ise düğme devre dışı.
  final VoidCallback? onReview;

  final Key? buttonKey;

  static const String counterpartyBadgeText = 'Karşı taraf sizi değerlendirdi';

  @override
  Widget build(BuildContext context) {
    final reviewed = hasReviewed || ownReview != null;
    final own = ownReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIcon(
              reviewed ? AppIcons.checkCircle : AppIcons.star,
              size: AppSizes.iconMedium,
              color: reviewed ? AppColors.success : AppColors.rating,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                reviewed
                    ? (own == null
                          ? 'Değerlendirdiniz.'
                          : 'Değerlendirdiniz: ${own.summaryLabel}')
                    : pendingText,
                style: context.textTheme.bodyMedium,
              ),
            ),
            if (!reviewed)
              TextButton(
                key: buttonKey,
                onPressed: onReview,
                child: Text(buttonLabel),
              ),
          ],
        ),
        if (counterpartyReviewed) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          _counterpartyBadge(context),
        ],
      ],
    );
  }

  Widget _counterpartyBadge(BuildContext context) {
    return Container(
      key: const ValueKey('review-counterparty-badge'),
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: context.payoutSurface,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIcons.star,
            size: AppSizes.iconSmall,
            color: AppColors.rating,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            counterpartyBadgeText,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
