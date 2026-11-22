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
import 'package:koala/product/services/push_token_lifecycle.dart';
import 'package:koala/product/services/push_token_service.dart';
import 'package:koala/product/services/push_token_source.dart';

/// Kimlik doğrulama uçları; token'ları ve oturum bayraklarını da burası yazar.
class AuthService {
  AuthService._(
    this._apiClient,
    this._sessionManager,
    this._userService,
    this._pushTokens,
  );

  static final AuthService _instance = AuthService._(
    ApiClient(),
    SessionManager(),
    UserService(),
    PushTokenLifecycle(),
  );

  factory AuthService() => _instance;

  @visibleForTesting
  factory AuthService.withClient(
    ApiClient apiClient, {
    SessionManager? sessionManager,
    UserService? userService,
    PushTokenLifecycle? pushTokens,
  }) {
    final session = sessionManager ?? SessionManager();
    return AuthService._(
      apiClient,
      session,
      userService ?? UserService.withClient(apiClient),
      pushTokens ??
          PushTokenLifecycle.withDependencies(
            service: PushTokenService.withClient(apiClient),
            source: const UnavailablePushTokenSource(),
            session: session,
          ),
    );
  }

  final ApiClient _apiClient;
  final SessionManager _sessionManager;
  final UserService _userService;
  final PushTokenLifecycle _pushTokens;

  /// Kayıtlı kullanıcıda da `200` döner (varlık sızmasın); başarı "mail gitti"
  /// garantisi değil.
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
        // Backend `@NotNull` ve adı sabit; eksik ya da farklı adla istek döner.
        'isEmployer': isEmployer,
      },
    );
  }

  /// E-postadaki token'ı şifre belirleme token'ına çevirir.
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

  /// Şifreyi belirler, kullanıcıyı oluşturur ve oturumu açar. [consents]
  /// zorunlu; eksik onayla backend reddeder.
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
    await _pushTokens.syncQuietly();
  }

  /// Giriş yanıtı kullanıcı tipini taşımadığı için ardından `/users/me` okunur;
  /// alınamazsa yarım oturum temizlenir.
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
      await _pushTokens.syncQuietly();
      return user;
    } catch (error, stackTrace) {
      if (error is ApiException) rethrow;
      debugPrint('Giriş sonrası profil doğrulaması başarısız: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ApiException(
        message: 'Hesap bilgilerin doğrulanamadı. Lütfen yeniden giriş yap.',
        type: ApiErrorType.unknown,
        cause: error,
      );
    }
  }

  /// Giriş akışının kendi içinde kapalı kalsın diye kısayol.
  Future<CurrentUser> fetchCurrentUser() => _userService.fetchCurrentUser();

  /// Sunucu çağrısı düşse de yerel oturum kapanır: cihazda token bırakmamak
  /// daha önemli.
  Future<void> logout() async {
    try {
      await _pushTokens.clearQuietly();
      await _apiClient.postWithoutData(ApiPaths.logout);
    } on ApiException {
      // Yerel temizlik aşağıda yapılıyor.
    } finally {
      await _sessionManager.end();
    }
  }

  /// Kayıtlı olmayan adreste de `200`.
  Future<void> forgotPassword(String email) {
    return _apiClient.postWithoutData(
      ApiPaths.forgotPassword,
      body: {'email': email},
    );
  }

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
