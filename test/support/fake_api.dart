import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/device_hints.dart';
import 'package:koala/product/network/device_identity.dart';
import 'package:koala/product/network/token_storage.dart';

/// Gerçek soket açmayan sahte HTTP katmanı. İstemci **üretimdeki interceptor
/// zincirini** taşıyor (#21); Keychain ve `SharedPreferences` bellekte.
class FakeApi {
  FakeApi({
    required this.handler,
    TokenStorage? tokenStorage,
    DeviceIdentity? deviceIdentity,
    this.deviceHints,
  }) : tokenStorage = tokenStorage ?? FakeTokenStorage(),
       deviceIdentity = deviceIdentity ?? FakeDeviceIdentity();

  final FutureOr<FakeApiResponse> Function(RequestOptions options) handler;

  /// Yenileme sonrası saklanan token buradan görülüyor.
  final TokenStorage tokenStorage;

  final DeviceIdentity deviceIdentity;

  /// Verilmezse test makinesinin değerleri gider.
  final DeviceHints? deviceHints;

  final List<RequestOptions> requests = [];

  final Map<int, Completer<void>> _arrivals = {};

  /// Eşzamanlı hataların tek sonucu paylaştığını ölçmek için sayaç.
  int sessionExpirationCount = 0;

  bool get sessionExpired => sessionExpirationCount > 0;

  /// İstek sayısı [count] olana kadar bekler. Uçuştaki isteği beklemenin **tek
  /// doğru** yolu: `Future.delayed` yüklü makinede yetmiyor (#88). İstek
  /// adaptöre ulaşınca tamamlanır; sayı zaten [count] ise hemen döner.
  Future<void> requestsReach(int count) {
    if (requests.length >= count) return Future<void>.value();
    return (_arrivals[count] ??= Completer<void>()).future;
  }

  void _recordRequest(RequestOptions options) {
    requests.add(options);
    for (final entry in _arrivals.entries) {
      if (requests.length >= entry.key && !entry.value.isCompleted) {
        entry.value.complete();
      }
    }
  }

  ApiClient get client {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = _FakeAdapter(this);

    return ApiClient.withDio(
      dio,
      tokenStorage: tokenStorage,
      deviceIdentity: deviceIdentity,
      deviceHints: deviceHints,
      onSessionExpired: () async => sessionExpirationCount++,
    );
  }
}

/// Bellekteki token deposu; gerçek saklamayı sınayan testler
/// `TokenStorage.withStorage` kullanıyor.
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

class FakeDeviceIdentity implements DeviceIdentity {
  FakeDeviceIdentity({this.id = 'test-device-id'});

  final String id;

  @override
  Future<String> deviceId() async => id;
}

class FakeApiResponse {
  const FakeApiResponse({
    required this.statusCode,
    this.body,
    this.headers = const {},
  }) : rawBody = null;

  const FakeApiResponse.raw({required this.statusCode, required String body})
    : body = null,
      headers = const {},
      rawBody = body;

  const FakeApiResponse.connectionError()
    : statusCode = -1,
      body = null,
      headers = const {},
      rawBody = null;

  /// Zaman aşımı; bağlantı hatasından farklı `DioExceptionType` üretiyor. Zarf
  /// taşımadığı için kategorisi yok.
  const FakeApiResponse.timeout()
    : statusCode = -2,
      body = null,
      headers = const {},
      rawBody = null;

  final int statusCode;
  final Map<String, dynamic>? body;

  final Map<String, String> headers;

  final String? rawBody;

  bool get isConnectionError => statusCode == -1;

  bool get isTimeout => statusCode == -2;
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

    if (response.isTimeout) {
      throw DioException.receiveTimeout(
        timeout: const Duration(milliseconds: 1),
        requestOptions: options,
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
        for (final entry in response.headers.entries) entry.key: [entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
