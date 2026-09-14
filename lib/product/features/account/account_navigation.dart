import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:provider/provider.dart';

/// Hesap ekranlarına kullanıcıyı yükleyerek gitmenin tek yolu.
///
/// Hesap bilgileri ve adres ekranı `extra` olarak [CurrentUser] bekliyor.
/// Profil henüz yüklenmemişken (ayarlar menüsü profilden önce açılabiliyor,
/// işveren tarafında profil şirketi gösteriyor) ekran boş açılırdı; önce
/// `/users/me` getiriliyor, alınamazsa gidilmiyor ve sebep söyleniyor.
class AccountNavigation {
  const AccountNavigation._();

  /// Hesap bilgileri ekranını açar; kapanınca döner.
  static Future<void> openAccountInfo(BuildContext context) =>
      _pushWithUser(context, AccountRoutes.accountInfo);

  /// Kullanıcının adres ekranını açar; kapanınca döner.
  ///
  /// İşverenin ödeme ve ilan akışları adres yokken buraya yönlendiriyor
  /// ([AddressRequiredErrorCodes]); çalışan tarafında başvuru kapısı aynı
  /// rotaya kendi `extra`'sıyla gidiyor.
  static Future<void> openAddress(BuildContext context) =>
      _pushWithUser(context, AccountRoutes.address);

  static Future<void> _pushWithUser(BuildContext context, String route) async {
    final user = await loadCurrentUser(context);
    if (user == null || !context.mounted) return;
    await context.push(route, extra: user);
  }

  /// Sağlayıcıdaki kullanıcıyı, yoksa sunucudan getirerek döner.
  ///
  /// Alınamazsa hatayı bildirip `null` döner; çağıran ekranı açmamalı.
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
