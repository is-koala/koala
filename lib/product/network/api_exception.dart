/// Hatanın kaynağı; ne gösterileceğine ve tekrar denenip denenmeyeceğine buna
/// bakılarak karar veriliyor.
///
/// Tip zarftaki `errorCategory`'den türüyor ([fromCategory]); durum kodu yalnız
/// yedek, çünkü bilgi kaybediyor: `401` altında üç, `409` altında iki ayrı
/// kategori var (is-koala/koala#82).
enum ApiErrorType {
  /// İnternet yok ya da sunucuya ulaşılamadı.
  network,

  /// Sunucuya ulaşıldı ama zamanında yanıt gelmedi.
  timeout,

  /// Gönderilen veri kabul edilmedi; alan ayrıntısı [ApiException.fieldErrors].
  validation,

  /// Geçerli oturum yok; kullanıcı yeniden giriş yapmalı. `AuthInterceptor`
  /// token yenilemeye bu tipe bakarak karar veriyor.
  unauthenticated,

  /// Oturum geçerli ama işleme izin yok. [unauthenticated]'dan ayrı, çünkü
  /// yeniden giriş bir şeyi çözmez.
  forbidden,

  notFound,

  /// İstek doğru ama bir iş kuralı izin vermiyor. Sunucu bunu `409` ile
  /// gönderiyor ama `409`'un yedeği [dataConflict]; kategori gelmezse bu tip
  /// üretilemez.
  businessRule,

  /// Ekrandaki veri bayat ya da kayıt zaten var. `409`'un iki kategorisi var;
  /// ayrıntı [_fromStatusCode]'ta.
  dataConflict,

  /// İstemci sürümü desteklenmiyor; tekrar denemek işe yaramaz, güncelleme
  /// gerekli.
  upgradeRequired,

  tooManyRequests,

  server,

  /// Sınıflandırılamayan her şey: `METHOD_NOT_ALLOWED` gibi istemci hataları,
  /// tanınmayan durum kodları, zarfsız yanıtlar.
  unknown;

  /// `errorCategory`'yi tipe çevirir; tanımadığı değerde `null` döner, böylece
  /// sunucunun eklediği yeni kategori uygulamayı düşürmez, durum koduna düşer.
  static ApiErrorType? fromCategory(String? category) {
    return switch (category) {
      'VALIDATION_FAILED' ||
      'REQUEST_MALFORMED' ||
      'PARAMETER_MISSING' => validation,
      'AUTHENTICATION_REQUIRED' ||
      'INVALID_CREDENTIALS' ||
      'TOKEN_EXPIRED' => unauthenticated,
      'ACCESS_DENIED' => forbidden,
      'RESOURCE_NOT_FOUND' || 'ENDPOINT_NOT_FOUND' => notFound,
      'BUSINESS_RULE_VIOLATION' => businessRule,
      'DATA_CONFLICT' => dataConflict,
      'RATE_LIMITED' => tooManyRequests,
      'CLIENT_TOO_OLD' => upgradeRequired,
      'UNEXPECTED' || 'UPSTREAM_FAILED' => server,
      // `MEDIA_TYPE_NOT_SUPPORTED`'ın bugün üreticisi yok ama sunucunun kapalı
      // kümesinde duruyor; multipart uçlardaki `415` boşluğu kapanınca bu
      // kategori gelecek.
      'METHOD_NOT_ALLOWED' || 'MEDIA_TYPE_NOT_SUPPORTED' => unknown,
      _ => null,
    };
  }

  /// Hata tipini belirler: önce zarftaki `errorCategory`, yoksa ya da
  /// tanınmıyorsa durum kodu.
  ///
  /// **Sınıflandırmaya açılan tek kapı bu.** `ApiClient` ve `AuthInterceptor`
  /// ikisi de buradan geçiyor; yedek tablo dışarı açık olsaydı biri kategoriyi
  /// okumadan durum koduna sorabilirdi (is-koala/koala#86).
  static ApiErrorType classify({String? errorCategory, int? statusCode}) {
    return fromCategory(errorCategory) ?? _fromStatusCode(statusCode);
  }

  /// Kategori gelmediğinde (eski sunucu, zarfsız yanıt) çalışan yedek; yalnız
  /// [classify] çağırır.
  ///
  /// `409` iki kategoriden hangisi olduğunu söylemiyor; [dataConflict] bir
  /// seçim. Ayrımı önemseyen çağıran `errorCode`'a bakmalı.
  static ApiErrorType _fromStatusCode(int? statusCode) {
    if (statusCode == null) return unknown;
    if (statusCode == 400 || statusCode == 422) return validation;
    if (statusCode == 401) return unauthenticated;
    if (statusCode == 403) return forbidden;
    if (statusCode == 404) return notFound;
    if (statusCode == 409) return dataConflict;
    if (statusCode == 429) return tooManyRequests;
    if (statusCode == 426) return upgradeRequired;
    if (statusCode >= 500) return server;
    return unknown;
  }

  /// Ekrandaki veri bayat, tazelenmeli. Adı niyeti söylüyor: çağıranlar
  /// [businessRule] ile [dataConflict] arasındaki farkı bilmek zorunda değil.
  /// Ayrım gereken yerde `errorCode` kullanılır.
  bool get serverStateMoved =>
      this == ApiErrorType.businessRule || this == ApiErrorType.dataConflict;
}

/// Bir alana bağlı doğrulama hatası (`details` dizisi).
class ApiFieldError {
  const ApiFieldError({required this.field, required this.message});

  final String field;
  final String message;
}

/// Uygulamanın gördüğü tek hata tipi; `DioException` [ApiClient] içinde
/// kalıyor.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.errorCode,
    this.fieldErrors = const [],
    this.cause,
  });

  /// Kullanıcıya gösterilebilecek Türkçe mesaj; çoğunlukla sunucudan.
  final String message;

  final ApiErrorType type;

  final int? statusCode;

  final String? errorCode;

  final List<ApiFieldError> fieldErrors;

  /// Hatayı doğuran özgün hata. Gösterilmiyor; sade mesaja sarılan beklenmedik
  /// hatanın nedeni kaybolmasın diye taşınıyor.
  final Object? cause;

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
