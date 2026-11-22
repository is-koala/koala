import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Numaralı yönerge satırı; çip okuma iki fiziksel adım, sıra görünmezse tarama
/// atlanıyor.
class IdentityStepRow extends StatelessWidget {
  const IdentityStepRow({
    super.key,
    required this.order,
    required this.title,
    required this.description,
  });

  final int order;

  final String title;
  final String description;

  static const double _badgeSize = 28.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _badgeSize,
          height: _badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.accentColor,
            borderRadius: AppRadius.stadiumCircular,
          ),
          child: Text(
            '$order',
            // Renk açıkça verilmezse slotun koyu rengi kalır.
            style: context.textTheme.labelLarge?.copyWith(
              color: AppColors.onAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textTheme.titleSmall),
              const SizedBox(height: AppSizes.smallGap),
              Text(
                description,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
