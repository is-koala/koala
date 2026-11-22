import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:provider/provider.dart';

/// Hesap ekranlarına kullanıcıyı yükleyerek gider: ekranlar `extra` olarak
/// [CurrentUser] bekliyor ve profil henüz yüklenmemiş olabilir. Alınamazsa
/// gidilmez, sebep söylenir.
class AccountNavigation {
  const AccountNavigation._();

  static Future<void> openAccountInfo(BuildContext context) =>
      _pushWithUser(context, AccountRoutes.accountInfo);

  /// Adres ekranı; işverenin ödeme ve ilan akışları adres yokken buraya
  /// yönlendiriyor ([AddressRequiredErrorCodes]).
  static Future<void> openAddress(BuildContext context) =>
      _pushWithUser(context, AccountRoutes.address);

  static Future<void> _pushWithUser(BuildContext context, String route) async {
    final user = await loadCurrentUser(context);
    if (user == null || !context.mounted) return;
    await context.push(route, extra: user);
  }

  /// Sağlayıcıdaki kullanıcı, yoksa sunucudan. Alınamazsa hatayı bildirip
  /// `null` döner; çağıran ekranı açmamalı.
  static Future<CurrentUser?> loadCurrentUser(BuildContext context) async {
    final provider = context.read<UserProvider>();
    if (provider.user == null) await provider.load();

    final user = provider.user;
    if (user == null && context.mounted) {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Profil bilgisi alınamadı.',
      );
    }
    return user;
  }
}
