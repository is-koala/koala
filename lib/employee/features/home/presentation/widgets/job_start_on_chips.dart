import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job_start_on.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/widgets/filter_pill.dart';

/// Keşif başlangıç günü çipleri: Bugün / Yarın / Hafta sonu / Bu hafta /
/// Tarih seç.
///
/// Seçim [onChanged]'e düşer; seçili çipe tekrar basmak süzgeci temizler.
class JobStartOnChips extends StatelessWidget {
  const JobStartOnChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final JobStartOn? selected;
  final ValueChanged<JobStartOn?> onChanged;

  static const _presets = [
    JobStartOn.today,
    JobStartOn.tomorrow,
    JobStartOn.weekend,
    JobStartOn.thisWeek,
  ];

  @override
  Widget build(BuildContext context) {
    final customDay = selected?.day;
    final customSelected = customDay != null;

    return Wrap(
      spacing: AppSizes.spaceSmall,
      runSpacing: AppSizes.spaceSmall,
      children: [
        for (final preset in _presets)
          FilterPill(
            label: preset.label,
            isSelected: selected == preset,
            onTap: () => onChanged(selected == preset ? null : preset),
          ),
        FilterPill(
          label: customSelected ? selected!.label : 'Tarih seç',
          isSelected: customSelected,
          onTap: () => _pickDay(context),
        ),
      ],
    );
  }

  Future<void> _pickDay(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = selected?.day ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Başlangıç günü',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (picked == null) return;
    onChanged(JobStartOn.calendarDay(picked));
  }
}
