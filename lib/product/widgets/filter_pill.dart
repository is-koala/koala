import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Süzgeç seçenek hapı. Adı `FilterChip` değil: Material'inkiyle çakışırdı.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.onRemove,
    this.enabled = true,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Verilirse sağda çarpı çizilir (etkin süzgeç özetinde).
  final VoidCallback? onRemove;

  /// Kapalıyken soluk ve dokunulmaz; nedeni yanındaki açıklama söylüyor.
  final bool enabled;

  static const double _selectedAlpha = 0.15;

  static const double _disabledOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final foreground = isSelected ? accent : context.textPrimary;

    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppPadding.primary,
        vertical: AppSizes.space,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: _selectedAlpha)
            : context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: isSelected ? accent : context.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: AppSizes.spaceSmall),
            GestureDetector(
              onTap: enabled ? onRemove : null,
              child: AppIcon(
                AppIcons.close,
                size: AppSizes.iconSmall,
                color: foreground,
              ),
            ),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : _disabledOpacity,
      child: GestureDetector(onTap: enabled ? onTap : null, child: pill),
    );
  }
}
