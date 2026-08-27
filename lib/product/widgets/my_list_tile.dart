import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class MyListTile extends StatelessWidget {
  const MyListTile({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.value,
  });

  final String title;
  final AppIconData icon;
  final VoidCallback? onTap;

  /// Satırın sağında, chevron'dan önce gösterilen mevcut değer. Ayarın o
  /// anki durumunu satırı açmadan görebilmek için (örn. "Sistem").
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Material(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          borderRadius: AppRadius.innerCircular,
          onTap: onTap,
          child: Container(
            padding: AppPadding.tileTall,
            decoration: BoxDecoration(
              borderRadius: AppRadius.innerCircular,
              border: Border.all(color: context.dividerColor),
            ),
            child: Row(
              children: [
                HugeIcon(icon: icon, color: context.textPrimary),
                const SizedBox(width: AppSizes.spaceMedium),
                Expanded(
                  child: Text(
                    title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (value != null) ...[
                  Text(
                    value!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSmall),
                ],
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconMedium,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
