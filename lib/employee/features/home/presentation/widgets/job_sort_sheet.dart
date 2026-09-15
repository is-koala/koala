import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/filter_pill.dart';

/// Keşfet listesinin sıralama menüsü.
///
/// Seçenekler [JobSortOption]'dan **türetiliyor**, elle yazılmıyor: sunucu
/// sıralamayı beyaz listeliyor ve listede olmayan bir alan boş sonuç değil
/// `400` (`PAGE_SORT_FIELD_NOT_ALLOWED`) döndürüyor.
///
/// "En yakın" konum ister: `lat`/`lng` + `sort=distance,asc`. İzin yoksa
/// seçenek kapalı çizilir ve sebebi yazılır; sessizce yok sayılmaz.
class JobSortSheet extends StatelessWidget {
  const JobSortSheet({
    super.key,
    required this.selected,
    this.hasLocation = false,
  });

  final JobSortOption selected;
  final bool hasLocation;

  /// Sheet'i açar ve seçilen sıralamayı döndürür; vazgeçilirse `null`.
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
