import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/network/session_manager.dart';

/// Hesap listelerinin alt payı: işveren kabuğunda liste navbar'ın altına
/// giriyor, çalışanınkinde girmiyor. Rol senkron [SessionManager.userType]'tan
/// okunuyor.
class AccountListClearance {
  const AccountListClearance._();

  static double bottomPadding() =>
      SessionManager().userType == SessionManager.businessType
      ? AppSizes.navBarClearance
      : AppSizes.space;
}
