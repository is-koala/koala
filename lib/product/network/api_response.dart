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
      // `as bool?` değil: gövde `"success": "false"` gibi bir şey taşırsa cast
      // atar. Zarf yalnızca `true` derken başarılı sayılıyor, geri kalan her
      // şey — yanlış tür dahil — başarısız.
      success: json['success'] == true,
      message: _stringOrNull(json['message']),
      data: parse == null ? null : parse(json['data']),
      errorCode: _stringOrNull(json['errorCode']),
      errorCategory: _stringOrNull(json['errorCategory']),
      fieldErrors: details is List
          ? details.whereType<Map<String, dynamic>>().map(_fieldError).toList()
          : const [],
    );
  }

  /// `details` dizisinin bir elemanı. Ayrıştırma burada, çünkü o da zarfın
  /// parçası ve aynı korumayı kullanmalı; alan adı ya da mesaj dizge değilse
  /// hata sayılmıyor, boş bırakılıyor.
  static ApiFieldError _fieldError(Map<String, dynamic> json) => ApiFieldError(
    field: _stringOrNull(json['field']) ?? '',
    message: _stringOrNull(json['message']) ?? '',
  );

  /// Zarftaki bir metin alanını **yalnızca gerçekten dizgeyse** okur; değilse
  /// "gelmedi" sayar.
  ///
  /// `as String?` yerine bunun olmasının sebebi zarfın **tamamı** için
  /// geçerli: bu ayrıştırma `ApiClient._fromResponse` üzerinden
  /// `_toApiException`'ın *içinden* çağrılıyor. Orada atılan bir `TypeError`
  /// `_send`'in `catch (error)` dalına hiç uğramadan yukarı fırlar — bir
  /// `catch` bloğunun içinden atılan hata aynı `try`'ın sonraki dallarına
  /// düşmez. Yani `"errorCode": 42` taşıyan bir gövde çağırana `ApiException`
  /// değil ham bir `_TypeError` verirdi.
  ///
  /// Koruma tek tek alanlara değil zarfın geneline konuyor: hangi alanın
  /// korunduğunu hatırlamak gerekmesin. Sunucu sözleşmesi bu alanların
  /// hepsine dizge diyor; gövdenin biçimi istemciyi düşürmemeli.
  static String? _stringOrNull(Object? value) => value is String ? value : null;
}
