import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Bir atamanın cihazda bekleyen veya destek isteyen mesai kayıtları.
class TimesheetQueueStatus extends StatelessWidget {
  const TimesheetQueueStatus({super.key, required this.events, this.onSupport});

  final List<TimesheetEvent> events;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final supportEvent = events
        .where((event) => event.requiresSupport)
        .firstOrNull;
    final needsSupport = supportEvent != null;
    final color = needsSupport ? AppColors.danger : AppColors.warning;
    final message = needsSupport
        ? supportEvent.supportMessage ?? 'Mesai kaydı için destek gerekiyor.'
        : events.length == 1
        ? 'Kaydedildi, gönderilmeyi bekliyor.'
        : '${events.length} mesai kaydı gönderilmeyi bekliyor.';

    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: AppColors.surfaceTintAlpha),
          context.tileColor,
        ),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            needsSupport ? AppIcons.alert : AppIcons.antenna,
            color: color,
            size: AppSizes.iconMedium,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (needsSupport && onSupport != null)
                  TextButton(
                    onPressed: onSupport,
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: AppPadding.zero,
                    ),
                    child: const Text('Destek Al'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
