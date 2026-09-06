import 'package:flutter/material.dart';
import 'package:koala/employee/features/profile/models/availability_slot.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Haftalık ızgarada tek günün saat aralıklarını düzenleyen satır.
class AvailabilityDayEditor extends StatelessWidget {
  const AvailabilityDayEditor({
    super.key,
    required this.dayOfWeek,
    required this.slots,
    required this.onAdd,
    required this.onRemove,
  });

  final String dayOfWeek;
  final List<AvailabilitySlot> slots;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AvailabilitySlot.labelForDay(dayOfWeek),
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: AppIcon(
                  AppIcons.plus,
                  size: AppSizes.iconSmall,
                  color: context.accentColor,
                ),
                label: const Text('Aralık Ekle'),
              ),
            ],
          ),
          if (slots.isEmpty)
            Text(
              'Müsait değil',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
            )
          else
            ...slots.asMap().entries.map((entry) {
              final slot = entry.value;
              return Row(
                children: [
                  AppIcon(
                    AppIcons.clock,
                    size: AppSizes.iconSmall,
                    color: AppColors.successStrong,
                  ),
                  const SizedBox(width: AppSizes.spaceSmall),
                  Expanded(
                    child: Text(
                      slot.timeLabel,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '${slot.timeLabel} aralığını kaldır',
                    onPressed: () => onRemove(entry.key),
                    icon: const AppIcon(
                      AppIcons.delete,
                      size: AppSizes.iconSmall,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
