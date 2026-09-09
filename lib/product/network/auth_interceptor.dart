import 'package:dio/dio.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/api_response.dart';
import 'package:koala/product/network/token_storage.dart';

/// İsteklere `Authorization` başlığını ekler ve oturumun bittiğini söyleyen
/// isteği bir kez `/auth/refresh-token` ile tazeleyip tekrar dener.
///
/// "Oturum bitti" ölçüsü [ApiErrorType.unauthenticated]: karar zarftaki
/// `errorCategory` alanından çıkıyor, `401` yalnızca yedek — ayrıntı
/// [_shouldRefresh]'te.
///
/// `QueuedInterceptor`'dan türüyor: aynı anda oturum hatası alan birden fazla
/// istek olduğunda token yalnızca bir defa yenilensin diye istekler sıraya
/// giriyor.
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

  /// İsteğin çıktığı erişim-token neslini taşıyan anahtar.
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

    // `QueuedInterceptor` ikinci 401'i ilk yenileme bittikten sonra ele alsa
    // bile iki istek aynı nesli taşıdığı için tamamlanmış sonucu paylaşır.
    // Logout/login sırasında storage başka bir hesaba geçtiyse eski isteği o
    // hesabın token'ıyla yeniden oynatmamak için yeni bir yenileme başlatma.
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
      handler.resolve(await _retry(err.requestOptions));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Bu hatanın oturumun bitmesi anlamına gelip gelmediğine karar verir.
  ///
  /// Ölçü **kategori**, durum kodu değil: sunucu `TOKEN_EXPIRED`'ı bir gün
  /// `401` dışında bir durum koduyla gönderirse yenileme sessizce çalışmaz
  /// hâle gelirdi (is-koala/koala#86). Ayrım `ApiErrorType`'ta zaten vardı
  /// ama oturumu yenileyen yol onu hiç okumuyordu; tip ile davranış
  /// arasındaki bağ yalnızca "sunucu bu kategorileri `401` ile gönderiyor"
  /// varsayımıyla ayakta duruyordu.
  ///
  /// `401` **yedek olarak duruyor**, birincil kapı olarak değil:
  /// [ApiErrorType.classify] kategori taşımayan zarfta durum koduna düşüyor,
  /// yani eski sunucu, zarfı elle yazan filtreler, gövdesi JSON olmayan
  /// yanıtlar ve yanıtsız ağ hataları bugünkü davranışı koruyor.
  ///
  /// Kararın `ApiClient`'takiyle aynı fonksiyondan çıkması şart: iki kopya,
  /// aynı yanıt için yenileme yolunun ve kullanıcıya gösterilen tipin
  /// sessizce ayrışması demek olurdu.
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

  /// Aynı erişim token'ıyla gönderilmiş isteklerin paylaştığı yenileme.
  /// Oturum sonlandırma da bu future'ın içinde olduğundan başarısız bir
  /// yenileme, kohort başına yalnız bir kez çıkışa düşürür.
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
      // Yenileme tamamlandıktan sonra çıkacak yeni istekler yeni bir hücre
      // alır. Eski istekler kendi hücresindeki tamamlanmış sonucu paylaşmayı
      // sürdürür; kalıcı token->future haritası gerekmez.
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

      // Yenileme uçuş hâlindeyken logout/login olduysa eski oturumun
      // yanıtıyla yeni oturumun token'ını ezme.
      if (await _tokenStorage.readAccessToken() != expectedAccessToken) {
        return null;
      }

      await _tokenStorage.saveAccessToken(newAccessToken);
      return newAccessToken;
    } on DioException {
      return null;
    }
  }

  /// İsteği tazelenmiş token'la bir kez daha gönderir.
  ///
  /// Multipart gövde tek kullanımlık: `FormData` ilk gönderimde akışa
  /// dönüştürülüp mühürleniyor, aynı nesne ikinci kez gönderilince dio
  /// "The FormData has already been finalized" diye düşüyor. Yani dosya
  /// yükleyen bir istek, yükleme sırasında erişim token'ı dolduğunda hiç
  /// tekrar denenemiyordu. `clone()` parçaları yeniden okunabilir biçimde
  /// kopyaladığı için tekrar denenen istek dosyayı yine taşıyor — kopyalamak
  /// yerine `FormData`'yı burada yeniden kurmak, isteği kimin kurduğunu
  /// bilmeyi gerektirirdi.
  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final accessToken = await _tokenStorage.readAccessToken();

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

/// Aynı access token'la çıkan isteklerin yenileme sonucu.
///
/// Hücre doğrudan `RequestOptions.extra`da taşındığı için yalnız ilgili
/// istekler yaşadığı sürece kalır; token değerlerine göre büyüyen bir cache
/// oluşturmaz.
class _AccessTokenGeneration {
  _AccessTokenGeneration(this.accessToken);

  final String accessToken;
  Future<String?>? refreshAttempt;
}
