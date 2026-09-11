import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_list_tile.dart';
import 'package:koala/product/widgets/theme_mode_sheet.dart';
import 'package:provider/provider.dart';

class BSettingsPage extends StatelessWidget {
  const BSettingsPage({super.key, this.onLogout});

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
            children: [_settingsList(context)],
          ),
        ),
      ),
    );
  }

  Widget _settingsList(BuildContext context) {
    return Column(
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
        MyListTile(
          icon: AppIcons.shield,
          title: "Şifreyi Değiştir",
          onTap: () => context.push('/change-password'),
        ),
        MyListTile(
          icon: AppIcons.mobile,
          title: "Oturumlar",
          onTap: () => context.push('/business/sessions'),
        ),
        MyListTile(
          icon: AppIcons.shield,
          title: "Şikayetlerim",
          onTap: () => context.push('/business/reports'),
        ),
        MyListTile(
          icon: AppIcons.userBlock,
          title: "Engellediklerim",
          onTap: () => context.push('/business/blocked-users'),
        ),
        MyListTile(
          icon: AppIcons.paint,
          title: "Görünüm",
          value: context.watch<ThemeProvider>().themeMode.label,
          onTap: () => ThemeModeSheet.show(context),
        ),
        MyListTile(
          icon: AppIcons.delete,
          title: "Hesabı Sil",
          onTap: () => context.push('/business/account-deletion'),
        ),
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
              await context.read<TimesheetQueueProvider>().pause();
              // Canlı bağlantı oturuma bağlı; token silinmeden önce
              // kapatılıyor ki yeniden bağlanmaya çalışmasın. İşveren tarafı da
              // aynı `RealtimeClient` örneğini kullanıyor.
              await RealtimeClient().disconnect();

              // Sunucudaki oturumu da kapatıyor; çağrı başarısız olsa bile
              // token'lar cihazdan siliniyor.
              await AuthService().logout();
            }

            if (!context.mounted) return;

            // Provider'lar uygulama boyunca yaşıyor: temizlenmezse bir
            // sonraki oturum öncekinin ilanlarını ve profilini görürdü.
            context.read<UserProvider>().clear();
            context.read<AvailabilityProvider>().clear();
            context.read<BJobsProvider>().clear();
            context.read<BCompanyProvider>().clear();
            context.read<BJobTemplatesProvider>().clear();
            context.read<BTalentPoolProvider>().clear();

            context.go('/auth');
          },
        ),
      ],
    );
  }
}
