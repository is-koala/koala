import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oturumun açılıp kapanmasını tek yerden yönetir.
///
/// İki ayrı yere yazıyor: token'lar [TokenStorage]'a (Keychain/Keystore),
/// router'ın okuduğu `is_logged_in` / `user_type` bayrakları
/// `SharedPreferences`'a. İkisinin birlikte hareket etmesi önemli — yalnızca
/// bayrağı yazan bir akış, token'ı olmayan "giriş yapmış" bir kullanıcı
/// üretir.
class SessionManager {
  SessionManager._internal();

  static final SessionManager _instance = SessionManager._internal();

  factory SessionManager() => _instance;

  /// Router'ın okuduğu oturum bayrağı.
  static const String isLoggedInKey = 'is_logged_in';

  /// Hangi uygulamanın (çalışan/iş veren) gösterileceğini belirleyen anahtar.
  static const String userTypeKey = 'user_type';

  /// [userTypeKey] için çalışan değeri.
  static const String employeeType = 'employee';

  /// [userTypeKey] için iş veren değeri.
  static const String businessType = 'business';

  final TokenStorage _tokenStorage = TokenStorage();

  /// Giriş ya da kayıt sonrası oturumu açar.
  Future<void> start({
    required String accessToken,
    required String refreshToken,
    DateTime? refreshExpiresAt,
    required bool isEmployer,
  }) async {
    await _tokenStorage.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
      refreshExpiresAt: refreshExpiresAt,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isLoggedInKey, true);
    await prefs.setString(
      userTypeKey,
      isEmployer ? businessType : employeeType,
    );
  }

  /// Kullanıcı tipini tek başına günceller.
  ///
  /// Giriş yanıtı bu bilgiyi taşımadığı için `/users/me` çağrısı döndükten
  /// sonra çağrılıyor.
  Future<void> updateUserType({required bool isEmployer}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      userTypeKey,
      isEmployer ? businessType : employeeType,
    );
  }

  /// Oturumu kapatır: token'lar silinir, bayraklar temizlenir.
  ///
  /// Yönlendirme yapmaz — router zaten her gezinmede bayrağı okuyup
  /// `/authgate`'e atıyor.
  Future<void> end() async {
    await _tokenStorage.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(isLoggedInKey);
    await prefs.remove(userTypeKey);
  }
}
