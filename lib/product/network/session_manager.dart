import 'package:flutter/foundation.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oturumun tek sahibi. Token'lar [TokenStorage]'a, router'ın okuduğu bayraklar
/// `SharedPreferences`'a; ikisi birlikte yazılmalı, yoksa token'sız "giriş
/// yapmış" kullanıcı çıkar.
///
/// Bayraklar [load] ile belleğe alınıp **senkron** okunuyor, çünkü router'ın
/// `redirect`'i senkron olmalı. [load] ve [end] router'ı tetikliyor; [start] ve
/// [updateUserType] **bilerek** tetiklemiyor: akışlar kendi `context.go`'sunu
/// yapıyor, muhafız ortada çalışırsa kullanıcı akışın sonunu görmeden ana
/// sayfaya atılır.
class SessionManager extends ChangeNotifier {
  SessionManager._internal() : _tokenStorage = TokenStorage();

  @visibleForTesting
  SessionManager.withTokenStorage(TokenStorage tokenStorage)
    : _tokenStorage = tokenStorage;

  static final SessionManager _instance = SessionManager._internal();

  factory SessionManager() => _instance;

  static const String isLoggedInKey = 'is_logged_in';

  static const String userTypeKey = 'user_type';

  static const String employeeType = 'employee';

  static const String businessType = 'business';

  static const String seenOnboardingKey = 'seen_onboarding';

  final TokenStorage _tokenStorage;

  SharedPreferences? _prefs;

  String _key(String name) =>
      '${Uri.encodeComponent(_tokenStorage.apiOrigin)}:$name';

  /// Durum diskten okundu mu. Okunmamış durum "giriş yapmamış"tan farklı.
  bool get isInitialized => _prefs != null;

  bool get isLoggedIn => _prefs?.getBool(_key(isLoggedInKey)) ?? false;

  /// [employeeType] ya da [businessType].
  String? get userType => _prefs?.getString(_key(userTypeKey));

  bool get seenOnboarding => _prefs?.getBool(seenOnboardingKey) ?? false;

  /// Oturum durumunu diskten okuyup belleğe alır; splash çağırıyor, bitince
  /// router yönlendiriyor.
  Future<void> load() async {
    final prefs = await _cached();
    if (isLoggedIn && await _tokenStorage.readAccessToken() == null) {
      await prefs.remove(_key(isLoggedInKey));
      await prefs.remove(_key(userTypeKey));
    }
    notifyListeners();
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await _cached();
    await prefs.setBool(seenOnboardingKey, true);
    notifyListeners();
  }

  /// Örneği alır ve belleğe yazar. Yazan yollar da buradan geçiyor ki [load]
  /// çağrılmadan açılan oturum "okunmadı" kalmasın.
  Future<SharedPreferences> _cached() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @visibleForTesting
  void resetForTest() => _prefs = null;

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

  /// Token'ları profil isteğine hazırlar; rol doğrulanana kadar oturumu açmaz,
  /// başarısızlıkta yarım oturumu temizler.
  Future<void> startWithVerifiedUserType({
    required String accessToken,
    required String refreshToken,
    DateTime? refreshExpiresAt,
    required Future<bool> Function() verifyUserType,
  }) async {
    final prefs = await _cached();
    try {
      await prefs.remove(_key(isLoggedInKey));
      await prefs.remove(_key(userTypeKey));
      await _tokenStorage.save(
        accessToken: accessToken,
        refreshToken: refreshToken,
        refreshExpiresAt: refreshExpiresAt,
      );
      final isEmployer = await verifyUserType();
      await updateUserType(isEmployer: isEmployer);
      await prefs.setBool(_key(isLoggedInKey), true);
    } catch (_) {
      // Temizlik de başarısız olabilir (imzasız iOS build'inde `-34018`);
      // yutuluyor ki `rethrow` asıl hatayı yükseltsin.
      try {
        await end();
      } catch (_) {}
      rethrow;
    }
  }

  /// Giriş yanıtı kullanıcı tipini taşımadığı için `/users/me`'den sonra
  /// çağrılıyor.
  Future<void> updateUserType({required bool isEmployer}) async {
    final prefs = await _cached();
    await prefs.setString(
      _key(userTypeKey),
      isEmployer ? businessType : employeeType,
    );
  }

  /// Oturumu kapatır; yönlendirmeyi router muhafızı yapar. Onboarding bayrağı
  /// korunuyor.
  Future<void> end() async {
    await _tokenStorage.clear();

    final prefs = await _cached();
    await prefs.remove(_key(isLoggedInKey));
    await prefs.remove(_key(userTypeKey));
    notifyListeners();
  }
}
