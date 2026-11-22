import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İşveren navbar öğesi; zemin temadan bağımsız yeşil, renkler [AppColors]'tan.
class BNavItem extends StatelessWidget {
  final int index;
  final AppIconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String? label;

  /// Ortadaki "ilan oluştur": beyaz dolu daire, etiketsiz.
  final bool? centerItem;

  const BNavItem({
    super.key,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    this.label,
    this.centerItem,
  });

  static const double _idleAlpha = 0.7;

  @override
  Widget build(BuildContext context) {
    final isCenter = centerItem == true;
    final radius = isCenter
        ? AppRadius.stadiumCircular
        : AppRadius.secondaryCircular;
    final foreground = isSelected
        ? AppColors.onAccent
        : (isCenter
              ? AppColors.primaryColor
              : AppColors.onAccent.withValues(alpha: _idleAlpha));

    return Material(
      color: AppColors.primaryColor,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isCenter ? AppColors.onAccent : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(
              isCenter ? AppSizes.spaceMedium : AppSizes.spaceSmall,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  icon,
                  size: AppSizes.icon,
                  color: foreground,
                  filled: isSelected,
                ),
                if (!isCenter && label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
                    child: Text(
                      label!,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
