import 'package:flutter/material.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final double? distance;

  const JobCard({super.key, required this.job, this.distance});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.secondaryCircular,
    );

    return Card(
      elevation: 0,
      // Sayfa zemini geri çekilmiş bir ton (bkz. context.recessedColor);
      // kart onun üstünde yükseliyor.
      color: context.raisedColor,
      margin: const EdgeInsets.only(bottom: AppSizes.space),
      shape: shape,
      child: ListTile(
        shape: shape,
        contentPadding: AppPadding.primaryAll,
        leading: _leading(),
        title: Text(job.title, style: context.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              job.subtitle,
              style: context.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (distance != null) ...[
              const SizedBox(height: AppSizes.spaceTiny),
              _distanceRow(context),
            ],
          ],
        ),
        // Column, fiyatı satırın ortasına değil üstüne hizalıyor; kaldırılırsa
        // fiyat dikeyde kayar.
        trailing: Column(
          children: [
            Text(
              '₺${job.price.toStringAsFixed(0)}',
              style: context.textTheme.titleSmall?.copyWith(
                color: context.accentColor,
              ),
            ),
          ],
        ),
        onTap: () => JobDetailBottomSheet.show(context, job),
      ),
    );
  }

  Widget _leading() {
    final coverImageUrl = job.coverImageUrl;
    if (coverImageUrl == null || coverImageUrl.isEmpty) {
      return _categoryAvatar();
    }

    return ClipRRect(
      borderRadius: AppRadius.innerCircular,
      child: Image.network(
        coverImageUrl,
        width: AppSizes.thumbnail,
        height: AppSizes.thumbnail,
        fit: BoxFit.cover,
        semanticLabel: 'İlan kapağı',
        errorBuilder: (_, _, _) => _categoryAvatar(),
      ),
    );
  }

  Widget _categoryAvatar() {
    return CircleAvatar(
      backgroundColor: job.category.color,
      // Kategori rengi doygun ve temadan bağımsız; üstündeki ikon da öyle.
      child: AppIcon(
        job.category.icon,
        color: AppColors.onAccent,
        size: AppSizes.icon,
      ),
    );
  }

  Widget _distanceRow(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          // Çözünürlüğü ilanın kesinliği belirliyor: yuvarlanmış bir
          // koordinattan çıkan uzaklığı ondalıklı yazmak, veride olmayan bir
          // hassasiyeti iddia etmek olurdu.
          job.distanceLabel(distance!),
          style: context.textTheme.labelMedium?.copyWith(
            color: context.accentColor,
          ),
        ),
      ],
    );
  }
}
