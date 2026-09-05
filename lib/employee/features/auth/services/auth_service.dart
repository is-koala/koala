import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/auth/models/auth_tokens.dart';
import 'package:koala/employee/features/auth/models/consent_decision.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/registration_verification.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/session_manager.dart';

/// Kimlik doğrulama uçlarının tek sarmalayıcısı.
///
/// Token'ların saklanması ve oturum bayraklarının yazılması da burada:
/// sayfalar `SharedPreferences`'a doğrudan yazmak yerine bu servisi çağırıyor.
class AuthService {
  AuthService._(this._apiClient, this._sessionManager, this._userService);

  static final AuthService _instance = AuthService._(
    ApiClient(),
    SessionManager(),
    UserService(),
  );

  factory AuthService() => _instance;

  @visibleForTesting
  factory AuthService.withClient(
    ApiClient apiClient, {
    SessionManager? sessionManager,
    UserService? userService,
  }) {
    return AuthService._(
      apiClient,
      sessionManager ?? SessionManager(),
      userService ?? UserService.withClient(apiClient),
    );
  }

  final ApiClient _apiClient;
  final SessionManager _sessionManager;
  final UserService _userService;

  /// Kayıt akışının ilk adımı: backend doğrulama e-postası gönderiyor.
  ///
  /// Kullanıcı zaten kayıtlıysa uç yine 200 dönüyor (hesabın varlığını
  /// sızdırmamak için), yani başarı yanıtı "mail gitti" garantisi değil.
  Future<void> startRegistration({
    required String firstName,
    required String lastName,
    required String email,
    required bool isEmployer,
  }) {
    return _apiClient.postWithoutData(
      ApiPaths.startRegistration,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        // Backend bu alanı `@JsonProperty("isEmployer")` ile sabitledi ve
        // `@NotNull` yaptı: eksik ya da farklı adla gönderilirse istek
        // doğrulamadan dönüyor.
        'isEmployer': isEmployer,
      },
    );
  }

  /// Kayıt akışının ikinci adımı: e-postadaki bağlantıdan gelen token'ı
  /// şifre belirleme token'ına çevirir.
  Future<RegistrationVerification> verifyRegistrationToken(
    String registrationToken,
  ) {
    return _apiClient.post<RegistrationVerification>(
      ApiPaths.verifyRegistrationToken,
      body: {'registrationToken': registrationToken},
      parse: (data) =>
          RegistrationVerification.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Kayıt akışının son adımı: şifreyi belirler, kullanıcıyı oluşturur ve
  /// oturumu açar.
  ///
  /// [consents] zorunlu: backend yürürlükteki zorunlu sözleşmelerin hepsinin
  /// onaylanmış olmasını istiyor, eksikse kaydı reddediyor.
  Future<void> completeRegistration({
    required String setPasswordToken,
    required String password,
    required bool isEmployer,
    required List<ConsentDecision> consents,
  }) async {
    final tokens = await _apiClient.post<AuthTokens>(
      ApiPaths.completeRegistration,
      body: {
        'setPasswordToken': setPasswordToken,
        'password': password,
        'consents': consents.map((consent) => consent.toJson()).toList(),
      },
      parse: (data) => AuthTokens.fromJson(data! as Map<String, dynamic>),
    );

    await _startSession(tokens, isEmployer: isEmployer);
  }

  /// E-posta ve şifreyle giriş yapar, oturumu açar.
  ///
  /// Giriş yanıtı kullanıcının iş veren olup olmadığını taşımadığı için
  /// hemen ardından `/users/me` çağrılıp tip güncelleniyor. Profil alınamazsa
  /// yarım oturum temizlenir ve giriş başarısız sayılır.
  Future<CurrentUser> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _apiClient.post<AuthTokens>(
      ApiPaths.login,
      body: {'email': email, 'password': password},
      parse: (data) => AuthTokens.fromJson(data! as Map<String, dynamic>),
    );

    try {
      late CurrentUser user;
      await _sessionManager.startWithVerifiedUserType(
        accessToken: tokens.token,
        refreshToken: tokens.refreshToken,
        refreshExpiresAt: tokens.refreshExpiresAt,
        verifyUserType: () async {
          user = await fetchCurrentUser();
          return user.isEmployer;
        },
      );
      return user;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw const ApiException(
        message: 'Hesap bilgilerin doğrulanamadı. Lütfen yeniden giriş yap.',
        type: ApiErrorType.unknown,
      );
    }
  }

  /// Oturumu açmış kullanıcının bilgileri.
  ///
  /// Ucun tek sarmalayıcısı [UserService]; buradaki kısayol giriş akışının
  /// kendi içinde kapalı kalması için duruyor.
  Future<CurrentUser> fetchCurrentUser() => _userService.fetchCurrentUser();

  /// Çıkış yapar.
  ///
  /// Sunucu çağrısı başarısız olsa bile yerel oturum kapatılıyor: kullanıcı
  /// çıkmak istediğinde cihazda token bırakmamak, sunucudaki oturumu
  /// kapatmaktan daha önemli.
  Future<void> logout() async {
    try {
      await _apiClient.postWithoutData(ApiPaths.logout);
    } on ApiException {
      // Yut: yerel temizlik aşağıda yapılıyor.
    } finally {
      await _sessionManager.end();
    }
  }

  /// Şifre sıfırlama e-postası ister.
  ///
  /// Adres kayıtlı değilse de 200 dönüyor.
  Future<void> forgotPassword(String email) {
    return _apiClient.postWithoutData(
      ApiPaths.forgotPassword,
      body: {'email': email},
    );
  }

  /// E-postadaki bağlantıdan gelen token ile yeni şifreyi yazar.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) {
    return _apiClient.postWithoutData(
      ApiPaths.resetPassword,
      body: {'resetToken': resetToken, 'newPassword': newPassword},
    );
  }

  Future<void> _startSession(AuthTokens tokens, {required bool isEmployer}) {
    return _sessionManager.start(
      accessToken: tokens.token,
      refreshToken: tokens.refreshToken,
      refreshExpiresAt: tokens.refreshExpiresAt,
      isEmployer: isEmployer,
    );
  }
}
