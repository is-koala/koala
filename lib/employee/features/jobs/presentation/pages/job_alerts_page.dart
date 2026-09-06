import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'job_alerts_pagemodel.dart';

class JobAlertsPage extends StatefulWidget {
  const JobAlertsPage({super.key});

  @override
  State<JobAlertsPage> createState() => _JobAlertsPageState();
}

class _JobAlertsPageState extends JobAlertsPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppbar(title: 'İş Alarmlarım'),
      body: Consumer<JobAlertsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.alerts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null && provider.alerts.isEmpty) {
            return _errorState(context, provider);
          }
          if (provider.alerts.isEmpty) {
            return const EmptyState(
              icon: AppIcons.notification,
              title: 'Henüz iş alarmınız yok',
              description:
                  'Aradığınız işe uygun ölçütleri kaydedip yeni ilanları '
                  'takip edebilirsiniz.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.load(force: true),
            child: ListView.separated(
              padding: AppPadding.primaryAll,
              itemCount: provider.alerts.length + 1,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSizes.spaceSmall),
              itemBuilder: (context, index) {
                if (index == provider.alerts.length) {
                  return _limitMessage(context, provider);
                }
                return _alertCard(context, provider, provider.alerts[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: Consumer<JobAlertsProvider>(
        builder: (context, provider, child) => FloatingActionButton.extended(
          onPressed: provider.canCreate
              ? () => context.push('/job-alerts/form')
              : null,
          icon: const AppIcon(AppIcons.plus),
          label: const Text('Yeni Alarm'),
        ),
      ),
    );
  }

  Widget _errorState(BuildContext context, JobAlertsProvider provider) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
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

  Widget _alertCard(
    BuildContext context,
    JobAlertsProvider provider,
    JobAlert alert,
  ) {
    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: Padding(
        padding: AppPadding.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(alert.name, style: context.textTheme.titleSmall),
                ),
                Switch(
                  value: alert.isActive,
                  onChanged: (_) => _toggle(context, provider, alert),
                ),
              ],
            ),
            Text(
              _criteria(alert),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      context.push('/job-alerts/form', extra: alert),
                  icon: const AppIcon(AppIcons.edit, size: AppSizes.iconSmall),
                  label: const Text('Düzenle'),
                ),
                TextButton.icon(
                  onPressed: () => _delete(context, provider, alert),
                  icon: const AppIcon(
                    AppIcons.delete,
                    size: AppSizes.iconSmall,
                  ),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _limitMessage(BuildContext context, JobAlertsProvider provider) {
    if (provider.canCreate) return const SizedBox.shrink();
    return Padding(
      padding: AppPadding.card,
      child: Text(
        '10 alarm sınırına ulaştınız. Yeni alarm için önce birini silin.',
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.textSecondary,
        ),
      ),
    );
  }
}
