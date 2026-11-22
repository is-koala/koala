import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Formda onaylı adresin özetini gösterir, dokununca harita ekranını açar.
/// Adres yokken çerçeve vurgu renginde: alan zorunlu.
class ConfirmedAddressField extends StatelessWidget {
  const ConfirmedAddressField({
    super.key,
    required this.value,
    required this.onTap,
    this.label = 'Adres *',
    this.placeholder = 'Haritadan seçin',
    this.errorText,
  });

  final ConfirmedAddress? value;
  final VoidCallback onTap;
  final String label;
  final String placeholder;

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final address = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.innerCircular,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: AppSizes.fieldHeight),
            padding: AppPadding.infoTile,
            decoration: BoxDecoration(
              border: Border.all(
                color: address == null
                    ? context.accentColor
                    : context.dividerColor,
              ),
              borderRadius: AppRadius.innerCircular,
            ),
            child: Row(
              children: [
                AppIcon(AppIcons.location, color: context.accentColor),
                const SizedBox(width: AppSizes.space),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.smallGap),
                      Text(
                        address?.summary ?? placeholder,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: address == null
                              ? context.textTertiary
                              : context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spaceSmall),
                AppIcon(
                  AppIcons.arrowRight,
                  size: AppSizes.iconMedium,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppPadding.primary,
              top: AppSizes.spaceTiny,
            ),
            child: Text(
              errorText!,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
      ],
    );
  }
}
