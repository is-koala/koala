import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/device_identity.dart';
import 'package:koala/product/network/token_storage.dart';

/// Ağ katmanı testleri için sahte HTTP katmanı.
///
/// Gerçek soket açmadan, isteğe karşılık verilecek yanıtı testin kendisi
/// belirliyor. Yakalanan istekler [FakeApi.requests] listesinde birikiyor;
/// böylece hangi yola, hangi gövdeyle gidildiği de doğrulanabiliyor.
///
/// Ürettiği istemci **üretimdeki interceptor zincirini** taşıyor: token
/// başlığı, cihaz başlığı ve `401` sonrası yenileme testlerde de çalışıyor
/// (is-koala/koala#21). Bunların dayandığı iki bağımlılık — Keychain ve
/// `SharedPreferences` — testte platform kanalına gitmesin diye bellekteki
/// [FakeTokenStorage] ve [FakeDeviceIdentity] ile karşılanıyor.
class FakeApi {
  FakeApi({
    required this.handler,
    TokenStorage? tokenStorage,
    DeviceIdentity? deviceIdentity,
  }) : tokenStorage = tokenStorage ?? FakeTokenStorage(),
       deviceIdentity = deviceIdentity ?? FakeDeviceIdentity();

  /// Gelen isteğe karşılık dönülecek sahte yanıtı üretir.
  final FutureOr<FakeApiResponse> Function(RequestOptions options) handler;

  /// İstemcinin token'ları okuyup yazdığı depo. Testin kendisi de okuyabilir:
  /// yenileme sonrası yeni erişim token'ının saklandığı buradan görülüyor.
  final TokenStorage tokenStorage;

  final DeviceIdentity deviceIdentity;

  /// Sahte sunucuya ulaşan istekler, sırayla.
  final List<RequestOptions> requests = [];

  /// Beklenen istek sayısına göre bekleyenler; anahtar eşiğin kendisi.
  final Map<int, Completer<void>> _arrivals = {};

  /// Oturum sonlandırma çağrıldı mı: yenileme başarısız olduğunda
  /// `AuthInterceptor` bunu tetikliyor.
  bool sessionExpired = false;

  /// Sahte katmana ulaşan istek sayısı [count] olana kadar bekler.
  ///
  /// Uçuştaki bir isteğin araya girmesini beklemenin **tek doğru** yolu bu:
  /// `Future.delayed` ile duvar saatinden pay biçmek yüklü bir makinede
  /// sessizce yetmiyor ve iddia, üretim kodu doğruyken kırmızıya dönüyor
  /// (is-koala/koala#88). İstek üretimdeki interceptor zincirinden geçtiği
  /// için beş olay-döngüsü turu istiyor; kaç milisaniye sürdüğü makinenin o
  /// anki yüküne bağlı, yani tahmin edilemez. Burada beklenen olayın
  /// kendisi: istek adaptöre ulaştığı anda bu `Future` tamamlanıyor.
  ///
  /// Sayı çağrı anında zaten [count] ise beklemeden döner.
  Future<void> requestsReach(int count) {
    if (requests.length >= count) return Future<void>.value();
    return (_arrivals[count] ??= Completer<void>()).future;
  }

  /// Adaptörün isteği kaydettiği tek yer; bekleyenler buradan uyandırılıyor.
  void _recordRequest(RequestOptions options) {
    requests.add(options);
    for (final entry in _arrivals.entries) {
      if (requests.length >= entry.key && !entry.value.isCompleted) {
        entry.value.complete();
      }
    }
  }

  /// Testte kullanılacak, sahte katmana bağlı istemci.
  ApiClient get client {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = _FakeAdapter(this);

    return ApiClient.withDio(
      dio,
      tokenStorage: tokenStorage,
      deviceIdentity: deviceIdentity,
      onSessionExpired: () async => sessionExpired = true,
    );
  }
}

/// Bellekte duran token deposu.
///
/// `TokenStorage`'ın kendisi Keychain'e gidiyor; testte platform kanalı yok.
/// Gerçek saklama davranışını sınayan testler `TokenStorage.withStorage` ile
/// sahte güvenli depoyu kullanmayı sürdürüyor.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({
    this.accessToken,
    this.refreshToken,
    this.refreshExpiresAt,
  });

  String? accessToken;
  String? refreshToken;
  DateTime? refreshExpiresAt;

  @override
  String get apiOrigin => 'https://test.local';

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<DateTime?> readRefreshExpiresAt() async => refreshExpiresAt;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    DateTime? refreshExpiresAt,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.refreshExpiresAt = refreshExpiresAt;
  }

  @override
  Future<void> saveAccessToken(String accessToken) async {
    this.accessToken = accessToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    refreshExpiresAt = null;
  }
}

/// Sabit cihaz kimliği; gerçeği `SharedPreferences`'a gidiyor.
class FakeDeviceIdentity implements DeviceIdentity {
  FakeDeviceIdentity({this.id = 'test-device-id'});

  final String id;

  @override
  Future<String> deviceId() async => id;
}

/// Sahte sunucunun döndüreceği yanıt.
class FakeApiResponse {
  const FakeApiResponse({required this.statusCode, this.body}) : rawBody = null;

  /// JSON olmayan gövde döndüren yanıt (ör. bir hata sayfası).
  const FakeApiResponse.raw({required this.statusCode, required String body})
    : body = null,
      rawBody = body;

  /// Ağa hiç çıkılamamış gibi davranan yanıt (bağlantı hatası).
  const FakeApiResponse.connectionError()
    : statusCode = -1,
      body = null,
      rawBody = null;

  final int statusCode;
  final Map<String, dynamic>? body;

  /// Doluysa gövde JSON'a çevrilmeden olduğu gibi gönderilir.
  final String? rawBody;

  bool get isConnectionError => statusCode == -1;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._fakeApi);

  final FakeApi _fakeApi;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _fakeApi._recordRequest(options);

    final response = await _fakeApi.handler(options);

    if (response.isConnectionError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'test',
      );
    }

    final rawBody = response.rawBody;
    if (rawBody != null) {
      return ResponseBody.fromString(
        rawBody,
        response.statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.textPlainContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(response.body ?? const <String, dynamic>{}),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
