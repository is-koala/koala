/// `/auth/login` ve `/auth/complete-registration` yanıtındaki token çifti.
class AuthTokens {
  const AuthTokens({
    required this.token,
    required this.refreshToken,
    this.refreshExpiresAt,
  });

  /// Erişim token'ı. Backend'de 12 saat geçerli.
  final String token;

  /// Yenileme token'ı. Backend'de 30 gün geçerli, kayan pencereyle uzuyor.
  final String refreshToken;

  /// Yenileme token'ının son kullanma anı.
  final DateTime? refreshExpiresAt;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['refreshExpiresAt'] as String?;

    return AuthTokens(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      refreshExpiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refreshToken': refreshToken,
      'refreshExpiresAt': refreshExpiresAt?.toIso8601String(),
    };
  }
}
