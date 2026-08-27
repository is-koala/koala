/// Backend uç noktalarının yolları.
///
/// Tek yerde durmalarının sebebi, [AuthInterceptor]'ın "bu yol token ister mi"
/// sorusunu string kopyalamadan yanıtlayabilmesi.
class ApiPaths {
  // --------------------------------------------------------------------- Auth

  static const String startRegistration = '/auth/start-registration';
  static const String verifyRegistrationToken =
      '/auth/verify-registration-token';
  static const String completeRegistration = '/auth/complete-registration';
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // -------------------------------------------------------------------- Users

  static const String currentUser = '/users/me';

  // -------------------------------------------------------------------- Legal

  static const String agreements = '/legal/agreements';
  static const String consents = '/legal/consents';
  static const String accountDeletion = '/legal/account-deletion';

  /// Token taşımadan çağrılan uçlar. Bunların dışındaki her isteğe
  /// `Authorization` başlığı ekleniyor.
  ///
  /// [refreshToken] bilerek listede değil: backend oturum kimliğini süresi
  /// dolmuş erişim token'ından okuduğu için o çağrı da başlığı taşımalı.
  static const Set<String> publicPaths = {
    startRegistration,
    verifyRegistrationToken,
    completeRegistration,
    login,
    forgotPassword,
    resetPassword,
    agreements,
  };
}
