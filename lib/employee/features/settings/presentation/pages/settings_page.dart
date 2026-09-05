import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_list_tile.dart';
import 'package:koala/product/widgets/theme_mode_sheet.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
        MyListTile(
          icon: AppIcons.user,
          title: "Hesabı Düzenle",
          onTap: () async {
            // Profil henüz yüklenmediyse düzenleme ekranı boş açılırdı;
            // önce veriyi getirip öyle geçiliyor.
            final provider = context.read<UserProvider>();
            if (provider.user == null) await provider.load();

            final user = provider.user;
            if (user == null) {
              if (context.mounted) {
                AppToast.error(
                  context,
                  provider.errorMessage ?? "Profil bilgisi alınamadı.",
                );
              }
              return;
            }

            if (context.mounted) {
              await context.push('/account-info', extra: user);
            }
          },
        ),
        MyListTile(
          icon: AppIcons.mobile,
          title: "Oturumlar",
          onTap: () => context.push('/sessions'),
        ),
        MyListTile(
          icon: AppIcons.shield,
          title: "Şikayetlerim",
          onTap: () => context.push('/reports'),
        ),
        MyListTile(
          icon: AppIcons.paint,
          title: "Görünüm",
          value: context.watch<ThemeProvider>().themeMode.label,
          onTap: () => ThemeModeSheet.show(context),
        ),
        MyListTile(
          icon: AppIcons.logout,
          title: "Çıkış Yap",
          onTap: () async {
            // Sunucudaki oturumu da kapatıyor; çağrı başarısız olsa bile
            // token'lar cihazdan siliniyor.
            // Canlı bağlantı oturuma bağlı; token silinmeden önce
            // kapatılıyor ki yeniden bağlanmaya çalışmasın.
            await RealtimeClient().disconnect();
            await AuthService().logout();

            if (context.mounted) {
              // Bir sonraki oturum, çıkan kullanıcının verisini görmesin.
              context.read<UserProvider>().clear();
              context.read<ApplyProvider>().clear();
              context.read<SavedJobsProvider>().clear();
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
