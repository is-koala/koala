import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/device_identity.dart';

import '../../support/fake_api.dart';

/// `ApiClient.withDio` üretimdeki interceptor zincirini kuruyor mu.
///
/// Bu dosyanın varlık sebebi is-koala/koala#21: testlerdeki istemci hiçbir
/// interceptor taşımadığı için `Authorization` başlığı, `X-Device-Id`,
/// `401` sonrası yenileme ve sıraya alma davranışının **hiçbir** otomatik
/// kanıtı yoktu. Bir interceptor zincirden düşerse buradaki testler kırmızıya
/// dönmeli.
void main() {
  group('DeviceInterceptor', () {
    test('her isteğe X-Device-Id başlığını koyuyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 'tamam'},
        ),
        deviceIdentity: FakeDeviceIdentity(id: 'cihaz-42'),
      );

      await api.client.get<String>(
        ApiPaths.currentUser,
        parse: (data) => data! as String,
      );

      expect(
        api.requests.single.headers[DeviceIdentity.deviceIdHeader],
        'cihaz-42',
      );
    });

    test('oturum açılmamış public istekte de gidiyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 'tamam'},
        ),
      );

      await api.client.get<String>(
        ApiPaths.jobCategories,
        parse: (data) => data! as String,
      );

      expect(
        api.requests.single.headers[DeviceIdentity.deviceIdHeader],
        isNotNull,
      );
    });
  });

  group('AuthInterceptor başlığı', () {
    test('korumalı yola Authorization ekliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 'tamam'},
        ),
        tokenStorage: FakeTokenStorage(accessToken: 'erisim-1'),
      );

      await api.client.get<String>(
        ApiPaths.currentUser,
        parse: (data) => data! as String,
      );

      expect(api.requests.single.headers['Authorization'], 'Bearer erisim-1');
    });

    test('public yola Authorization eklemiyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 'tamam'},
        ),
        tokenStorage: FakeTokenStorage(accessToken: 'erisim-1'),
      );

      await api.client.get<String>(
        ApiPaths.login,
        parse: (data) => data! as String,
      );

      expect(api.requests.single.headers['Authorization'], isNull);
    });

    test('token yokken başlık hiç konmuyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 'tamam'},
        ),
      );

      await api.client.get<String>(
        ApiPaths.currentUser,
        parse: (data) => data! as String,
      );

      expect(api.requests.single.headers['Authorization'], isNull);
    });
  });

  group('AuthInterceptor yenileme', () {
    test('401 alan istek bir kez yenilenip tekrar deneniyor', () async {
      final sentTokens = <String, List<String?>>{};
      var businessCalls = 0;

      final api = FakeApi(
        handler: (options) {
          (sentTokens[options.path] ??= []).add(
            options.headers['Authorization'] as String?,
          );

          if (options.path == ApiPaths.refreshToken) {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'token': 'tazelenmis-erisim'},
              },
            );
          }

          businessCalls++;
          if (businessCalls == 1) {
            return const FakeApiResponse(
              statusCode: 401,
              body: {'success': false, 'message': 'Oturum bulunamadı'},
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': 'tamam'},
          );
        },
        tokenStorage: FakeTokenStorage(
          accessToken: 'suresi-dolmus',
          refreshToken: 'gecerli-yenileme',
        ),
      );

      final result = await api.client.get<String>(
        ApiPaths.currentUser,
        parse: (data) => data! as String,
      );

      expect(result, 'tamam');
      expect(api.sessionExpired, isFalse);
      expect(api.requests.map((request) => request.path), [
        ApiPaths.currentUser,
        ApiPaths.refreshToken,
        ApiPaths.currentUser,
      ]);
      // Yenileme, süresi dolmuş erişim token'ını taşımak zorunda: backend
      // oturum kimliğini onun claim'lerinden okuyor.
      expect(sentTokens[ApiPaths.refreshToken], ['Bearer suresi-dolmus']);
      expect(sentTokens[ApiPaths.currentUser], [
        'Bearer suresi-dolmus',
        'Bearer tazelenmis-erisim',
      ]);
      expect(
        (api.tokenStorage as FakeTokenStorage).accessToken,
        'tazelenmis-erisim',
      );
    });

    test('yenileme başarısızsa oturum sonlandırılıyor', () async {
      final api = FakeApi(
        handler: (options) {
          if (options.path == ApiPaths.refreshToken) {
            return const FakeApiResponse(
              statusCode: 401,
              body: {'success': false, 'message': 'Yenileme reddedildi'},
            );
          }
          return const FakeApiResponse(
            statusCode: 401,
            body: {'success': false, 'message': 'Oturum bulunamadı'},
          );
        },
        tokenStorage: FakeTokenStorage(
          accessToken: 'suresi-dolmus',
          refreshToken: 'gecersiz-yenileme',
        ),
      );

      await expectLater(
        api.client.get<String>(
          ApiPaths.currentUser,
          parse: (data) => data! as String,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unauthorized,
          ),
        ),
      );

      expect(api.sessionExpired, isTrue);
      // Tekrar denenmiyor: yenileme olmadan aynı 401'e gidilirdi.
      expect(api.requests.map((request) => request.path), [
        ApiPaths.currentUser,
        ApiPaths.refreshToken,
      ]);
    });

    test('aynı anda 401 alan iki isteğin yenilemesi sıraya giriyor', () async {
      final unauthorized = <String>{};
      final sent = <String>[];

      final api = FakeApi(
        handler: (options) async {
          sent.add(options.path);

          if (options.path == ApiPaths.refreshToken) {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'token': 'tazelenmis-erisim'},
              },
            );
          }

          // Her iş isteği yalnızca ilk denemesinde 401 alıyor.
          if (unauthorized.add(options.path)) {
            return const FakeApiResponse(
              statusCode: 401,
              body: {'success': false, 'message': 'Oturum bulunamadı'},
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': 'tamam'},
          );
        },
        tokenStorage: FakeTokenStorage(
          accessToken: 'suresi-dolmus',
          refreshToken: 'gecerli-yenileme',
        ),
      );

      final client = api.client;
      final results = await Future.wait([
        client.get<String>(
          ApiPaths.currentUser,
          parse: (data) => data! as String,
        ),
        client.get<String>(
          ApiPaths.currentUserSessions,
          parse: (data) => data! as String,
        ),
      ]);

      expect(results, ['tamam', 'tamam']);
      expect(api.sessionExpired, isFalse);

      // `QueuedInterceptor` yalnızca **sıraya alıyor**: ikinci isteğin 401'i,
      // birincisinin yenileme + tekrar deneme çifti bitmeden ele alınmıyor.
      // Yenilemeyi paylaştırmıyor — ikinci istek de kendi yenilemesini
      // yapıyor, çünkü `AuthInterceptor` isteğin taşıdığı token'ın bu arada
      // tazelenip tazelenmediğine bakmıyor. Davranış bugün budur; ikinci
      // yenilemeyi gereksiz kılmak ayrı bir iş.
      expect(sent, [
        ApiPaths.currentUser,
        ApiPaths.currentUserSessions,
        ApiPaths.refreshToken,
        ApiPaths.currentUser,
        ApiPaths.refreshToken,
        ApiPaths.currentUserSessions,
      ]);
    });
  });

  group('multipart tekrar denemesi', () {
    test(
      'FormData taşıyan istek tekrar denendiğinde gövdesini koruyor',
      () async {
        var businessCalls = 0;

        final api = FakeApi(
          handler: (options) {
            if (options.path == ApiPaths.refreshToken) {
              return const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'token': 'tazelenmis-erisim'},
                },
              );
            }

            businessCalls++;
            if (businessCalls == 1) {
              return const FakeApiResponse(
                statusCode: 401,
                body: {'success': false, 'message': 'Oturum bulunamadı'},
              );
            }
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': 'tamam'},
            );
          },
          tokenStorage: FakeTokenStorage(
            accessToken: 'suresi-dolmus',
            refreshToken: 'gecerli-yenileme',
          ),
        );

        final result = await api.client.postMultipartJson<String>(
          ApiPaths.companies,
          jsonFieldName: 'company',
          jsonBody: const {'name': 'Koala'},
          parse: (data) => data! as String,
        );

        expect(result, 'tamam');
        expect(api.requests, hasLength(3));
        expect(api.requests.last.data, isA<FormData>());
        expect(
          api.requests.last.headers[Headers.contentTypeHeader],
          startsWith(Headers.multipartFormDataContentType),
        );
      },
    );
  });
}
