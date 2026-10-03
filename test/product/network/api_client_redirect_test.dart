import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../support/fake_api.dart';

const _path = '/disputes/d-1/evidence/e-1/download';

ApiClient _clientOn(FakeApi api) => api.client;

FakeApiResponse _redirectTo(String location) =>
    FakeApiResponse(statusCode: 302, headers: {'location': location});

void main() {
  group('getRedirectLocation: hedef şeması', () {
    test('https adresi verilir', () async {
      final api = FakeApi(
        handler: (_) => _redirectTo('https://depo.example/k?imza=1'),
      );

      final url = await _clientOn(api).getRedirectLocation(_path);

      expect(url, Uri.parse('https://depo.example/k?imza=1'));
    });

    // Bu adres `launchUrl`'e gidiyor: şifresiz `http`, `intent:` ve `file:`
    // harici uygulamaya sızmamalı.
    test('http, intent, file ve host\'suz adresler reddedilir', () async {
      for (final location in [
        'http://depo.example/k',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///etc/passwd',
        'javascript:alert(1)',
        '/uploads/files/x',
        'https:///yalniz-yol',
      ]) {
        final api = FakeApi(handler: (_) => _redirectTo(location));

        await expectLater(
          _clientOn(api).getRedirectLocation(_path),
          throwsA(isA<ApiException>()),
          reason: location,
        );
      }
    });

    test('dev ortamında http de kabul edilir', () async {
      final api = FakeApi(
        handler: (_) => _redirectTo('http://10.0.2.2:9000/k'),
      );

      final url = await _clientOn(api).getRedirectLocation(
        _path,
        allowedSchemes: ApiConfig.resolveExternalUrlSchemes(flavor: 'dev'),
      );

      expect(url, Uri.parse('http://10.0.2.2:9000/k'));
    });

    test('ApiConfig: http yalnız dev, bilinmeyen ortam kapalı', () {
      expect(ApiConfig.resolveExternalUrlSchemes(flavor: 'dev'), {
        'https',
        'http',
      });
      expect(ApiConfig.resolveExternalUrlSchemes(flavor: 'staging'), {'https'});
      expect(ApiConfig.resolveExternalUrlSchemes(flavor: 'production'), {
        'https',
      });
      expect(ApiConfig.resolveExternalUrlSchemes(flavor: null), {'https'});
      // Testler staging ile koşuyor: üretimdeki varsayılan da yalnız https.
      expect(ApiConfig.externalUrlSchemes, {'https'});
    });
  });

  group('getRedirectLocation: hata gövdesi akıştan okunur', () {
    test('zarflı 404 tür ve kodla çıkar', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Kanıt dosyası bulunamadı.',
            'errorCode': 'DISPUTE_EVIDENCE_NOT_FOUND',
            'errorCategory': 'RESOURCE_NOT_FOUND',
          },
        ),
      );

      await expectLater(
        _clientOn(api).getRedirectLocation(_path),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.notFound)
              .having(
                (e) => e.errorCode,
                'errorCode',
                'DISPUTE_EVIDENCE_NOT_FOUND',
              )
              .having((e) => e.message, 'message', 'Kanıt dosyası bulunamadı.'),
        ),
      );
    });

    test('JSON olmayan hata gövdesi durum koduna düşer', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse.raw(
          statusCode: 502,
          body: '<html>Bad Gateway</html>',
        ),
      );

      await expectLater(
        _clientOn(api).getRedirectLocation(_path),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.server)
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    });

    test(
      'aşırı büyük hata gövdesi okunmaz, karar durum koduna kalır',
      () async {
        final api = FakeApi(
          handler: (_) => FakeApiResponse.raw(
            statusCode: 403,
            body: '{"message":"${'x' * (80 * 1024)}"}',
          ),
        );

        await expectLater(
          _clientOn(api).getRedirectLocation(_path),
          throwsA(
            isA<ApiException>().having(
              (e) => e.type,
              'type',
              ApiErrorType.forbidden,
            ),
          ),
        );
      },
    );
  });

  // Gerçek soketlerle: sahte katman yönlendirmeyi hiç izleyemez ve gövdenin
  // belleğe alınıp alınmadığını gösteremez.
  group('getRedirectLocation: gerçek HTTP', () {
    late HttpServer api;
    late HttpServer storage;
    late List<HttpRequest> apiRequests;
    late List<HttpRequest> storageRequests;
    late Completer<void> releaseBody;
    var apiHandler = (HttpRequest request) async {};

    setUp(() async {
      apiRequests = [];
      storageRequests = [];
      releaseBody = Completer<void>();
      api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      storage = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      api.listen((request) async {
        apiRequests.add(request);
        await apiHandler(request);
      });
      storage.listen((request) async {
        storageRequests.add(request);
        request.response.write('depo');
        await request.response.close();
      });
    });

    tearDown(() async {
      if (!releaseBody.isCompleted) releaseBody.complete();
      await api.close(force: true);
      await storage.close(force: true);
    });

    ApiClient clientForApi() {
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${api.port}'));
      return ApiClient.withDio(
        dio,
        tokenStorage: FakeTokenStorage(accessToken: 'erisim-token'),
        deviceIdentity: FakeDeviceIdentity(),
        onSessionExpired: () async {},
      );
    }

    test(
      '302 izlenmez: depoya hiç gidilmez, token yalnız API\'ye gider',
      () async {
        apiHandler = (request) async {
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set(
              HttpHeaders.locationHeader,
              'http://127.0.0.1:${storage.port}/nesne?imza=1',
            );
          await request.response.close();
        };

        final url = await clientForApi().getRedirectLocation(
          _path,
          allowedSchemes: const {'http'},
        );

        expect(url, Uri.parse('http://127.0.0.1:${storage.port}/nesne?imza=1'));
        expect(apiRequests, hasLength(1));
        expect(
          apiRequests.single.headers.value(HttpHeaders.authorizationHeader),
          'Bearer erisim-token',
        );
        // Yönlendirme izlenseydi ikinci sunucu bu isteği ve başlığı alırdı.
        expect(storageRequests, isEmpty);
      },
    );

    test('200 akışı belleğe alınmaz: başlıklar gelince dönülür', () async {
      apiHandler = (request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.binary
          ..add(List<int>.filled(64 * 1024, 7));
        await request.response.flush();
        // Gövdenin geri kalanı hiç gelmiyor: bütünüyle okumaya kalkan bir
        // istemci burada takılır.
        await releaseBody.future;
        await request.response.close();
      };

      final url = await clientForApi()
          .getRedirectLocation(_path, allowedSchemes: const {'http'})
          .timeout(const Duration(seconds: 5));

      expect(url, isNull);
    });

    test('zarflı 404 gerçek bağlantıda da ApiException olur', () async {
      apiHandler = (request) async {
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'success': false,
              'message': 'Kanıt dosyası bulunamadı.',
              'errorCode': 'DISPUTE_EVIDENCE_NOT_FOUND',
              'errorCategory': 'RESOURCE_NOT_FOUND',
            }),
          );
        await request.response.close();
      };

      await expectLater(
        clientForApi().getRedirectLocation(_path),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.notFound)
              .having(
                (e) => e.errorCode,
                'errorCode',
                'DISPUTE_EVIDENCE_NOT_FOUND',
              ),
        ),
      );
    });
  });
}
