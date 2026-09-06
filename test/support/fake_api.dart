import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:koala/product/network/api_client.dart';

/// Ağ katmanı testleri için sahte HTTP katmanı.
///
/// Gerçek soket açmadan, isteğe karşılık verilecek yanıtı testin kendisi
/// belirliyor. Yakalanan istekler [FakeApi.requests] listesinde birikiyor;
/// böylece hangi yola, hangi gövdeyle gidildiği de doğrulanabiliyor.
class FakeApi {
  FakeApi({required this.handler});

  /// Gelen isteğe karşılık dönülecek sahte yanıtı üretir.
  final FutureOr<FakeApiResponse> Function(RequestOptions options) handler;

  /// Sahte sunucuya ulaşan istekler, sırayla.
  final List<RequestOptions> requests = [];

  /// Testte kullanılacak, sahte katmana bağlı istemci.
  ApiClient get client {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = _FakeAdapter(this);
    return ApiClient.withDio(dio);
  }
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
    _fakeApi.requests.add(options);

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
