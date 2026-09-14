import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İlanı kimin açtığını söyleyen küçük rozet: "Kurumsal" ya da "Bireysel".
///
/// `employerType` sunucudan her ilanla geliyordu ama hiçbir ekran
/// çizmiyordu (is-koala/koala#177). İşlerim satırı, iş detayındaki işveren
/// kartı ve ilan detayı sheet'i aynı rozeti kullanıyor; o yüzden
/// `employee/core/` altında.
class EmployerTypeBadge extends StatelessWidget {
  const EmployerTypeBadge({super.key, required this.type, this.color});

  final JobEmployerType type;

  /// Metin, ikon ve çerçeve rengi. Verilmezse ikincil metin rengi; renkli
  /// bölüm zeminlerinde satırın kendi ön rengi geçiliyor.
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
