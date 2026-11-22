import 'package:dio/dio.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/api_response.dart';
import 'package:koala/product/network/token_storage.dart';

/// İsteklere `Authorization` ekler; oturumun bittiğini söyleyen isteği bir kez
/// `/auth/refresh-token` ile tazeleyip tekrar dener.
///
/// `QueuedInterceptor`: aynı anda oturum hatası alan istekler için token bir
/// kez yenilensin. Yenileme süresi **dolmuş** token'la da çalışıyor (backend
/// oturumu onun claim'lerinden okuyor), o yüzden yol [ApiPaths.publicPaths]
/// içinde değil.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this._tokenStorage,
    required this._tokenDio,
    required this._onSessionExpired,
  });

  final TokenStorage _tokenStorage;

  /// Kendi interceptor'ına takılıp döngüye girmesin diye ayrı istemci.
  final Dio _tokenDio;

  final Future<void> Function() _onSessionExpired;

  static const String _retriedKey = 'koala_retried';

  static const String _accessTokenGenerationKey =
      'koala_access_token_generation';

  _AccessTokenGeneration? _currentGeneration;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!ApiPaths.publicPaths.contains(options.path)) {
      final accessToken = await _tokenStorage.readAccessToken();
      if (accessToken != null) {
        final currentGeneration = _currentGeneration;
        final generation = currentGeneration?.accessToken == accessToken
            ? currentGeneration!
            : _AccessTokenGeneration(accessToken);
        _currentGeneration = generation;
        options.extra[_accessTokenGenerationKey] = generation;
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

    final generation =
        err.requestOptions.extra[_accessTokenGenerationKey]
            as _AccessTokenGeneration?;
    if (generation == null) {
      await _onSessionExpired();
      handler.next(err);
      return;
    }

    // Aynı nesli taşıyan istekler tamamlanmış sonucu paylaşır. Bu arada başka
    // hesaba geçildiyse eski istek o hesabın token'ıyla oynatılmasın.
    final existingAttempt = generation.refreshAttempt;
    if (existingAttempt == null &&
        await _tokenStorage.readAccessToken() != generation.accessToken) {
      handler.next(err);
      return;
    }

    final refreshedAccessToken = await (generation.refreshAttempt ??=
        _refreshGeneration(generation));
    if (refreshedAccessToken == null ||
        await _tokenStorage.readAccessToken() != refreshedAccessToken) {
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _retry(err.requestOptions, refreshedAccessToken));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Hatanın oturumun bittiği anlamına gelip gelmediği. Ölçü kategori; `401`
  /// yalnız yedek (is-koala/koala#86). Karar `ApiClient`'takiyle aynı
  /// fonksiyondan çıkmalı, yoksa yenileme ile gösterilen tip ayrışır.
  bool _shouldRefresh(DioException err) {
    final type = ApiErrorType.classify(
      errorCategory: ApiResponse.errorCategoryOf(err.response?.data),
      statusCode: err.response?.statusCode,
    );
    if (type != ApiErrorType.unauthenticated) return false;

    final path = err.requestOptions.path;
    if (path == ApiPaths.refreshToken) return false;
    if (ApiPaths.publicPaths.contains(path)) return false;

    return err.requestOptions.extra[_retriedKey] != true;
  }

  /// Aynı token'la gönderilmiş isteklerin paylaştığı yenileme; başarısızlık
  /// kohort başına bir kez çıkışa düşürür.
  Future<String?> _refreshGeneration(_AccessTokenGeneration generation) async {
    try {
      final refreshedAccessToken = await _refreshAccessToken(
        generation.accessToken,
      );
      if (refreshedAccessToken == null &&
          await _tokenStorage.readAccessToken() == generation.accessToken) {
        await _onSessionExpired();
      }
      return refreshedAccessToken;
    } finally {
      // Yenilemeden sonra çıkan istekler yeni hücre alır; kalıcı bir
      // token→future haritası gerekmez.
      if (identical(_currentGeneration, generation)) {
        _currentGeneration = null;
      }
    }
  }

  Future<String?> _refreshAccessToken(String expectedAccessToken) async {
    final accessToken = await _tokenStorage.readAccessToken();
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (accessToken != expectedAccessToken || refreshToken == null) return null;

    try {
      final response = await _tokenDio.post<Map<String, dynamic>>(
        ApiPaths.refreshToken,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) return null;

      final newAccessToken = data['token'] as String?;
      if (newAccessToken == null) return null;

      // Yenileme sürerken hesap değiştiyse yeni oturumun token'ını ezme.
      if (await _tokenStorage.readAccessToken() != expectedAccessToken) {
        return null;
      }

      await _tokenStorage.saveAccessToken(newAccessToken);
      return newAccessToken;
    } on DioException {
      return null;
    }
  }

  /// İsteği tazelenmiş token'la bir kez daha gönderir. `FormData` tek
  /// kullanımlık ("already been finalized"); `clone()` ile dosya yükleyen istek
  /// de tekrar denenebiliyor.
  Future<Response<dynamic>> _retry(
    RequestOptions options,
    String accessToken,
  ) async {
    final body = options.data;
    if (body is FormData) {
      options.data = body.clone();
    }

    return _tokenDio.fetch<dynamic>(
      options
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..extra[_retriedKey] = true,
    );
  }
}

/// Aynı token'la çıkan isteklerin yenileme sonucu. `RequestOptions.extra`da
/// taşındığı için istekler yaşadıkça kalır, büyüyen bir önbellek olmaz.
class _AccessTokenGeneration {
  _AccessTokenGeneration(this.accessToken);

  final String accessToken;
  Future<String?>? refreshAttempt;
}
