import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/employee/features/profile/models/user.dart';
import 'package:koala/employee/features/profile/services/fake_user.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/theme/theme_provider.dart';
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
            final user = FakeUser.instance;
            final updatedUser = await context.push<User>(
              '/account-info',
              extra: user,
            );
            if (updatedUser != null) {
              FakeUser.instance.fullName = updatedUser.fullName;
              FakeUser.instance.jobTitle = updatedUser.jobTitle;
              FakeUser.instance.location = updatedUser.location;
              FakeUser.instance.about = updatedUser.about;
              FakeUser.instance.cvFileName = updatedUser.cvFileName;
            }
          },
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
            await AuthService().logout();

            if (context.mounted) {
              context.go('/authgate');
            }
          },
        ),
      ],
    );
  }
}
