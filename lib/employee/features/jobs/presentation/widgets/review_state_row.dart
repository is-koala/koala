import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Tamamlanmış bir atamanın değerlendirme satırı.
///
/// İki kabuk aynı satırı çiziyor — çalışanın iş detayı ve işverenin atama
/// paneli — bu yüzden metinler dışarıdan geliyor, karar tek yerde:
///
/// - [ownReview] doluysa "Değerlendirdiniz: ★N · "yorum"", düğme yok.
/// - [hasReviewed] ama içerik yoksa (eski sunucunun `409`u) "Değerlendirdiniz."
/// - Değilse [pendingText] ve [buttonLabel] ile düğme.
///
/// [counterpartyReviewed] doğruysa altta küçük bir rozet: karşı tarafın
/// değerlendirmesinin **varlığı** yazılıyor, içeriği değil — sunucu da
/// yalnız varlığı gönderiyor.
///
/// Sohbet parçaları gibi işveren kabuğu bu widget'ı çalışan tarafından alıyor;
/// [Review] modeli burada yaşadığı için `product/`'a taşınmadı.
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

  /// İçeriği bilinen değerlendirme; `null` "değerlendirilmedi" demek değil.
  final Review? ownReview;

  /// Değerlendirilmiş mi; [ownReview] `null` iken de doğru olabilir.
  final bool hasReviewed;

  final bool counterpartyReviewed;

  /// Henüz değerlendirilmemişken yazılan cümle.
  final String pendingText;

  final String buttonLabel;

  /// Düğmenin eylemi; `null` ise düğme devre dışı (bir eylem sürüyor).
  final VoidCallback? onReview;

  final Key? buttonKey;

  /// Karşı taraf rozetinin metni; iki kabukta da aynı.
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
