import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Tek renkli küçük durum rozeti: renk tonu zemin, rengin kendisi metin.
///
/// Oturum listesindeki "Bu cihaz" ve ayrıntıdaki Başarılı / Başarısız
/// rozetleri aynı kabuğu çiziyor; şekil tek yerde dursun diye çıkarıldı.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, required this.color});

  final String text;

  /// Rozetin anlam rengi (`AppColors.success` gibi); zemin bunun soluk tonu.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        text,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// İsteği atan oturumun rozeti. Sunucu `current` ile işaretliyor; liste ve
/// ayrıntı aynı rozeti çiziyor.
class CurrentSessionBadge extends StatelessWidget {
  const CurrentSessionBadge({super.key});

  static const String label = 'Bu cihaz';

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(label, color: AppColors.success);
  }
}
