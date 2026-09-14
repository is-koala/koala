import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Puan özeti rozeti: yıldız, ortalama ve parantez içinde değerlendirme
/// sayısı — `★ 4.5 (12)`.
///
/// Çağıran [RatingSummary.hasRating]'e bakmalı: değerlendirmesi olmayana
/// "0.0" yazmak onu kötü puanlı gösterirdi, o durumda bu rozet çizilmez.
class RatingSummaryBadge extends StatelessWidget {
  const RatingSummaryBadge({super.key, required this.summary});

  final RatingSummary summary;

  /// Rozetteki yıldız; satır metninden bir kademe büyük.
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
