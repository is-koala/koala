import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/network/session_manager.dart';

/// Hesap listelerinin (oturumlar, engellenenler, şikayetler) alt payı.
///
/// Sayfa iki kabuktan da açılıyor ama kabuklar aynı değil: işveren
/// kabuğunda liste navbar'ın altına giriyor ve son satırın görünmesi için
/// [AppSizes.navBarClearance] gerekiyor; çalışan kabuğunda o pay yalnız
/// boşluk olurdu. Silinen `b_*` ikizleriyle çalışan sayfaları arasındaki tek
/// fark buydu; ortak sayfa farkı role bakarak koruyor. Rol, router'ın da
/// okuduğu [SessionManager.userType]'tan geliyor: senkron ve oturum açıldığı
/// andan itibaren dolu, `UserProvider` gibi ağ isteğine bağlı değil.
class AccountListClearance {
  const AccountListClearance._();

  static double bottomPadding() =>
      SessionManager().userType == SessionManager.businessType
      ? AppSizes.navBarClearance
      : AppSizes.space;
}
