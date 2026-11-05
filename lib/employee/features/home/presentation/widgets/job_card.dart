import 'package:flutter/material.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

class JobCard extends StatelessWidget {
  final Job job;

  const JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.secondaryCircular,
    );
    final distanceKm = job.distanceKm;

    return Card(
      elevation: 0,
      // Uygulamanın kart rengi; liste sayfasında da, haritadaki grup
      // listesinde (beyaz sheet) de zeminden ayrılıyor.
      color: context.tileColor,
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
            if (distanceKm != null) ...[
              const SizedBox(height: AppSizes.spaceTiny),
              _distanceRow(context, distanceKm),
            ],
            // `JobSummaryDto.hasShuttle` (is-koala/koala#197): ilanın servisi
            // var; ayrıntı ilan detayındaki ulaşım kartında.
            if (job.hasShuttle) ...[
              const SizedBox(height: AppSizes.spaceTiny),
              _shuttleChip(context),
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

  Widget _shuttleChip(BuildContext context) {
    return Container(
      key: const ValueKey('job-card-shuttle'),
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(
          alpha: AppColors.surfaceTintAlpha,
        ),
        borderRadius: AppRadius.stadiumCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIcons.bus,
            size: AppSizes.iconSmall,
            color: context.accentColor,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            'Servis var',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _distanceRow(BuildContext context, double kilometersAway) {
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
          job.distanceLabel(kilometersAway),
          style: context.textTheme.labelMedium?.copyWith(
            color: context.accentColor,
          ),
        ),
      ],
    );
  }
}
