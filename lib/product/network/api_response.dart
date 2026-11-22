import 'package:koala/product/network/api_exception.dart';

/// Backend'in her yanıtı sardığı zarf (`success`, `message`, `data` ...).
///
/// `data` yalnız `SuccessDataResult` dönen uçlarda var. Hata zarfının ek
/// alanları (`errorCode`, `errorCategory`, `details` ...) `NON_NULL` olduğu
/// için koşullu.
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

  /// Backend'in kapalı hata kümesi; sınıflandırmanın asıl kaynağı. Eski sunucu
  /// göndermeyebilir.
  final String? errorCategory;

  final List<ApiFieldError> fieldErrors;

  /// Zarfı çözer. [parse] verilmezse `data` okunmaz — gövdesiz uçlar için.
  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json, {
    T Function(Object? data)? parse,
  }) {
    final details = json['details'];

    return ApiResponse<T>(
      // `as bool?` değil: `"success": "false"` cast hatası verirdi. Yalnız
      // `true` başarı sayılıyor.
      success: json['success'] == true,
      message: _stringOrNull(json['message']),
      data: parse == null ? null : parse(json['data']),
      errorCode: _stringOrNull(json['errorCode']),
      errorCategory: errorCategoryOf(json),
      fieldErrors: details is List
          ? details.whereType<Map<String, dynamic>>().map(_fieldError).toList()
          : const [],
    );
  }

  /// Ham gövdeden yalnız kategoriyi okur; `AuthInterceptor` zarf çözülmeden
  /// önce kullanıyor. Okuma [fromJson] ile aynı yerden geçiyor ki iki okuyucu
  /// ayrışmasın. JSON değilse `null`.
  static String? errorCategoryOf(Object? body) => body is Map<String, dynamic>
      ? _stringOrNull(body['errorCategory'])
      : null;

  /// `details` elemanı; alan adı ya da mesaj dizge değilse boş bırakılıyor.
  static ApiFieldError _fieldError(Map<String, dynamic> json) => ApiFieldError(
    field: _stringOrNull(json['field']) ?? '',
    message: _stringOrNull(json['message']) ?? '',
  );

  /// Alanı yalnız gerçekten dizgeyse okur.
  ///
  /// `as String?` olmaz: bu ayrıştırma `_toApiException` içinden çağrılıyor ve
  /// orada atılan `TypeError` `catch` dalına uğramadan yukarı fırlar; çağıran
  /// `ApiException` yerine ham hata alırdı.
  static String? _stringOrNull(Object? value) => value is String ? value : null;
}
