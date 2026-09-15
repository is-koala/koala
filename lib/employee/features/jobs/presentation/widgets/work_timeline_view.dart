import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job_start_on.dart';
import 'package:koala/employee/features/jobs/models/work_timeline.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';

/// İşin zaman çizelgesi: sol kenarda noktalar ve çizgi, sağda olay ve anı.
///
/// Satırların hangileri olduğuna [WorkTimeline.build] karar veriyor; burası
/// yalnızca çiziyor. Damgalar UTC geliyor, ekrana İstanbul duvar saatiyle yazılıyor.
class WorkTimelineView extends StatelessWidget {
  const WorkTimelineView({super.key, required this.entries});

  final List<WorkTimelineEntry> entries;

  /// Çizelge noktasının çapı ve satırlar arasındaki çizginin kalınlığı.
  static const double _dotSize = 10;
  static const double _lineWidth = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, entry) in entries.indexed)
          _row(context, entry, isLast: index == entries.length - 1),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    WorkTimelineEntry entry, {
    required bool isLast,
  }) {
    final detail = entry.detail;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSizes.iconMedium,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
                  child: Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      color: context.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: _lineWidth,
                      color: context.dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSizes.space),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    IstanbulCalendar.wallClockOf(entry.at).asShortDateTime,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
