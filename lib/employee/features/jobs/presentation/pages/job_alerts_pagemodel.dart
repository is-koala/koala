part of 'job_alerts_page.dart';

abstract class JobAlertsPagemodel extends State<JobAlertsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<JobAlertsProvider>().load();
    });
  }

  String _criteria(JobAlert alert) {
    final values = <String>[
      if (alert.category != null) alert.category!.name,
      if (alert.cityName != null) alert.cityName!,
      if (alert.districtName != null) alert.districtName!,
      if (alert.minimumSalary != null)
        'En az ${alert.minimumSalary!.asExactPrice} ₺',
      if (alert.type != null) alert.type!.displayName,
    ];
    return values.join(' · ');
  }

  Future<void> _toggle(
    BuildContext context,
    JobAlertsProvider provider,
    JobAlert alert,
  ) async {
    final ok = await provider.update(
      alert.id,
      JobAlertDraft(
        name: alert.name,
        category: alert.category,
        cityName: alert.cityName,
        districtName: alert.districtName,
        minimumSalary: alert.minimumSalary,
        type: alert.type,
        isActive: !alert.isActive,
      ),
    );
    if (!ok && context.mounted) {
      AppToast.error(context, provider.errorMessage ?? 'Alarm güncellenemedi.');
    }
  }

  Future<void> _delete(
    BuildContext context,
    JobAlertsProvider provider,
    JobAlert alert,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Alarmı Sil',
      message: '${alert.name} alarmı silinsin mi?',
      actionLabel: 'Sil',
    );
    if (confirmed != true) return;

    final ok = await provider.delete(alert.id);
    if (!ok && context.mounted) {
      AppToast.error(context, provider.errorMessage ?? 'Alarm silinemedi.');
    }
  }
}
