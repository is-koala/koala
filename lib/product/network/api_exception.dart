/// Hatanın kaynağını sınıflandırır; kullanıcıya ne gösterileceğine ve
/// isteğin tekrar denenip denenmeyeceğine buna bakarak karar veriliyor.
///
/// Tip, backend'in hata zarfındaki `errorCategory` alanından türetiliyor
/// ([fromCategory]); HTTP durum kodu yalnızca alan gelmediğinde ya da
/// tanınmadığında devreye giren yedek. Sebep: durum kodu bilgi kaybediyordu —
/// sunucunun ayırdığı dört kimlik hatası tek `401`/`403` çiftine, iki farklı
/// çakışma tek `409`'a sıkışıyordu (is-koala/koala#82).
enum ApiErrorType {
  /// İnternet yok ya da sunucuya hiç ulaşılamadı.
  ///
  /// HTTP'ye hiç varılamamış hâl: kategorisi olamaz, yalnızca `DioException`
  /// üretir.
  network,

  /// Sunucuya ulaşıldı ama zamanında yanıt gelmedi.
  ///
  /// Bu da HTTP yanıtı olmayan bir hâl; kategoriden gelmiyor.
  timeout,

  /// Gönderilen veri kabul edilmedi. [ApiException.fieldErrors] doluysa hangi
  /// alanın hatalı olduğu oradadır.
  ///
  /// Kategoriler: `VALIDATION_FAILED`, `REQUEST_MALFORMED`,
  /// `PARAMETER_MISSING`. Yedek: `400` / `422`.
  validation,

  /// Geçerli bir oturum yok: hiç giriş yapılmamış, token süresi dolmuş ya da
  /// token geçersiz. Kullanıcının **yeniden kimlik doğrulaması** gerekiyor.
  ///
  /// Kategoriler: `AUTHENTICATION_REQUIRED`, `INVALID_CREDENTIALS`,
  /// `TOKEN_EXPIRED`. Yedek: `401`.
  ///
  /// `AuthInterceptor` yalnızca bu ailenin durum kodunda (`401`) token
  /// yenilemeye çalışıyor ve başaramazsa oturumu kapatıyor.
  unauthenticated,

  /// Oturum geçerli ama bu işleme izin yok.
  ///
  /// Kategori: `ACCESS_DENIED`. Yedek: `403`.
  ///
  /// [unauthenticated]'dan ayrı tutulmasının sebebi bu: kullanıcı giriş
  /// ekranına gönderilmemeli, yeniden giriş yapmak hiçbir şeyi çözmez.
  forbidden,

  /// Kayıt bulunamadı.
  ///
  /// Kategoriler: `RESOURCE_NOT_FOUND`, `ENDPOINT_NOT_FOUND`. Yedek: `404`.
  notFound,

  /// İstek biçimsel olarak doğru ama bir iş kuralı buna izin vermiyor.
  ///
  /// Kategori: `BUSINESS_RULE_VIOLATION`. Yedek yok — durum kodu yolunda
  /// `409` [dataConflict] üretiyor (bugün sunucudan gelen her `409` zaten
  /// `ConflictException`, yani `DATA_CONFLICT`).
  businessRule,

  /// Kaydın sunucudaki hâli istemcinin varsaydığından farklı: ekrandaki veri
  /// bayat ya da aynı kayıt zaten var.
  ///
  /// Kategori: `DATA_CONFLICT`. Yedek: `409`.
  dataConflict,

  /// İstemci sürümü sunucunun istediği en düşük sürümün altında. Tekrar
  /// denemenin faydası yok; kullanıcının uygulamayı güncellemesi gerekiyor.
  ///
  /// Kategori: `CLIENT_TOO_OLD`. Yedek: `426`.
  upgradeRequired,

  /// İstek sınırı aşıldı (backend'de `RateLimitFilter` var).
  ///
  /// Kategori: `RATE_LIMITED`. Yedek: `429`.
  tooManyRequests,

  /// Sunucu tarafında hata.
  ///
  /// Kategoriler: `UNEXPECTED`, `UPSTREAM_FAILED`. Yedek: `5xx`.
  server,

  /// Sınıflandırılamayan her şey: istemcinin kendi hatası olan uçlar
  /// (`METHOD_NOT_ALLOWED`, `MEDIA_TYPE_NOT_SUPPORTED`), tanınmayan durum
  /// kodları ve zarfı olmayan yanıtlar.
  unknown;

  /// Backend'in `errorCategory` alanını tipe çevirir; **tanımadığı değerde
  /// `null` döner**.
  ///
  /// Küme kapalı ama büyüyebilir: sunucu yeni bir kategori eklediğinde
  /// uygulamanın çökmemesi, durum kodu yedeğine düşmesi gerekiyor. Bu yüzden
  /// `values.byName` gibi fırlatan bir arama değil, açık bir `switch`.
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
      // İstemcinin kendi hatası; kullanıcıya gösterilecek özel bir karşılığı
      // yok, durum koduyla aynı yere düşüyor.
      'METHOD_NOT_ALLOWED' || 'MEDIA_TYPE_NOT_SUPPORTED' => unknown,
      _ => null,
    };
  }

  /// Sunucudaki durum istemcinin varsaydığından farklı — kategorisi hangisi
  /// olursa olsun.
  ///
  /// [businessRule] ile [dataConflict] ayrı tipler, ama "ekrandaki veri bayat,
  /// tazele" diyen çağıranlar için ikisi de aynı şeyi söylüyor. Ayrımı
  /// gerçekten kullanan çağıran (ör. incelemeyi "yapılmış" işaretleyen yol)
  /// bunun yerine tipin kendisine bakıyor.
  bool get isConflict =>
      this == ApiErrorType.businessRule || this == ApiErrorType.dataConflict;
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
