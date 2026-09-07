import 'package:koala/product/network/api_exception.dart';

/// Backend'in her yanıtı sardığı zarf.
///
/// ```json
/// { "success": true, "message": "...", "httpStatus": "OK", "path": "/auth/login",
///   "timeStamp": "...", "requestId": "...", "data": { } }
/// ```
///
/// `data` yalnızca `SuccessDataResult` dönen uçlarda var; `SuccessResult`
/// dönenlerde alan hiç gelmiyor.
///
/// Hata zarfı (`ErrorResult`) bunun üstüne beş alan ekliyor: `errorCode`,
/// `errorCategory`, `resource`, `resourceId`, `details`. `ErrorResult`
/// `@JsonInclude(NON_NULL)` taşıdığı için hepsi **koşullu** — biri gelmedi
/// diye hata sayılmaz.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.errorCode,
    this.errorCategory,
    this.fieldErrors = const [],
  });

  final bool success;
  final String? message;
  final T? data;
  final String? errorCode;

  /// Backend'in kapalı hata kümesi (`ErrorCategory`). Hata sınıflandırmasının
  /// asıl kaynağı bu; `errorCode` serbest metne yakın, kategori değil.
  ///
  /// `@JsonInclude(NON_NULL)` yüzünden yok olabilir; eski sunucu ya da zarfı
  /// elle yazan filtreler alanı hiç göndermeyebilir.
  final String? errorCategory;

  final List<ApiFieldError> fieldErrors;

  /// Zarfı çözer. [parse] verilmezse `data` okunmaz — gövdesiz uçlar için.
  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json, {
    T Function(Object? data)? parse,
  }) {
    final details = json['details'];

    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: parse == null ? null : parse(json['data']),
      errorCode: json['errorCode'] as String?,
      // `as String?` değil: alan beklenmedik bir türde gelirse cast bir
      // `TypeError` atar ve bu ayrıştırma `_toApiException`'ın içinden
      // çağrıldığı için `ApiClient`'ın `TypeError` ağına takılmadan yukarı
      // fırlar — yani sınıflandırmanın kaynağı olan alan uygulamayı
      // düşürebilirdi. Tanınmayan kategoriyle aynı yere düşsün: yok sayılsın.
      errorCategory: switch (json['errorCategory']) {
        final String category => category,
        _ => null,
      },
      fieldErrors: details is List
          ? details
                .whereType<Map<String, dynamic>>()
                .map(ApiFieldError.fromJson)
                .toList()
          : const [],
    );
  }
}
