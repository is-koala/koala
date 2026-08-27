import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class SavedJobsPage extends StatelessWidget {
  const SavedJobsPage({super.key});

  /// Boş durum ikonu; sayfanın tek görseli olduğu için normal ikonlardan
  /// belirgin biçimde büyük.
  static const double _emptyIconSize = 80;

  /// Kaydırıp silme sırasında açılan kırmızı zeminin sağ boşluğu.
  static const double _dismissPadding = 24;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Kaydettiğim İşler", showBackButton: false),
      body: Consumer<SavedJobsProvider>(
        builder: (context, provider, child) {
          final savedJobs = provider.savedJobs;

          if (savedJobs.isEmpty) {
            return _emptyState(context);
          }

          return ListView.separated(
            padding: AppPadding.primaryAll,
            itemCount: savedJobs.length,
            separatorBuilder: (context, index) =>
                Divider(color: context.dividerColor, thickness: 1, height: 1),
            itemBuilder: (context, index) =>
                _savedJobTile(context, savedJobs[index], provider),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: _emptyIconSize,
              color: context.dividerColor,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            Text(
              'Henüz kaydedilmiş iş yok',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'İş detaylarında kaydet butonuna basarak\nişleri buraya ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedJobTile(
    BuildContext context,
    Job job,
    SavedJobsProvider provider,
  ) {
    return Dismissible(
      key: ValueKey(job.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        provider.removeJob(job.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${job.title} kaldırıldı'),
            action: SnackBarAction(
              label: 'Geri Al',
              onPressed: () => provider.toggleSave(job),
            ),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: _dismissPadding),
        // Silme zemini ve üstündeki ikon temadan bağımsız.
        color: AppColors.danger,
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.onAccent,
          size: AppSizes.iconNav,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSizes.spaceTiny,
        ),
        onTap: () => JobDetailBottomSheet.show(context, job),
        leading: Container(
          width: AppSizes.avatar,
          height: AppSizes.avatar,
          decoration: BoxDecoration(
            color: job.category.color.withValues(alpha: 0.15),
            borderRadius: AppRadius.innerCircular,
          ),
          child: HugeIcon(
            icon: job.category.icon,
            color: job.category.color,
            size: AppSizes.icon,
          ),
        ),
        title: Text(job.title, style: context.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.company ?? '', style: context.textTheme.bodySmall),
            const SizedBox(height: AppSizes.smallGap),
            Text(
              job.subtitle,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${job.price.asPrice}₺',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.accentColor,
              ),
            ),
            GestureDetector(
              onTap: () => provider.removeJob(job.id),
              child: Icon(
                Icons.bookmark,
                color: context.accentColor,
                size: AppSizes.icon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
