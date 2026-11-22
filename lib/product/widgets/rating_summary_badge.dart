import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Puan özeti (`★ 4.5 (12)`). Değerlendirmesi olmayana "0.0" yazmak kötü puanlı
/// gösterir; çağıran [RatingSummary.hasRating]'e bakmalı.
class RatingSummaryBadge extends StatelessWidget {
  const RatingSummaryBadge({super.key, required this.summary});

  final RatingSummary summary;

  static const double _starSize = 20;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(
          AppIcons.star,
          filled: true,
          color: AppColors.rating,
          size: _starSize,
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
}
