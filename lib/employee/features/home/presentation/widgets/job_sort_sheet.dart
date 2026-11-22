import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/filter_pill.dart';

/// Sıralama menüsü; seçenekler [JobSortOption]'dan (sunucu beyaz liste
/// uyguluyor). "En yakın" izin yoksa kapalı ve sebebi yazılı.
class JobSortSheet extends StatelessWidget {
  const JobSortSheet({
    super.key,
    required this.selected,
    this.hasLocation = false,
  });

  final JobSortOption selected;
  final bool hasLocation;

  /// Vazgeçilirse `null`.
  static Future<JobSortOption?> show(
    BuildContext context, {
    required JobSortOption selected,
    bool hasLocation = false,
  }) {
    return AppBottomSheet.show<JobSortOption>(
      context,
      builder: (_) =>
          JobSortSheet(selected: selected, hasLocation: hasLocation),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Sırala',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSizes.spaceSmall,
            runSpacing: AppSizes.spaceSmall,
            children: [
              for (final option in JobSortOption.values)
                FilterPill(
                  label: option.label,
                  isSelected: option == selected,
                  enabled: !option.requiresOrigin || hasLocation,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
          if (!hasLocation) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Yakınlık sıralaması için konum izni gerekiyor.',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
