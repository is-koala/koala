import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İlanı kimin açtığı: "Kurumsal" ya da "Bireysel" (#177).
class EmployerTypeBadge extends StatelessWidget {
  const EmployerTypeBadge({super.key, required this.type, this.color});

  final JobEmployerType type;

  /// Verilmezse ikincil metin rengi.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.textSecondary;

    return Semantics(
      label: 'İşveren türü: ${type.displayName}',
      child: Container(
        padding: AppPadding.badge,
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: AppColors.surfaceTintAlpha),
          borderRadius: AppRadius.stadiumCircular,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              type == JobEmployerType.company
                  ? AppIcons.building
                  : AppIcons.user,
              size: AppSizes.iconSmall,
              color: foreground,
            ),
            const SizedBox(width: AppSizes.spaceTiny),
            Text(
              type.displayName,
              style: context.textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
