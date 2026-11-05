import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Bir biniş okutmasının sonucunun türü.
enum BoardingResultTone {
  /// Kaydedildi.
  success,

  /// Cihazda saklandı, sonra gönderilecek.
  queued,

  /// Kaydedilemedi.
  failure,
}

/// Okutma sonucunu çizen kutu; işçinin ve işverenin tarama ekranları ve
/// telefon kamerasıyla açılan bağlantı sayfası aynı dili kullanıyor.
class BoardingResultPanel extends StatelessWidget {
  const BoardingResultPanel({
    super.key,
    required this.tone,
    required this.message,
    this.detail,
  });

  final BoardingResultTone tone;
  final String message;

  /// İkinci satır (bayraklar, "daha önce kaydedilmişti" gibi).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final (Color color, AppIconData icon) = switch (tone) {
      BoardingResultTone.success => (AppColors.success, AppIcons.checkCircle),
      BoardingResultTone.queued => (AppColors.info, AppIcons.info),
      BoardingResultTone.failure => (AppColors.danger, AppIcons.alert),
    };
    final detail = this.detail;

    return Container(
      key: ValueKey('boarding-result-${tone.name}'),
      width: double.infinity,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: AppSizes.iconMedium, color: color),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: AppSizes.spaceTiny),
                  Text(
                    detail,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
