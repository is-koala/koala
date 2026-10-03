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
/// [filename] ve [contentType] verilmezse dio dosya adından türetiyor;
/// dosyanın adı içeriğini yansıtmıyorsa (Android seçicisinin `.heic` adıyla
/// verdiği JPEG gibi) çağıran ikisini gerçek içeriğe göre yazıyor — sunucu
/// uzantıya bakıyor.
class UploadFile {
  const UploadFile(this.path, {this.filename, this.contentType});

  final String path;

  /// Parçanın `filename` alanı; `null` ise dosyanın kendi adı.
  final String? filename;

  /// Parçanın içerik tipi (`image/jpeg` gibi); `null` ise addan türetilir.
  final String? contentType;
}

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
  /// yapılsaydı testler platform kanalına gitmeye çalışırdı. [deviceHints]
  /// verilmezse test makinesinin kendi değerleri gidiyor; başlıkları ölçen
  /// test sabit bir ipucu geçiyor.
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
    DeviceHints? deviceHints,
  }) {
    // Cihaz başlıkları hem ana istemciye hem yenileme istemcisine gerekiyor:
    // backend oturumu yenilerken de cihazı doğruluyor ve adını tazeliyor.
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

  /// JSON bir parça ve **birden çok** dosya içeren multipart POST.
  ///
  /// [postMultipartJson]'dan farkı dosya sayısı ve ilerleme: kimlik
  /// belgeleri gibi dört dosyayı tek istekte taşıyan uçlar için. [files]
  /// parça adı → dosya; her dosya kendi parçasında, adı ve içerik tipi
  /// [UploadFile]'dan. [onSendProgress] gönderilen ve toplam bayt sayısını
  /// veriyor — kırk megabaytlık bir gövde mobil ağda dakikalar sürebiliyor,
  /// kullanıcı takıldığını sanmasın.
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

  /// Tek dosya yükleyen, ad ve içerik tipini kendisi yazan `POST` isteği.
  ///
  /// [postFile]'dan farkı, parçanın `filename` ve `Content-Type`'ının
  /// [UploadFile]'dan gelmesi ve ilerleme: sunucu uzantıya bakıyor, seçicinin
  /// verdiği ad ise içeriği yansıtmayabiliyor (Android'in `.heic` adlı JPEG'i).
  /// [onSendProgress] gönderilen ve toplam bayt sayısını veriyor.
  ///
  /// `async`: dosya açılamazsa (seçicinin geçici kopyası bu arada silinmiş
  /// olabilir) hata eşzamanlı fırlamak yerine `Future`'dan, yani çağıranın
  /// `await`'inden [ApiException] olarak çıkıyor.
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

  /// [UploadFile]'ı multipart parçasına çevirir; ad ve içerik tipi dosyanın
  /// kendisinden değil [UploadFile]'dan.
  ///
  /// Dosya **eşzamanlı** açılıyor: boyut tek `stat` ile okunuyor, içerik
  /// gönderim sırasında akıtılıyor. Eşzamansız `fromFile` widget testlerinin
  /// sahte saatinde hiç dönmüyor ve akış ekranda takılı kalıyordu; gerçek
  /// cihazda iki yol arasında ölçülebilir fark yok.
  ///
  /// Dosya yoksa ya da okunamıyorsa `FileSystemException` değil
  /// [ApiException]: servisler yalnızca onu yükseltir (CONTRIBUTING, "Veri
  /// Katmanı") ve sayfa tek bir hata yolu yönetir. Seçicinin geçici dosyası
  /// işletim sistemi tarafından temizlenmiş olabilir (iOS `tmp`).
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

  /// Yönlendirmeyle cevap veren bir `GET`'in hedef adresini döndürür.
  ///
  /// Dosya indirme uçları (`.../download`) imzalı bir depo adresine `302`
  /// veriyor ve kendileri `Authorization` istiyor. Yönlendirmeyi **izlemek**
  /// o başlığı depoya taşıyabilir (S3 imzalı adres + ikinci kimlik doğrulama
  /// `400` döner, üstelik token üçüncü bir sunucuya gider); o yüzden `302`
  /// burada duruyor ve `Location` okunuyor.
  ///
  /// Yanıt gövdesi **akış** olarak alınıyor ve hiç okunmadan bırakılıyor:
  /// yalnız başlık gerekiyor. Varsayılan JSON yanıt tipinde sunucunun
  /// akıttığı üç megabaytlık bir dosya bütünüyle belleğe alınıp metne
  /// çevriliyordu. Hata yanıtlarının (küçük) zarfı ise okunup olağan
  /// [ApiException]'a çevriliyor.
  ///
  /// Hedefin şeması [allowedSchemes] içinde olmalı (varsayılan:
  /// [ApiConfig.externalUrlSchemes] — yalnız `https`, dev'de `http` de): bu
  /// adres harici uygulamaya veriliyor, `intent:` ya da şifresiz `http`
  /// buraya sızmamalı. Sunucu depo imzası yapamıyorsa baytları kendisi
  /// akıtıyor (`200`); o durumda `null` dönüyor — çağıran "uygulama içinde
  /// açılamıyor" demeli.
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

  /// Gövdesi okunmayacak bir akışı kapatır: bağlantı dosyanın geri kalanını
  /// beklemeden bırakılıyor. İptal **beklenmiyor**: bağlantıyı kapatmak
  /// çağıranın sonucunu geciktirmemeli (ve sahte saatli widget testlerinde
  /// bu iptal hiç tamamlanmıyor); iptalin hatası da kimsenin işi değil.
  void _discardBody(ResponseBody? body) {
    if (body == null) return;
    unawaited(body.stream.listen(null).cancel().catchError((Object _) {}));
  }

  /// Akış olarak alınmış bir hata yanıtının gövdesini okuyup JSON zarfı olarak
  /// yerine koyar; [_toApiException] zarfı ancak çözülmüş hâliyle okuyabiliyor.
  /// Zarf küçük: [_maxErrorBodyBytes]'ı aşan ya da JSON olmayan gövde okunmamış
  /// sayılıyor ve karar durum koduna kalıyor.
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

  /// Akış olarak alınan hata gövdesinin okunacak en büyük boyutu.
  static const int _maxErrorBodyBytes = 64 * 1024;

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
        // Zarf yok, yani okunacak kategori de yok — ama yedek tabloya
        // doğrudan gidilmiyor. `errorCategory: null` "bu yanıtın kategorisi
        // yok" demenin kuralın kendi diliyle yazılmış hâli; karar yine tek
        // kapıdan geçiyor. Yedeğe buradan kestirme atılsaydı tablo dışarıya
        // açık kalmak zorunda kalır, o kapıdan giren bir çağıran da
        // kategoriyi hiç okumadan #86'nın kusurunu geri getirirdi.
        type: ApiErrorType.classify(
          errorCategory: null,
          statusCode: statusCode,
        ),
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

  /// Zarfın taşıdığı kategori ile durum kodunu tipe çevirir.
  ///
  /// Kuralın kendisi [ApiErrorType.classify]'da: `AuthInterceptor` de aynı
  /// kararı vermek zorunda ve kural iki kopyaya bölünmemeli
  /// (is-koala/koala#86).
  ApiErrorType _typeFor(ApiResponse<void> envelope, int? statusCode) {
    return ApiErrorType.classify(
      errorCategory: envelope.errorCategory,
      statusCode: statusCode,
    );
  }
}
