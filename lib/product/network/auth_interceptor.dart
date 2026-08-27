import 'package:dio/dio.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/token_storage.dart';

/// İsteklere `Authorization` başlığını ekler ve 401 gelen isteği bir kez
/// `/auth/refresh-token` ile tazeleyip tekrar dener.
///
/// `QueuedInterceptor`'dan türüyor: aynı anda 401 alan birden fazla istek
/// olduğunda token yalnızca bir defa yenilensin diye istekler sıraya giriyor.
///
/// Yenileme çağrısı, süresi **dolmuş** erişim token'ıyla da çalışıyor:
/// backend `/auth/refresh-token` yolunda oturum filtresini atlıyor ve oturum
/// kimliğini süresi dolmuş JWT'nin claim'lerinden okuyor. Bu yüzden istek
/// yine de `Authorization` başlığını taşımak zorunda — yol bilerek
/// [ApiPaths.publicPaths] içinde değil.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio tokenDio,
    required Future<void> Function() onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _tokenDio = tokenDio,
       _onSessionExpired = onSessionExpired;

  final TokenStorage _tokenStorage;

  /// Yenileme ve tekrar deneme bu istemci üzerinden gidiyor; kendi
  /// interceptor'ına takılıp sonsuz döngüye girmesin diye ayrı.
  final Dio _tokenDio;

  final Future<void> Function() _onSessionExpired;

  /// Bir isteğin zaten bir kez tekrar denendiğini işaretleyen anahtar.
  static const String _retriedKey = 'koala_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!ApiPaths.publicPaths.contains(options.path)) {
      final accessToken = await _tokenStorage.readAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRefresh(err)) {
      handler.next(err);
      return;
    }

    if (!await _refreshAccessToken()) {
      await _onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _retry(err.requestOptions));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRefresh(DioException err) {
    if (err.response?.statusCode != 401) return false;

    final path = err.requestOptions.path;
    if (path == ApiPaths.refreshToken) return false;
    if (ApiPaths.publicPaths.contains(path)) return false;

    return err.requestOptions.extra[_retriedKey] != true;
  }

  Future<bool> _refreshAccessToken() async {
    final accessToken = await _tokenStorage.readAccessToken();
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (accessToken == null || refreshToken == null) return false;

    try {
      final response = await _tokenDio.post<Map<String, dynamic>>(
        ApiPaths.refreshToken,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) return false;

      final newAccessToken = data['token'] as String?;
      if (newAccessToken == null) return false;

      await _tokenStorage.saveAccessToken(newAccessToken);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final accessToken = await _tokenStorage.readAccessToken();

    return _tokenDio.fetch<dynamic>(
      options
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..extra[_retriedKey] = true,
    );
  }
}
