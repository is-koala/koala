import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/product/features/account/presentation/pages/account_deletion_page.dart';
import 'package:koala/product/features/account/presentation/pages/account_info_page.dart';
import 'package:koala/product/features/account/presentation/pages/address_page.dart';
import 'package:koala/product/features/account/presentation/pages/blocked_users_page.dart';
import 'package:koala/product/features/account/presentation/pages/change_password_page.dart';
import 'package:koala/product/features/account/presentation/pages/notification_preferences_page.dart';
import 'package:koala/product/features/account/presentation/pages/reports_page.dart';
import 'package:koala/product/features/account/presentation/pages/sessions_page.dart';
import 'package:koala/product/features/account/presentation/pages/verification_code_page.dart';

/// Hesap modülünün rotaları.
///
/// Hesap kullanıcıya ait, tarafına değil: çalışan da işveren de aynı
/// ekranları açıyor. Yollar bu yüzden `/business/` öneki taşımıyor — önek
/// yönlendirme kapısında çalışanı geri çevirir, öneksiz yol iki tarafa da
/// açık (`RouterManager.resolveRedirect`). Eski `/business/sessions`,
/// `/business/blocked-users`, `/business/account-deletion` ve
/// `/business/reports` kopyaları kaldırıldı; iki ayarlar menüsü de buradaki
/// sabitlere gidiyor.
class AccountRoutes {
  const AccountRoutes._();

  /// Hesap bilgileri. `extra`: [CurrentUser].
  static const String accountInfo = '/account-info';

  /// Kullanıcının kendi adresi, harita-öncelikli ekranda. `extra` olarak
  /// [CurrentUser] verilebilir; verilmezse ekran `UserProvider`'daki
  /// kullanıcıya açılır.
  static const String address = '/address';

  static const String changePassword = '/change-password';

  static const String sessions = '/sessions';

  static const String notificationPreferences = '/notification-preferences';

  static const String reports = '/reports';

  static const String blockedUsers = '/blocked-users';

  static const String accountDeletion = '/account-deletion';

  /// E-posta/telefon değişikliğinin kod ekranı. `extra`:
  /// [PendingVerification]; `bool` sonucuyla kapanır.
  static const String verification = '/verification';

  /// Modülün `GoRoute` listesi.
  ///
  /// [page], shell dışındaki sayfaların `Page`'ini üreten fonksiyon
  /// (`RouterManager._page`): her rota kendi `pageBuilder`'ını vermek zorunda,
  /// yoksa go_router sayfayı animasyonsuz açıyor.
  static List<GoRoute> routes(
    Page<void> Function(GoRouterState state, Widget child) page,
  ) {
    return [
      GoRoute(
        path: accountInfo,
        pageBuilder: (context, state) {
          final user = state.extra as CurrentUser;
          return page(state, AccountInfoPage(user: user));
        },
      ),
      GoRoute(
        path: address,
        pageBuilder: (context, state) {
          final extra = state.extra;
          return page(
            state,
            AddressPage(user: extra is CurrentUser ? extra : null),
          );
        },
      ),
      GoRoute(
        path: changePassword,
        pageBuilder: (context, state) =>
            page(state, const ChangePasswordPage()),
      ),
      GoRoute(
        path: sessions,
        pageBuilder: (context, state) => page(state, const SessionsPage()),
      ),
      GoRoute(
        path: notificationPreferences,
        pageBuilder: (context, state) =>
            page(state, const NotificationPreferencesPage()),
      ),
      GoRoute(
        path: reports,
        pageBuilder: (context, state) => page(state, const ReportsPage()),
      ),
      GoRoute(
        path: blockedUsers,
        pageBuilder: (context, state) => page(state, const BlockedUsersPage()),
      ),
      GoRoute(
        path: accountDeletion,
        pageBuilder: (context, state) =>
            page(state, const AccountDeletionPage()),
      ),
      // Hesap ekranından açılıyor: e-posta ya da telefon değiştiğinde sunucu
      // değeri yazmıyor, önce buradaki kodun girilmesini bekliyor. Sonucu
      // `bool` olarak döndürüyor; çağıran sıradaki doğrulamaya geçip
      // geçmeyeceğine buna bakarak karar veriyor.
      GoRoute(
        path: verification,
        pageBuilder: (context, state) {
          final verification = state.extra as PendingVerification;
          return page(state, VerificationCodePage(verification: verification));
        },
      ),
    ];
  }
}
