import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/features/account/presentation/widgets/account_settings_tiles.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_list_tile.dart';
import 'package:koala/product/widgets/theme_mode_sheet.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.onLogout});

  /// Testte çıkışı ağ olmadan sürmek için.
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Ayarlar", isLarge: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [settingsList(context)],
          ),
        ),
      ),
    );
  }

  Column settingsList(BuildContext context) {
    return Column(
      children: [
        // Hesap satırları ortak modülden; kazançlar ve iş alarmları çalışana
        // özgü. Sıra en sık açılandan en seyreğe.
        MyListGroup(
          title: 'Hesap',
          children: [
            AccountSettingsTiles.editAccount(context),
            AccountSettingsTiles.address(context),
            AccountSettingsTiles.changePassword(context),
            AccountSettingsTiles.sessions(context),
          ],
        ),
        MyListGroup(
          title: 'İşlerim',
          children: [
            MyListTile(
              icon: AppIcons.moneyBag,
              title: 'Kazançlarım',
              onTap: () => context.push('/earnings'),
            ),
            MyListTile(
              icon: AppIcons.notification,
              title: 'İş Alarmlarım',
              onTap: () => context.push('/job-alerts'),
            ),
          ],
        ),
        MyListGroup(
          title: 'Tercihler',
          children: [
            AccountSettingsTiles.notificationPreferences(context),
            MyListTile(
              icon: AppIcons.paint,
              title: "Görünüm",
              value: context.watch<ThemeProvider>().themeMode.label,
              onTap: () => ThemeModeSheet.show(context),
            ),
          ],
        ),
        MyListGroup(
          title: 'Gizlilik ve Güvenlik',
          children: [
            AccountSettingsTiles.reports(context),
            AccountSettingsTiles.blockedUsers(context),
          ],
        ),
        MyListGroup(
          children: [
            AccountSettingsTiles.deleteAccount(context),
            MyListTile(
              icon: AppIcons.logout,
              title: "Çıkış Yap",
              onTap: () async {
                // İlk `await`'ten önce: çıkış gecikse de eski bildirimler yeni
                // oturuma taşınmasın.
                context.read<NotificationProvider>().clear();

                final logout = onLogout;
                if (logout != null) {
                  await logout();
                } else {
                  // Bekleyen kayıtlar diskte kalır; yalnız aktif bölüm
                  // işaretçisi temizlenir.
                  await context.read<TimesheetQueueProvider>().pause();
                  // Token silinmeden kapatılıyor ki yeniden bağlanmaya
                  // çalışmasın; sunucu çağrısı düşse de token'lar silinir.
                  await RealtimeClient().disconnect();
                  await AuthService().logout();
                }

                if (context.mounted) {
                  context.read<UserProvider>().clear();
                  context.read<IdentityReviewProvider>().clear();
                  context.read<AvailabilityProvider>().clear();
                  context.read<ApplyProvider>().clear();
                  context.read<SavedJobsProvider>().clear();
                  context.read<JobAlertsProvider>().clear();
                  context.read<ReviewProvider>().clear();
                  context.go('/auth');
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
