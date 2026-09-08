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
  /// `AuthInterceptor` token yenilemeyi **bu tipe** bakarak deniyor ve
  /// başaramazsa oturumu kapatıyor; kararın kaynağı artık durum kodu değil
  /// ([classify]).
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
  /// Kategori: `BUSINESS_RULE_VIOLATION`. Yedek yok, çünkü durum kodu bu
  /// tipe hiç ulaşamıyor: sunucu bunu `409` ile gönderiyor
  /// (`IllegalStateException` → `GlobalExceptionHandler.handleIllegalState`)
  /// ama `409`'un yedeği [dataConflict]. Kategori gelmezse bu tip
  /// üretilemiyor — bilinen ve kabul edilen kayıp.
  businessRule,

  /// Kaydın sunucudaki hâli istemcinin varsaydığından farklı: ekrandaki veri
  /// bayat ya da aynı kayıt zaten var.
  ///
  /// Kategori: `DATA_CONFLICT`. Yedek: `409` — ama `409`'un iki kategorisi
  /// var ve durum kodu hangisi olduğunu söylemiyor; ayrıntı
  /// [fromStatusCode]'ta.
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
      //
      // `MEDIA_TYPE_NOT_SUPPORTED`'ın backend'de bugün **üreticisi yok**;
      // yalnız `METHOD_NOT_ALLOWED` üretiliyor
      // (`GlobalExceptionHandler.java:131`). Yine de duruyor, üç sebeple:
      //
      // 1. Bu tablo gözlenen kategorilerin değil, sunucunun kapalı kümesinin
      //    (`ErrorCategory.java`) kopyası. Değer orada duruyor; buradan
      //    silmek iki listeyi ayırır ve "17 değerin hepsi karşılanmış mı"
      //    sorusunu cevapsız bırakır.
      // 2. Uygulama multipart yüklüyor (`putFile`, `postFile`,
      //    `postMultipartJson`). Spring bu uçlarda
      //    `HttpMediaTypeNotSupportedException` atıyor ve backend'de o
      //    istisnanın `@ExceptionHandler`'ı henüz yok — bugün `500` +
      //    `UNEXPECTED` oluyor. O boşluk kapandığında üretici tam olarak bu
      //    kategori olacak; yani planlanmış bir tüketici değil, planlanmış
      //    bir **üretici** var.
      // 3. Silmenin karşılığı sıfır: `415` `_typeForStatus`'ta da yok, yani
      //    satır kalksa da tip `unknown` çıkıyor. Kazanç yok, kayıp var.
      //
      // Bu depoda "referansı yok" diye silinen bir enum değeri, planlanan
      // akış gelince geri gerekmişti. Şüphede olan değer bırakılır.
      'METHOD_NOT_ALLOWED' || 'MEDIA_TYPE_NOT_SUPPORTED' => unknown,
      _ => null,
    };
  }

  /// Hata tipini belirler: **önce zarftaki `errorCategory`**, o yoksa ya da
  /// tanınmıyorsa durum kodu.
  ///
  /// Sıra bu yönde, çünkü durum kodu bilgi kaybediyor: sunucu `401` altında
  /// üç, `409` altında iki ayrı kategori döndürüyor ve bunlar kullanıcıdan
  /// farklı şeyler istiyor (is-koala/koala#82).
  ///
  /// Kategori tanınmadığında **istisna atılmıyor**: küme kapalı ama
  /// büyüyebilir; sunucunun eklediği yeni bir değer uygulamayı düşürmemeli,
  /// bugünkü durum kodu davranışına düşmeli.
  ///
  /// Kural burada duruyor, `ApiClient`'ta değil, çünkü **iki çağıranı** var
  /// ve ikisi hatayı farklı katmanlarda görüyor: `ApiClient` zarfı çözdükten
  /// sonra [ApiException]'ı kurarken, `AuthInterceptor` ise henüz ham
  /// `Response` elindeyken oturumu yenileyip yenilemeyeceğine karar verirken
  /// (is-koala/koala#86). Kuralın ikinci bir kopyası çıkarsa ikisi sessizce
  /// ayrışır: yenileme yolu ile kullanıcıya gösterilen tip aynı yanıt için
  /// farklı şey söylerdi.
  static ApiErrorType classify({String? errorCategory, int? statusCode}) {
    return fromCategory(errorCategory) ?? fromStatusCode(statusCode);
  }

  /// Kategori gelmediğinde çalışan yedek.
  ///
  /// Eski sunucu, zarfı elle yazan filtreler ve gövdesi JSON olmayan yanıtlar
  /// için tek bilgi kaynağı bu.
  ///
  /// **`409` iki kategoriden hangisi olduğunu söylemiyor.** Sunucu bu durum
  /// kodunu iki ayrı yoldan üretiyor: `ConflictException` (bir
  /// `KoalaException`) `categoryOf(CONFLICT)` üzerinden `DATA_CONFLICT`
  /// veriyor, `IllegalStateException` ise `handleIllegalState` içinde
  /// doğrudan `BUSINESS_RULE_VIOLATION` veriyor
  /// (`GlobalExceptionHandler.java:86`). Buradaki [dataConflict] bir olgu
  /// değil **seçim**: ikisi de aynı gövdeyi taşıyabildiği için durum
  /// kodundan ayırt edilemiyorlar, ve çağıranların çoğu ([serverStateMoved])
  /// ikisine de aynı tepkiyi veriyor.
  ///
  /// Ayrımı gerçekten önemseyen bir çağıran bu yedeğe güvenmemeli — zaten
  /// güvenmiyor: kategoriden değil `errorCode`'dan karar veriyor.
  static ApiErrorType fromStatusCode(int? statusCode) {
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

  /// Sunucudaki kayıt istemcinin varsaydığından farklı: ekrandaki veri bayat,
  /// tazelenmesi gerekiyor.
  ///
  /// Adı mekanizmayı değil **niyeti** söylüyor. Çağıranların hepsi aynı şeyi
  /// yapıyor — listeyi ya da atamayı yeniden okuyor — ve bunun için
  /// [businessRule] ile [dataConflict] arasındaki farkı bilmeleri gerekmiyor.
  /// Önceki adı `isConflict`'ti ve çağıranı "hangi çakışma?" diye düşünmeye
  /// çağırıyordu; cevabı olmayan bir soru.
  ///
  /// Ayrımı gerçekten kullanan bir yol bu getter'a hiç bakmıyor. `errorCode`
  /// hangi hatanın geldiğini kategoriden daha iyi söylüyor
  /// (`ReviewProvider`, `JobAlertsProvider`), çünkü kategori bir sınıf, kod
  /// ise o hatanın kendisi.
  bool get serverStateMoved =>
      this == ApiErrorType.businessRule || this == ApiErrorType.dataConflict;
}

/// Bir alana bağlı doğrulama hatası. Backend `details` dizisinde döndürüyor.
///
/// JSON'dan kurulması `ApiResponse.fromJson`'da: zarfın bütün metin alanları
/// tek bir tür korumasından geçiyor ve bu da onlardan biri.
class ApiFieldError {
  const ApiFieldError({required this.field, required this.message});

  final String field;
  final String message;
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
