import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/features/account/presentation/widgets/account_settings_tiles.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_list_tile.dart';
import 'package:koala/product/widgets/theme_mode_sheet.dart';
import 'package:provider/provider.dart';

class BSettingsPage extends StatelessWidget {
  const BSettingsPage({super.key, this.onLogout});

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
            children: [_settingsList(context)],
          ),
        ),
      ),
    );
  }

  Widget _settingsList(BuildContext context) {
    return Column(
      children: [
        // Hesap satırları ortak modülden; firma, şablon ve havuz işverene özgü.
        // "Adresim" bireysel işverenin ödemesi için gerekli.
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
          title: 'İşletme',
          children: [
            MyListTile(
              icon: AppIcons.building,
              title: "Firma Bilgileri Düzenle",
              onTap: () {
                context.push('/business/company-info');
              },
            ),
            MyListTile(
              icon: AppIcons.fileText,
              title: "İlan Şablonlarım",
              onTap: () => context.push('/business/job-templates'),
            ),
            MyListTile(
              icon: AppIcons.bookmark,
              title: "Yetenek Havuzum",
              onTap: () => context.push('/business/talent-pool'),
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
                  await context.read<TimesheetQueueProvider>().pause();
                  // Token silinmeden kapatılıyor ki yeniden bağlanmaya
                  // çalışmasın.
                  await RealtimeClient().disconnect();

                  // Çağrı başarısız olsa da token'lar silinir.
                  await AuthService().logout();
                }

                if (!context.mounted) return;

                // Provider'lar uygulama boyunca yaşıyor; temizlenmezse sonraki
                // oturum öncekinin verisini görür.
                context.read<UserProvider>().clear();
                context.read<IdentityReviewProvider>().clear();
                context.read<AvailabilityProvider>().clear();
                context.read<BJobsProvider>().clear();
                context.read<BCompanyProvider>().clear();
                context.read<BJobTemplatesProvider>().clear();
                context.read<BTalentPoolProvider>().clear();
                context.read<ReviewProvider>().clear();

                context.go('/auth');
              },
            ),
          ],
        ),
      ],
    );
  }
}
