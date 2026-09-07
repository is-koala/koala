import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/filter_pill.dart';

/// Keşfet listesinin sıralama menüsü.
///
/// Seçenekler [JobSortOption]'dan **türetiliyor**, elle yazılmıyor: sunucu
/// sıralamayı beyaz listeliyor ve listede olmayan bir alan boş sonuç değil
/// `400` (`PAGE_SORT_FIELD_NOT_ALLOWED`) döndürüyor. Menüye elle bir dize
/// eklenirse ilk denemede hata alınır; enum bunu imkânsız kılıyor.
///
/// **"En yakın" bilerek yok.** Sunucunun `SORTABLE_FIELDS` kümesinde mesafe
/// yok, yani böyle bir seçenek yalnızca o ana kadar yüklenmiş sayfaları
/// sıralardı ve sonsuz kaydırmayla birlikte kartlar gözün önünde yer
/// değiştirirdi. Mesafe bunun yerine **süzgeç** tarafında duruyor: kullanıcının
/// çevresinde bir sınırlayıcı kutu olarak sunucuya gidiyor, sonuç zaten yakın
/// ilanlardan oluşuyor.
class JobSortSheet extends StatelessWidget {
  const JobSortSheet({super.key, required this.selected});

  final JobSortOption selected;

  /// Sheet'i açar ve seçilen sıralamayı döndürür; vazgeçilirse `null`.
  static Future<JobSortOption?> show(
    BuildContext context, {
    required JobSortOption selected,
  }) {
    return AppBottomSheet.show<JobSortOption>(
      context,
      builder: (_) => JobSortSheet(selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Sırala',
      child: Wrap(
        spacing: AppSizes.spaceSmall,
        runSpacing: AppSizes.spaceSmall,
        children: [
          for (final option in JobSortOption.values)
            FilterPill(
              label: option.label,
              isSelected: option == selected,
              onTap: () => Navigator.pop(context, option),
            ),
        ],
      ),
    );
  }
}
