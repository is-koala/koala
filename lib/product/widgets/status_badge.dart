import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Tek renkli küçük durum rozeti: rengin tonu zemin, kendisi metin.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, required this.color});

  final String text;

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

/// İsteği atan oturumun rozeti ("Bu cihaz").
class CurrentSessionBadge extends StatelessWidget {
  const CurrentSessionBadge({super.key});

  static const String label = 'Bu cihaz';

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(label, color: AppColors.success);
  }
}
