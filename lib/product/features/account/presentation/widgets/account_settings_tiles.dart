import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/features/account/account_navigation.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/widgets/my_list_tile.dart';

/// Ayarlar menüsünün hesap satırları.
///
/// Çalışan ve işveren ayarları aynı hesap ekranlarını açıyor; satırların
/// başlığı, ikonu ve gittiği rota tek yerde dursun diye burada. Menüler
/// bunları kendi rol-özel satırlarının (kazançlar, firma bilgileri...)
/// arasına diziyor; sıra menünün kararı, hedef modülün.
class AccountSettingsTiles {
  const AccountSettingsTiles._();

  /// Hesabı Düzenle. Profil yüklenmemişse önce `/users/me` getiriliyor;
  /// ekran `extra` olarak kullanıcıyı istiyor.
  static Widget editAccount(BuildContext context) => MyListTile(
    icon: AppIcons.user,
    title: 'Hesabı Düzenle',
    onTap: () => AccountNavigation.openAccountInfo(context),
  );

  /// Adresim. İşveren ayarlarında ilk kez bir yol: bireysel işverenin
  /// ödemesi bu adres olmadan başlamıyor.
  static Widget address(BuildContext context) => MyListTile(
    icon: AppIcons.location,
    title: 'Adresim',
    onTap: () => AccountNavigation.openAddress(context),
  );

  static Widget changePassword(BuildContext context) => MyListTile(
    icon: AppIcons.shield,
    title: 'Şifreyi Değiştir',
    onTap: () => context.push(AccountRoutes.changePassword),
  );

  static Widget sessions(BuildContext context) => MyListTile(
    icon: AppIcons.mobile,
    title: 'Oturumlar',
    onTap: () => context.push(AccountRoutes.sessions),
  );

  static Widget notificationPreferences(BuildContext context) => MyListTile(
    icon: AppIcons.notification,
    title: 'Bildirim Tercihleri',
    onTap: () => context.push(AccountRoutes.notificationPreferences),
  );

  static Widget reports(BuildContext context) => MyListTile(
    icon: AppIcons.shield,
    title: 'Şikayetlerim',
    onTap: () => context.push(AccountRoutes.reports),
  );

  static Widget blockedUsers(BuildContext context) => MyListTile(
    icon: AppIcons.userBlock,
    title: 'Engellediklerim',
    onTap: () => context.push(AccountRoutes.blockedUsers),
  );

  static Widget deleteAccount(BuildContext context) => MyListTile(
    icon: AppIcons.delete,
    title: 'Hesabı Sil',
    onTap: () => context.push(AccountRoutes.accountDeletion),
  );
}
