import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:koala/product/constants/app_info.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_response.dart';
import 'package:koala/product/network/app_update_gate.dart';
import 'package:koala/product/network/auth_interceptor.dart';
import 'package:koala/product/network/device_hints.dart';
import 'package:koala/product/network/device_identity.dart';
import 'package:koala/product/network/device_interceptor.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';

/// Multipart isteğe eklenecek tek dosya.
///
/// Sunucu uzantıya bakıyor; dosya adı içeriği yansıtmıyorsa (Android'in `.heic`
/// adlı JPEG'i) çağıran [filename] ve [contentType]'ı içeriğe göre yazar.
class UploadFile {
  const UploadFile(this.path, {this.filename, this.contentType});

  final String path;

  final String? filename;

  final String? contentType;
}

/// Backend'e giden bütün isteklerin geçtiği tek kapı: zarfı açar,
/// `DioException`'ı [ApiException]'a çevirir.
class ApiClient {
  ApiClient._internal() : _dio = _buildDio() {
    _attachInterceptors(
      deviceIdentity: DeviceIdentity(),
      tokenStorage: TokenStorage(),
      tokenDio: _buildDio(),
      onSessionExpired: SessionManager().end,
    );
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  /// Testler için; sahte `HttpClientAdapter` takılı dio alır.
  ///
  /// Zinciri **üretimdekiyle aynı** kuruyor, yoksa bozulan bir interceptor
  /// hiçbir testi kırmaz (is-koala/koala#21). [tokenStorage] ve
  /// [deviceIdentity] dışarıdan geliyor çünkü testte platform kanalı yok.
  @visibleForTesting
  ApiClient.withDio(
    this._dio, {
    required TokenStorage tokenStorage,
    required DeviceIdentity deviceIdentity,
    required Future<void> Function() onSessionExpired,
    DeviceHints? deviceHints,
  }) {
    _attachInterceptors(
      deviceIdentity: deviceIdentity,
      deviceHints: deviceHints,
      tokenStorage: tokenStorage,
      // Yenileme ayrı bir dio'dan gidiyor; testte o da sahte katmandan geçmeli.
      tokenDio: Dio(_dio.options)..httpClientAdapter = _dio.httpClientAdapter,
      onSessionExpired: onSessionExpired,
    );
  }

  final Dio _dio;

  /// İstek hattı: cihaz başlığı, sonra oturum. İki kurucu da buradan geçiyor ki
  /// test istemcisi üretimdekinden ayrışmasın.
  void _attachInterceptors({
    required DeviceIdentity deviceIdentity,
    required TokenStorage tokenStorage,
    required Dio tokenDio,
    required Future<void> Function() onSessionExpired,
    DeviceHints? deviceHints,
  }) {
    // Backend yenileme sırasında da cihazı doğruluyor.
    final hints = deviceHints ?? DeviceHints.current();
    tokenDio.interceptors.add(DeviceInterceptor(deviceIdentity, hints: hints));

    _dio.interceptors
      ..add(DeviceInterceptor(deviceIdentity, hints: hints))
      ..add(
        AuthInterceptor(
          tokenStorage: tokenStorage,
          tokenDio: tokenDio,
          onSessionExpired: onSessionExpired,
        ),
      );
  }

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          HttpHeaders.acceptLanguageHeader: ApiConfig.acceptLanguage,
          HttpHeaders.userAgentHeader: DeviceIdentity.userAgent,
          // Sunucu eski istemciyi bu başlıkla `426`'ya çeviriyor; başlık yoksa
          // zorunlu güncelleme hiç çalışmaz.
          ApiConfig.appVersionHeader: AppInfo.version,
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    return dio;
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? data) parse,
  }) {
    return _send<T>(
      () => _dio.get<dynamic>(path, queryParameters: queryParameters),
      parse: parse,
    );
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? data) parse,
  }) {
    return _send<T>(
      () => _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
      ),
      parse: parse,
    );
  }

  /// JSON parçası ve isteğe bağlı tek dosyalı multipart `POST`. Spring
  /// `@RequestPart` uçlarında JSON, `application/json` tipli ayrı bir parça
  /// olmalı.
  Future<T> postMultipartJson<T>(
    String path, {
    required String jsonFieldName,
    required Map<String, dynamic> jsonBody,
    String? fileFieldName,
    String? filePath,
    required T Function(Object? data) parse,
  }) async {
    final parts = <String, Object>{
      jsonFieldName: MultipartFile.fromString(
        jsonEncode(jsonBody),
        filename: '$jsonFieldName.json',
        contentType: DioMediaType('application', 'json'),
      ),
    };

    if (fileFieldName != null && filePath != null) {
      parts[fileFieldName] = await MultipartFile.fromFile(filePath);
    }

    return _send<T>(
      () => _dio.post<dynamic>(
        path,
        data: FormData.fromMap(parts),
        options: _multipartOptions,
      ),
      parse: parse,
    );
  }

  /// JSON parçası ve birden çok dosyalı multipart `POST` (ör. dört kimlik
  /// belgesi). [onSendProgress] var çünkü 40 MB'lık gövde mobil ağda dakikalar
  /// sürebilir.
  Future<T> postMultipartJsonFiles<T>(
    String path, {
    required String jsonFieldName,
    required Map<String, dynamic> jsonBody,
    required Map<String, UploadFile> files,
    void Function(int sent, int total)? onSendProgress,
    required T Function(Object? data) parse,
  }) async {
    final parts = <String, Object>{
      jsonFieldName: MultipartFile.fromString(
        jsonEncode(jsonBody),
        filename: '$jsonFieldName.json',
        contentType: DioMediaType('application', 'json'),
      ),
    };

    for (final entry in files.entries) {
      parts[entry.key] = _multipartFile(entry.value);
    }

    return _send<T>(
      () => _dio.post<dynamic>(
        path,
        data: FormData.fromMap(parts),
        options: _multipartOptions,
        onSendProgress: onSendProgress,
      ),
      parse: parse,
    );
  }

  /// Tek dosya yükleyen `POST`; ad ve içerik tipi [UploadFile]'dan.
  ///
  /// `async`, böylece açılamayan dosya (silinmiş geçici kopya) eşzamanlı
  /// fırlamak yerine [ApiException] olarak `await`'ten çıkar.
  Future<T> postUploadFile<T>(
    String path, {
    required String fieldName,
    required UploadFile file,
    void Function(int sent, int total)? onSendProgress,
    required T Function(Object? data) parse,
  }) async {
    final formData = FormData.fromMap({fieldName: _multipartFile(file)});

    return _send<T>(
      () => _dio.post<dynamic>(
        path,
        data: formData,
        options: _multipartOptions,
        onSendProgress: onSendProgress,
      ),
      parse: parse,
    );
  }

  /// [UploadFile]'ı multipart parçasına çevirir.
  ///
  /// Dosya **eşzamanlı** açılıyor: eşzamansız `fromFile` widget testlerinin
  /// sahte saatinde hiç dönmüyor. Okunamayan dosya [ApiException] olur ki sayfa
  /// tek hata yolu yönetsin.
  MultipartFile _multipartFile(UploadFile file) {
    final contentType = file.contentType;
    try {
      return MultipartFile.fromFileSync(
        file.path,
        filename: file.filename,
        contentType: contentType == null
            ? null
            : DioMediaType.parse(contentType),
      );
    } on FileSystemException {
      throw const ApiException(
        message: 'Dosya okunamadı. Dosyayı yeniden seçin.',
        type: ApiErrorType.unknown,
      );
    }
  }

  /// Yönlendirmeyle cevap veren bir `GET`'in hedefini döndürür.
  ///
  /// İndirme uçları `Authorization` istiyor ve imzalı depo adresine `302`
  /// veriyor; yönlendirmeyi izlemek token'ı depoya taşır. O yüzden `Location`
  /// okunuyor, gövde akış olarak alınıp okunmadan bırakılıyor.
  ///
  /// Hedef şeması [allowedSchemes] içinde olmalı, çünkü adres harici uygulamaya
  /// veriliyor. Sunucu baytları kendisi akıtıyorsa (`200`) `null` döner.
  Future<Uri?> getRedirectLocation(
    String path, {
    @visibleForTesting Set<String>? allowedSchemes,
  }) async {
    final schemes = allowedSchemes ?? ApiConfig.externalUrlSchemes;
    try {
      final response = await _dio.get<ResponseBody>(
        path,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      _discardBody(response.data);

      final status = response.statusCode ?? 0;
      if (status < 300) return null;

      final location = response.headers.value(HttpHeaders.locationHeader);
      final target = location == null ? null : Uri.tryParse(location);
      if (target != null &&
          target.host.isNotEmpty &&
          schemes.contains(target.scheme)) {
        return target;
      }
      throw const ApiException(
        message: 'Sunucudan beklenmeyen bir yanıt geldi.',
        type: ApiErrorType.unknown,
      );
    } on DioException catch (error) {
      throw _toApiException(await _withReadBody(error));
    }
  }

  /// Okunmayacak akışı kapatır. İptal beklenmiyor: sonucu geciktirmemeli ve
  /// sahte saatli testlerde hiç tamamlanmıyor.
  void _discardBody(ResponseBody? body) {
    if (body == null) return;
    unawaited(body.stream.listen(null).cancel().catchError((Object _) {}));
  }

  /// Akış olarak alınan hata gövdesini okuyup JSON zarfı olarak koyar. Sınırı
  /// aşan ya da JSON olmayan gövdede karar durum koduna kalır.
  Future<DioException> _withReadBody(DioException error) async {
    final response = error.response;
    final body = response?.data;
    if (response == null || body is! ResponseBody) return error;

    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      bytes.add(chunk);
      if (bytes.length > _maxErrorBodyBytes) break;
    }

    Object? decoded;
    if (bytes.length <= _maxErrorBodyBytes) {
      try {
        decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      } on FormatException {
        decoded = null;
      }
    }
    return error.copyWith(
      response: Response<dynamic>(
        requestOptions: response.requestOptions,
        data: decoded,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        headers: response.headers,
        isRedirect: response.isRedirect,
        redirects: response.redirects,
        extra: response.extra,
      ),
    );
  }

  static const int _maxErrorBodyBytes = 64 * 1024;

  /// JSON parçası olmadan tek dosya yükleyen `POST` (ör. galeri
  /// `@RequestPart("image")`). [fieldName] parça adı.
  Future<T> postFile<T>(
    String path, {
    required String fieldName,
    required String filePath,
    required T Function(Object? data) parse,
  }) async {
    final formData = await _fileFormData(fieldName, filePath);

    return _send<T>(
      () =>
          _dio.post<dynamic>(path, data: formData, options: _multipartOptions),
      parse: parse,
    );
  }

  Future<void> postWithoutData(String path, {Object? body}) {
    return _send<void>(() => _dio.post<dynamic>(path, data: body));
  }

  /// Veri dönmeyen `PUT`; gereksiz bir `parse` uydurmamak için.
  Future<void> putWithoutData(String path, {Object? body}) {
    return _send<void>(() => _dio.put<dynamic>(path, data: body));
  }

  Future<void> deleteWithoutData(String path) {
    return _send<void>(() => _dio.delete<dynamic>(path));
  }

  /// Veri dönen `DELETE`; ör. logo kaldırınca şirketin yeni hâli.
  Future<T> delete<T>(String path, {required T Function(Object? data) parse}) {
    return _send<T>(() => _dio.delete<dynamic>(path), parse: parse);
  }

  /// Tek dosyalı multipart `PUT`. [fieldName] parça adı.
  Future<T> putFile<T>(
    String path, {
    required String fieldName,
    required String filePath,
    required T Function(Object? data) parse,
  }) async {
    final formData = await _fileFormData(fieldName, filePath);

    return _send<T>(
      () => _dio.put<dynamic>(path, data: formData, options: _multipartOptions),
      parse: parse,
    );
  }

  Future<void> putFileWithoutData(
    String path, {
    required String fieldName,
    required String filePath,
  }) async {
    final formData = await _fileFormData(fieldName, filePath);
    return _send<void>(
      () => _dio.put<dynamic>(path, data: formData, options: _multipartOptions),
    );
  }

  /// Veri dönen `PUT`. Kaydın tamamı gönderilir: konmayan alan "boş" demek.
  Future<T> put<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) {
    return _send<T>(() => _dio.put<dynamic>(path, data: body), parse: parse);
  }

  /// Veri dönen `PATCH`. Yalnız değişen alanlar gönderilmeli.
  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) {
    return _send<T>(() => _dio.patch<dynamic>(path, data: body), parse: parse);
  }

  /// Taban ayar `application/json` olduğu için multipart'ta tip açıkça
  /// yazılmalı, yoksa Spring `415` döner. Her çağrıda yeni nesne: dio
  /// `Options.method`'u üstüne yazıyor.
  static Options get _multipartOptions =>
      Options(contentType: Headers.multipartFormDataContentType);

  Future<FormData> _fileFormData(String fieldName, String filePath) async {
    return FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
  }

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request, {
    T Function(Object? data)? parse,
  }) async {
    try {
      final response = await request();
      final body = response.data;

      if (body is! Map<String, dynamic>) {
        throw const ApiException(
          message: 'Sunucudan beklenmeyen bir yanıt geldi.',
          type: ApiErrorType.unknown,
        );
      }

      // Başarısız yanıtta `data`'yı ayrıştırmak gerçek hata mesajını örterdi.
      if (body['success'] != true) {
        final envelope = ApiResponse.fromJson<void>(body);

        throw ApiException(
          message: envelope.message ?? 'İşlem tamamlanamadı.',
          type: _typeFor(envelope, response.statusCode),
          statusCode: response.statusCode,
          errorCode: envelope.errorCode,
          fieldErrors: envelope.fieldErrors,
        );
      }

      return ApiResponse.fromJson<T>(body, parse: parse).data as T;
    } on DioException catch (error) {
      throw _toApiException(error);
    } catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const ApiException(
          message: 'Sunucudan beklenmeyen bir yanıt geldi.',
          type: ApiErrorType.unknown,
        );
      }
      rethrow;
    }
  }

  ApiException _toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          message: 'Sunucu zamanında yanıt vermedi. Lütfen tekrar dene.',
          type: ApiErrorType.timeout,
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.',
          type: ApiErrorType.network,
        );

      case DioExceptionType.cancel:
        return const ApiException(
          message: 'İstek iptal edildi.',
          type: ApiErrorType.unknown,
        );

      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'Sunucu sertifikası doğrulanamadı.',
          type: ApiErrorType.network,
        );

      case DioExceptionType.badResponse:
        return _fromResponse(error.response);

      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const ApiException(
            message: 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.',
            type: ApiErrorType.network,
          );
        }
        return const ApiException(
          message: 'Beklenmeyen bir hata oluştu.',
          type: ApiErrorType.unknown,
        );
    }
  }

  ApiException _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final body = response?.data;

    if (body is! Map<String, dynamic>) {
      return ApiException(
        message: 'Beklenmeyen bir hata oluştu.',
        // Zarf yok; yine de karar tek kapıdan geçiyor.
        type: ApiErrorType.classify(
          errorCategory: null,
          statusCode: statusCode,
        ),
        statusCode: statusCode,
      );
    }

    final envelope = ApiResponse.fromJson<void>(body);

    final type = _typeFor(envelope, statusCode);

    // Sürüm kapısı her uçtan gelebilir; burada bir kez yakalanıyor.
    if (type == ApiErrorType.upgradeRequired) {
      AppUpdateGate().block(envelope.message);
    }

    return ApiException(
      message: envelope.message ?? 'Beklenmeyen bir hata oluştu.',
      type: type,
      statusCode: statusCode,
      errorCode: envelope.errorCode,
      fieldErrors: envelope.fieldErrors,
    );
  }

  ApiErrorType _typeFor(ApiResponse<void> envelope, int? statusCode) {
    return ApiErrorType.classify(
      errorCategory: envelope.errorCategory,
      statusCode: statusCode,
    );
  }
}
