import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Bir formun içinde onaylı adresi gösteren ve dokununca harita ekranını
/// açan alan.
///
/// İlan ve şirket formları adresi kendi isteklerinin içinde gönderdiği için
/// `MapFirstAddressPage` onlara yalnız [ConfirmedAddress] döndürür; bu alan
/// o değerin özetini formun ızgarasında gösterir. Adres yokken çerçeve vurgu
/// rengiyle çizilir: alan zorunlu ve dokunulacak yer burası.
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

  /// Formun doğrulaması bu alanı eksik bulduğunda altına yazılan satır.
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
