/// Hatanın kaynağını sınıflandırır; kullanıcıya ne gösterileceğine ve
/// isteğin tekrar denenip denenmeyeceğine buna bakarak karar veriliyor.
enum ApiErrorType {
  /// İnternet yok ya da sunucuya hiç ulaşılamadı.
  network,

  /// Sunucuya ulaşıldı ama zamanında yanıt gelmedi.
  timeout,

  /// 400 / 422 — gönderilen veri kabul edilmedi. [ApiException.fieldErrors]
  /// doluysa hangi alanın hatalı olduğu oradadır.
  validation,

  /// 401 / 403 — oturum yok, süresi dolmuş ya da yetki yetersiz.
  unauthorized,

  /// 404 — kayıt bulunamadı.
  notFound,

  /// 409 — çakışma (ör. e-posta zaten kayıtlı).
  conflict,

  /// 426 — istemci sürümü sunucunun istediği en düşük sürümün altında.
  /// Tekrar denemenin faydası yok; kullanıcının uygulamayı güncellemesi
  /// gerekiyor.
  upgradeRequired,

  /// 429 — istek sınırı aşıldı (backend'de `RateLimitFilter` var).
  tooManyRequests,

  /// 5xx — sunucu tarafında hata.
  server,

  /// Sınıflandırılamayan her şey.
  unknown,
}

/// Bir alana bağlı doğrulama hatası. Backend `details` dizisinde döndürüyor.
class ApiFieldError {
  const ApiFieldError({required this.field, required this.message});

  final String field;
  final String message;

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

/// Uygulamanın gördüğü tek hata tipi.
///
/// `DioException` katmanı [ApiClient] içinde kapatılıyor; servisler ve
/// sayfalar yalnızca bunu yakalar.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.errorCode,
    this.fieldErrors = const [],
    this.cause,
  });

  /// Kullanıcıya gösterilebilecek mesaj. Backend `Accept-Language: tr` ile
  /// zaten Türkçe döndürdüğü için çoğu durumda sunucudan geliyor.
  final String message;

  final ApiErrorType type;

  final int? statusCode;

  /// Backend'in makine tarafından okunabilir hata kodu (`errorCode` alanı).
  final String? errorCode;

  final List<ApiFieldError> fieldErrors;

  /// Bu hatayı doğuran özgün hata.
  ///
  /// Kullanıcıya gösterilmiyor; beklenmeyen bir hata sade bir mesaja
  /// sarıldığında nedeni kaybolmasın diye taşınıyor. Cihazda çıkan hatayı
  /// teşhis edebilmenin tek yolu bu.
  final Object? cause;

  /// Verilen alan için doğrulama mesajı; yoksa `null`.
  String? messageForField(String field) {
    for (final error in fieldErrors) {
      if (error.field == field) return error.message;
    }
    return null;
  }

  @override
  String toString() => cause == null
      ? 'ApiException($type, $statusCode): $message'
      : 'ApiException($type, $statusCode): $message (cause: $cause)';
}
