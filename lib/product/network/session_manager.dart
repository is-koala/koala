import 'package:flutter/foundation.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oturumun tek sahibi: durumu hem yazar hem okur.
///
/// İki ayrı yere yazıyor: token'lar [TokenStorage]'a (Keychain/Keystore),
/// router'ın okuduğu `is_logged_in` / `user_type` bayrakları
/// `SharedPreferences`'a. İkisinin birlikte hareket etmesi önemli — yalnızca
/// bayrağı yazan bir akış, token'ı olmayan "giriş yapmış" bir kullanıcı
/// üretir.
///
/// Bayraklar [load] ile bir kez belleğe alınıyor ve oradan **senkron**
/// okunuyor. Router'ın yönlendirme kararı senkron olmak zorunda: `await`
/// eden bir `redirect`, go_router'ın sayfayı kareden sonra yerleştirmesine
/// ve her gezinmede diske gidilmesine yol açıyor.
///
/// [ChangeNotifier] olması router içindir: [load] ve [end] `refreshListenable`
/// üzerinden yönlendirmeyi yeniden tetikliyor. [start] ve [updateUserType]
/// **bilerek** haber vermiyor: giriş ve kayıt akışlarının hepsi zaten kendi
/// `context.go`'sunu yapıyor, muhafızı ortadan tetiklemek kullanıcıyı akışın
/// sonunu görmeden ana sayfaya fırlatıyor (kayıt sonrası şirket bilgileri
/// adımı böyle atlanıyordu). Bayrakların tazeliği bundan etkilenmiyor:
/// getter'lar paylaşılan örnekten canlı okuyor, `refreshListenable` yalnızca
/// muhafızın **ne zaman** çalışacağını belirliyor.
class SessionManager extends ChangeNotifier {
  SessionManager._internal() : _tokenStorage = TokenStorage();

  /// Farklı API oturumlarını gerçek saklama davranışıyla sınamak için.
  @visibleForTesting
  SessionManager.withTokenStorage(TokenStorage tokenStorage)
    : _tokenStorage = tokenStorage;

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

  /// Onboarding'in bir kez gösterildiğini işaretleyen anahtar.
  static const String seenOnboardingKey = 'seen_onboarding';

  final TokenStorage _tokenStorage;

  SharedPreferences? _prefs;

  String _key(String name) =>
      '${Uri.encodeComponent(_tokenStorage.apiOrigin)}:$name';

  /// Oturum durumu diskten okundu mu. Okunmadan hiçbir yönlendirme kararı
  /// verilemez: okunmamış durum "giriş yapmamış"tan farklı bir şey.
  bool get isInitialized => _prefs != null;

  /// Kullanıcının oturumu açık mı.
  bool get isLoggedIn => _prefs?.getBool(_key(isLoggedInKey)) ?? false;

  /// Hangi uygulamanın gösterileceği: [employeeType] ya da [businessType].
  String? get userType => _prefs?.getString(_key(userTypeKey));

  /// Onboarding daha önce gösterildi mi.
  bool get seenOnboarding => _prefs?.getBool(seenOnboardingKey) ?? false;

  /// Oturum durumunu diskten okuyup belleğe alır.
  ///
  /// Splash ekranı çağırıyor; bitince dinleyiciler haberdar ediliyor ve
  /// router kullanıcıyı gideceği yere yolluyor.
  ///
  /// `getInstance()` tek bir örnek döndürüp değerleri bellekte tuttuğu için
  /// -- yazan bütün akışlar da aynı örnekten geçiyor -- burada tutulan örnek
  /// bayatlamıyor.
  Future<void> load() async {
    final prefs = await _cached();
    if (isLoggedIn && await _tokenStorage.readAccessToken() == null) {
      await prefs.remove(_key(isLoggedInKey));
      await prefs.remove(_key(userTypeKey));
    }
    notifyListeners();
  }

  /// Onboarding'i görülmüş olarak işaretler.
  Future<void> markOnboardingSeen() async {
    final prefs = await _cached();
    await prefs.setBool(seenOnboardingKey, true);
    notifyListeners();
  }

  /// Örneği alır ve belleğe yazar.
  ///
  /// Yazan yollar da buradan geçiyor: [load] hiç çağrılmamışken açılan bir
  /// oturum, aksi hâlde "durum okunmadı" olarak kalır ve muhafız kullanıcıyı
  /// giriş yapmamış sayardı.
  Future<SharedPreferences> _cached() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @visibleForTesting
  void resetForTest() => _prefs = null;

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

    final prefs = await _cached();
    await prefs.setBool(_key(isLoggedInKey), true);
    await prefs.setString(
      _key(userTypeKey),
      isEmployer ? businessType : employeeType,
    );
  }

  /// Kullanıcı tipini tek başına günceller.
  ///
  /// Giriş yanıtı bu bilgiyi taşımadığı için `/users/me` çağrısı döndükten
  /// sonra çağrılıyor.
  Future<void> updateUserType({required bool isEmployer}) async {
    final prefs = await _cached();
    await prefs.setString(
      _key(userTypeKey),
      isEmployer ? businessType : employeeType,
    );
  }

  /// Oturumu kapatır: token'lar silinir, bayraklar temizlenir.
  ///
  /// Yönlendirme yapmaz — dinleyiciler haberdar ediliyor ve router muhafızı
  /// kullanıcıyı `/auth`'a atıyor. Onboarding bayrağı korunuyor: kullanıcı
  /// çıkış yaptı diye tanıtımı yeniden izlememeli.
  Future<void> end() async {
    await _tokenStorage.clear();

    final prefs = await _cached();
    await prefs.remove(_key(isLoggedInKey));
    await prefs.remove(_key(userTypeKey));
    notifyListeners();
  }
}
