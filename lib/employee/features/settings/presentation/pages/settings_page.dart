import 'package:flutter/material.dart';
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

  /// Çıkış sınırını ağ çağrısı olmadan widget testinde sürmek için.
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
        // Hesap satırları ortak modülden: işverenin ayarları da aynı
        // ekranlara gidiyor. Kazançlar ve iş alarmları çalışana özgü.
        AccountSettingsTiles.editAccount(context),
        AccountSettingsTiles.address(context),
        AccountSettingsTiles.changePassword(context),
        AccountSettingsTiles.sessions(context),
        AccountSettingsTiles.notificationPreferences(context),
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
        AccountSettingsTiles.reports(context),
        AccountSettingsTiles.blockedUsers(context),
        MyListTile(
          icon: AppIcons.paint,
          title: "Görünüm",
          value: context.watch<ThemeProvider>().themeMode.label,
          onTap: () => ThemeModeSheet.show(context),
        ),
        AccountSettingsTiles.deleteAccount(context),
        MyListTile(
          icon: AppIcons.logout,
          title: "Çıkış Yap",
          onTap: () async {
            // İlk await'ten önce: eski hesabın bildirimi, çıkan istek
            // gecikse veya hata verse bile yeni oturuma taşınmamalı.
            context.read<NotificationProvider>().clear();

            final logout = onLogout;
            if (logout != null) {
              await logout();
            } else {
              // Bekleyen kayıtlar kullanıcı bölümünde kalır; yalnız bu
              // oturuma ait aktif bölüm işaretçisi temizlenir.
              await context.read<TimesheetQueueProvider>().pause();
              // Sunucudaki oturumu da kapatıyor; çağrı başarısız olsa bile
              // token'lar cihazdan siliniyor.
              // Canlı bağlantı oturuma bağlı; token silinmeden önce
              // kapatılıyor ki yeniden bağlanmaya çalışmasın.
              await RealtimeClient().disconnect();
              await AuthService().logout();
            }

            if (context.mounted) {
              // Bir sonraki oturum, çıkan kullanıcının verisini görmesin.
              context.read<UserProvider>().clear();
              context.read<IdentityReviewProvider>().clear();
              context.read<AvailabilityProvider>().clear();
              context.read<ApplyProvider>().clear();
              context.read<SavedJobsProvider>().clear();
              context.read<JobAlertsProvider>().clear();
              // Değerlendirme kaydı cihazda duruyor; yeni kullanıcı önceki
              // kullanıcının işaretlerini görmemeli.
              context.read<ReviewProvider>().clear();
              context.go('/auth');
            }
          },
        ),
      ],
    );
  }
}
