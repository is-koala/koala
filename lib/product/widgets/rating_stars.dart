import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Beş yıldızlık puan satırı: dolu yıldızlar puan renginde, kalanı çizgi.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating});

  /// 1 ile 5 arası.
  final int rating;

  /// Sunucunun `@Max(5)` sınırı.
  static const int maxRating = 5;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
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
}
