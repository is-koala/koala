import 'package:flutter/material.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class SavedJobsPage extends StatefulWidget {
  const SavedJobsPage({super.key});

  @override
  State<SavedJobsPage> createState() => _SavedJobsPageState();
}

class _SavedJobsPageState extends State<SavedJobsPage> {
  /// Kaydırıp silme sırasında açılan kırmızı zeminin sağ boşluğu.
  static const double _dismissPadding = 24;

  @override
  void initState() {
    super.initState();
    // Sayfa `ShellPage`'in `PageView`'ında canlı kaldığı için yükleme tek
    // sefer burada tetikleniyor; provider ikinci kez ağa çıkmıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SavedJobsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Kaydettiğim İşler", showBackButton: false),
      body: Consumer<SavedJobsProvider>(
        builder: (context, provider, child) {
          final savedJobs = provider.savedJobs;

          if (provider.isLoading && savedJobs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Elde kayıt yokken hata varsa "hiç kaydın yok" demek yanıltıcı.
          final error = provider.errorMessage;
          if (error != null && savedJobs.isEmpty) {
            return _errorState(context, error, provider);
          }

          if (savedJobs.isEmpty) {
            return _emptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () => provider.load(force: true),
            child: ListView.separated(
              padding: AppPadding.primaryAll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: savedJobs.length,
              separatorBuilder: (context, index) =>
                  Divider(color: context.dividerColor, thickness: 1, height: 1),
              itemBuilder: (context, index) =>
                  _savedJobTile(context, savedJobs[index], provider),
            ),
          );
        },
      ),
    );
  }

  /// Kayıtlar çekilemediğinde.
  Widget _errorState(
    BuildContext context,
    String message,
    SavedJobsProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(
              onPressed: () => provider.load(force: true),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return const EmptyState(
      icon: AppIcons.bookmark,
      title: 'Henüz kaydedilmiş iş yok',
      description:
          'İş detaylarında kaydet butonuna basarak işleri buraya '
          'ekleyebilirsiniz.',
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
        AppToast.info(
          context,
          '${job.title} kaldırıldı',
          actionLabel: 'Geri Al',
          onAction: () => provider.toggleSave(job),
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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: job.category.color.withValues(alpha: 0.15),
            borderRadius: AppRadius.innerCircular,
          ),
          child: AppIcon(
            job.category.icon,
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
