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
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.errorCode,
    this.fieldErrors = const [],
  });

  final bool success;
  final String? message;
  final T? data;
  final String? errorCode;
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
      fieldErrors: details is List
          ? details
                .whereType<Map<String, dynamic>>()
                .map(ApiFieldError.fromJson)
                .toList()
          : const [],
    );
  }
}
