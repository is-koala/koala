import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:koala/product/constants/app_info.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_response.dart';
import 'package:koala/product/network/app_update_gate.dart';
import 'package:koala/product/network/auth_interceptor.dart';
import 'package:koala/product/network/device_identity.dart';
import 'package:koala/product/network/device_interceptor.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';

/// Backend'e giden bütün isteklerin geçtiği tek kapı.
///
/// İki işi var: yanıt zarfını açmak ve `DioException`'ı [ApiException]'a
/// çevirmek. Servisler dio'yu hiç görmüyor.
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

  /// Testlerde sahte bir `HttpClientAdapter` takılı dio geçilebilsin diye.
  ///
  /// Zinciri **üretimdekiyle aynı** kuruyor. Eskiden hiçbir interceptor
  /// takmıyordu; 630 testin hiçbiri `Authorization` başlığını, `X-Device-Id`'yi
  /// ya da `401` sonrası yenilemeyi çalıştırmıyordu, yani bir interceptor
  /// bozulsa hiçbir test kırmızıya dönmüyordu (is-koala/koala#21).
  ///
  /// Keychain ve `SharedPreferences` testte yok, o yüzden [tokenStorage] ile
  /// [deviceIdentity] dışarıdan veriliyor — üretim tekilleri varsayılan
  /// yapılsaydı testler platform kanalına gitmeye çalışırdı.
  @visibleForTesting
  ApiClient.withDio(
    this._dio, {
    required TokenStorage tokenStorage,
    required DeviceIdentity deviceIdentity,
    required Future<void> Function() onSessionExpired,
  }) {
    _attachInterceptors(
      deviceIdentity: deviceIdentity,
      tokenStorage: tokenStorage,
      // Yenileme ve tekrar deneme ayrı bir dio'dan gidiyor; testte o da aynı
      // sahte katmandan geçmeli, yoksa gerçek ağa çıkmaya çalışırdı.
      tokenDio: Dio(_dio.options)..httpClientAdapter = _dio.httpClientAdapter,
      onSessionExpired: onSessionExpired,
    );
  }

  final Dio _dio;

  /// İstek hattının tamamı: cihaz başlığı, sonra oturum.
  ///
  /// İki kurucu da buradan geçiyor — zincirin şekli tek yerde durmazsa
  /// testlerdeki istemci üretimdekinden sessizce ayrılıyor.
  void _attachInterceptors({
    required DeviceIdentity deviceIdentity,
    required TokenStorage tokenStorage,
    required Dio tokenDio,
    required Future<void> Function() onSessionExpired,
  }) {
    // Cihaz başlığı hem ana istemciye hem yenileme istemcisine gerekiyor:
    // backend oturumu yenilerken de cihazı doğruluyor.
    tokenDio.interceptors.add(DeviceInterceptor(deviceIdentity));

    _dio.interceptors
      ..add(DeviceInterceptor(deviceIdentity))
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
          // Sunucu bu başlığa bakarak eski istemciyi `426` ile geri
          // çeviriyor. Başlık yoksa filtre isteği geçiriyor, yani
          // göndermemek zorunlu güncellemeyi tamamen devre dışı bırakıyor.
          ApiConfig.appVersionHeader: AppInfo.version,
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    return dio;
  }

  /// Gövdesinde veri dönen `GET` isteği.
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

  /// Gövdesinde veri dönen `POST` isteği.
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

  /// JSON bir parça ve isteğe bağlı tek dosya içeren multipart POST.
  ///
  /// Şirket oluşturma gibi Spring `@RequestPart` uçlarında JSON gövdesi
  /// sıradan form alanı değil `application/json` içerik tipli ayrı bir parça
  /// olmalı. Bu ayrıntıyı servislerin her birinde tekrar etmiyoruz.
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

  /// Tek dosya yükleyen `POST` isteği.
  ///
  /// [postMultipartJson]'dan farkı, JSON parçası istememesi: galeriye görsel
  /// ekleyen uçlar yalnızca `@RequestPart("image") MultipartFile` alıyor,
  /// yanına konacak bir JSON parçası uydurmak sunucunun beklemediği bir
  /// parçayı göndermek olurdu. [putFile]'dan farkı yöntemin `POST` olması.
  /// [fieldName] backend'in beklediği parça adı (`image`, `file` ...).
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

  /// Yalnızca başarı/başarısızlık dönen `POST` isteği (`SuccessResult`).
  Future<void> postWithoutData(String path, {Object? body}) {
    return _send<void>(() => _dio.post<dynamic>(path, data: body));
  }

  /// Yalnızca başarı/başarısızlık dönen `PUT` isteği (`SuccessResult`).
  ///
  /// [put]'tan farkı `parse` istememesi: parola değiştirme gibi uçlar
  /// gövdesinde veri döndürmüyor, zorunlu bir `parse` orada yazılacak hiçbir
  /// şeyi olmayan bir dönüştürücü uydurmayı gerektirirdi.
  Future<void> putWithoutData(String path, {Object? body}) {
    return _send<void>(() => _dio.put<dynamic>(path, data: body));
  }

  /// Yalnızca başarı/başarısızlık dönen `DELETE` isteği.
  Future<void> deleteWithoutData(String path) {
    return _send<void>(() => _dio.delete<dynamic>(path));
  }

  /// Gövdesinde veri dönen `DELETE` isteği.
  ///
  /// Bazı uçlar silme sonrası kaydın yeni hâlini döndürüyor (ör. logo
  /// kaldırıldıktan sonra şirketin kendisi); ikinci bir okuma isteği
  /// atmamak için.
  Future<T> delete<T>(String path, {required T Function(Object? data) parse}) {
    return _send<T>(() => _dio.delete<dynamic>(path), parse: parse);
  }

  /// Tek dosya yükleyen `PUT` isteği.
  ///
  /// Dosyayı `multipart/form-data` olarak gönderiyor; [fieldName] backend'in
  /// beklediği parça adı (`logo`, `image`, `file` ...).
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

  /// Veri gövdesi döndürmeyen tek dosyalı multipart PUT isteği.
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

  /// Gövdesinde veri dönen `PUT` isteği.
  ///
  /// [patch]'ten farkı, kaydın tamamının gönderilmesi: gövdeye konmayan alan
  /// "değişmedi" değil "boş" anlamına geliyor.
  Future<T> put<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) {
    return _send<T>(() => _dio.put<dynamic>(path, data: body), parse: parse);
  }

  /// Gövdesinde veri dönen `PATCH` isteği.
  ///
  /// Backend kısmi güncellemede yalnızca gönderilen alanlara bakıyor, o yüzden
  /// [body]'ye değişmeyen alanları koymamak gerekiyor.
  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) {
    return _send<T>(() => _dio.patch<dynamic>(path, data: body), parse: parse);
  }

  /// Multipart isteklerin içerik tipi. Taban ayarlarda `application/json`
  /// yazdığı için `FormData` verilse bile açıkça geçersiz kılınması gerekiyor;
  /// aksi hâlde Spring isteği `415` ile geri çevirir.
  ///
  /// Her çağrıda yeni bir nesne veriyor: dio `Options.method`'u geçilen
  /// nesnenin üstüne yazıyor, paylaşılan tek bir örnek `POST` ile `PUT`
  /// isteklerinin birbirinin yöntemini ezmesine açık kapı bırakırdı.
  static Options get _multipartOptions =>
      Options(contentType: Headers.multipartFormDataContentType);

  /// Tek dosya taşıyan multipart gövde. [fieldName] backend'in beklediği
  /// parça adı (`image`, `logo`, `file` ...).
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

      // Başarı bayrağı önce kontrol ediliyor: başarısız yanıtta `data` ya hiç
      // yok ya da beklenen biçimde değil, ayrıştırmaya kalkmak gerçek hata
      // mesajının üstünü örterdi.
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
        type: _typeForStatus(statusCode),
        statusCode: statusCode,
      );
    }

    final envelope = ApiResponse.fromJson<void>(body);

    final type = _typeFor(envelope, statusCode);

    // Sürüm kapısı her uçtan gelebiliyor; çağıranın karşılamasını beklemek
    // yerine burada bir kez yakalanıyor.
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
  ApiErrorType _typeFor(ApiResponse<void> envelope, int? statusCode) {
    return ApiErrorType.fromCategory(envelope.errorCategory) ??
        _typeForStatus(statusCode);
  }

  /// Kategori gelmediğinde çalışan yedek.
  ///
  /// Eski sunucu, zarfı elle yazan filtreler ve gövdesi JSON olmayan yanıtlar
  /// için tek bilgi kaynağı bu. Ürettiği tipler kategori eşlemesiyle uyumlu:
  /// `409` [ApiErrorType.dataConflict] veriyor, çünkü bugün sunucudan gelen
  /// her `409` `ConflictException`, yani `DATA_CONFLICT`.
  ApiErrorType _typeForStatus(int? statusCode) {
    if (statusCode == null) return ApiErrorType.unknown;
    if (statusCode == 400 || statusCode == 422) return ApiErrorType.validation;
    if (statusCode == 401) return ApiErrorType.unauthenticated;
    if (statusCode == 403) return ApiErrorType.forbidden;
    if (statusCode == 404) return ApiErrorType.notFound;
    if (statusCode == 409) return ApiErrorType.dataConflict;
    if (statusCode == 429) return ApiErrorType.tooManyRequests;
    if (statusCode == 426) return ApiErrorType.upgradeRequired;
    if (statusCode >= 500) return ApiErrorType.server;
    return ApiErrorType.unknown;
  }
}
