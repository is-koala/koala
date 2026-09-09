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

    // Issue'nun asıl bulgusu: yenileme kararı yalnızca `401` durum koduna
    // bağlıyken `unauthenticated` tipinin **hiçbir okuyucusu yoktu**. Ayrım
    // `ApiErrorType`'ta vardı ama oturumu yenileyen yol onu hiç okumuyordu;
    // bağ yalnızca "sunucu bu kategorileri `401` ile gönderiyor" varsayımıyla
    // ayakta duruyordu (is-koala/koala#86).
    //
    // Aşağıdaki iki durum kodu bilerek `401` **değil**: karar kategoriden
    // gelmiyorsa hiçbiri yenilemez.
    for (final (statusCode, category) in const [
      // Durum kodu kategoriyle **çelişiyor**: `403`'ün yedeği `forbidden`,
      // yani karar durum kodundan çıksa yenileme hiç denenmezdi.
      (403, 'TOKEN_EXPIRED'),
      // Tablonun hiç tanımadığı bir kod: yedek `unknown`'a düşüyor, yani bu
      // satırın yeşil kalmasının tek yolu kategoriyi okumak.
      (440, 'AUTHENTICATION_REQUIRED'),
    ]) {
      test('$statusCode + $category yenilemeyi tetikliyor', () async {
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
              return FakeApiResponse(
                statusCode: statusCode,
                body: {
                  'success': false,
                  'message': 'Oturum süresi doldu.',
                  'errorCategory': category,
                },
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
      });
    }

    // Ayrımın ters yönü. Yukarıdaki iki test tek başına "kategori **ya da**
    // `401`" kuralıyla da yeşil kalırdı; bu test kategorinin gerçekten
    // birincil kapı olduğunu ölçüyor: `401` geliyor ama kategori oturumun
    // bittiğini söylemiyor, yani yenilemenin çözeceği bir şey yok.
    test('401 + ACCESS_DENIED yenileme denemiyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 401,
          body: {
            'success': false,
            'message': 'Bu işlem için yetkin yok.',
            'errorCategory': 'ACCESS_DENIED',
          },
        ),
        tokenStorage: FakeTokenStorage(
          accessToken: 'gecerli',
          refreshToken: 'gecerli-yenileme',
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
            ApiErrorType.forbidden,
          ),
        ),
      );

      expect(api.sessionExpired, isFalse);
      expect(api.requests.map((request) => request.path), [
        ApiPaths.currentUser,
      ]);
    });

    // `401` **yedek** olarak duruyor: zarf kategori taşımıyorsa bugünkü
    // davranış korunmalı. Gövdesi JSON olmayan bir hata sayfasında
    // ayrıştırılacak kategori yok, karar durum koduna düşüyor.
    test('kategorisiz 401 hata sayfasında yenileme sürüyor', () async {
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
            return const FakeApiResponse.raw(
              statusCode: 401,
              body: '<html><body>Unauthorized</body></html>',
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
      expect(api.requests.map((request) => request.path), [
        ApiPaths.currentUser,
        ApiPaths.refreshToken,
        ApiPaths.currentUser,
      ]);
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
            ApiErrorType.unauthenticated,
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

    // Yukarıdaki testin kategori yolundaki karşılığı, ve eksik olan buydu.
    // O test kategorisiz bir `401` kullanıyor, yani yalnız durum kodu
    // yedeğini ölçüyor: `_shouldRefresh` eski hâline (`statusCode == 401`)
    // döndürülse bile yeşil kalır. Yenilemenin **kategoriden** başladığı
    // yolda başarısızlığın kullanıcıyı gerçekten çıkışa düşürdüğünü ölçen
    // tek yer burası — yenilemeyi denemek ile onu tamamlamak ayrı şeyler ve
    // ikincisi ölçülmemişse `sessionExpired` sessizce ölü kalabilirdi.
    test('403 + TOKEN_EXPIRED yenilenemezse oturum sonlandırılıyor', () async {
      final api = FakeApi(
        handler: (options) {
          if (options.path == ApiPaths.refreshToken) {
            return const FakeApiResponse(
              statusCode: 401,
              body: {'success': false, 'message': 'Yenileme reddedildi'},
            );
          }
          return const FakeApiResponse(
            statusCode: 403,
            body: {
              'success': false,
              'message': 'Oturum süresi doldu.',
              'errorCategory': 'TOKEN_EXPIRED',
            },
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
            // Durum kodu `403`, tip `unauthenticated`: çağırana ulaşan hata
            // da kategoriden çıkıyor, yenileme kararıyla aynı yerden.
            ApiErrorType.unauthenticated,
          ),
        ),
      );

      expect(api.sessionExpired, isTrue);
      expect(api.requests.map((request) => request.path), [
        ApiPaths.currentUser,
        ApiPaths.refreshToken,
      ]);
    });

    test('aynı anda 401 alan iki istek tek yenilemeyi paylaşıyor', () async {
      final unauthorized = <String>{};
      final sent = <String>[];
      final sentTokens = <String, List<String?>>{};

      late final FakeApi api;
      api = FakeApi(
        handler: (options) async {
          sent.add(options.path);
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

          // Her iş isteği yalnızca ilk denemesinde 401 alıyor.
          if (unauthorized.add(options.path)) {
            // İki eski-token isteği de adaptöre ulaşmadan ilk 401'i bırakma;
            // test gerçekten eşzamanlı bir yenileme kohortu kursun.
            await api.requestsReach(2);
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
      expect(sent, hasLength(5));
      expect(sent.where((path) => path == ApiPaths.refreshToken), hasLength(1));
      expect(sentTokens[ApiPaths.refreshToken], ['Bearer suresi-dolmus']);
      expect(sentTokens[ApiPaths.currentUser], [
        'Bearer suresi-dolmus',
        'Bearer tazelenmis-erisim',
      ]);
      expect(sentTokens[ApiPaths.currentUserSessions], [
        'Bearer suresi-dolmus',
        'Bearer tazelenmis-erisim',
      ]);
      expect(
        (api.tokenStorage as FakeTokenStorage).accessToken,
        'tazelenmis-erisim',
      );
    });

    test(
      'eşzamanlı 401 yenilenemezse oturum bir kez sonlandırılıyor',
      () async {
        final sent = <String>[];
        late final FakeApi api;
        api = FakeApi(
          handler: (options) async {
            sent.add(options.path);
            if (options.path == ApiPaths.refreshToken) {
              return const FakeApiResponse(
                statusCode: 401,
                body: {'success': false, 'message': 'Yenileme reddedildi'},
              );
            }

            await api.requestsReach(2);
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

        final client = api.client;
        await expectLater(
          Future.wait([
            client.get<String>(
              ApiPaths.currentUser,
              parse: (data) => data! as String,
            ),
            client.get<String>(
              ApiPaths.currentUserSessions,
              parse: (data) => data! as String,
            ),
          ]),
          throwsA(
            isA<ApiException>().having(
              (error) => error.type,
              'type',
              ApiErrorType.unauthenticated,
            ),
          ),
        );

        expect(sent, hasLength(3));
        expect(
          sent.where((path) => path == ApiPaths.refreshToken),
          hasLength(1),
        );
        expect(api.sessionExpirationCount, 1);
      },
    );

    test('eski istek yeni kullanıcı tokenıyla tekrar oynatılmıyor', () async {
      final storage = FakeTokenStorage(
        accessToken: 'eski-hesap',
        refreshToken: 'eski-yenileme',
      );
      var businessCalls = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.path == ApiPaths.refreshToken) {
            fail('Yeni oturum için yenileme yapılmamalı.');
          }

          businessCalls++;
          if (businessCalls == 1) {
            storage
              ..accessToken = 'yeni-hesap'
              ..refreshToken = 'yeni-yenileme';
            return const FakeApiResponse(
              statusCode: 401,
              body: {'success': false, 'message': 'Eski oturum kapandı'},
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': 'yanlis-hesap'},
          );
        },
        tokenStorage: storage,
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
            ApiErrorType.unauthenticated,
          ),
        ),
      );

      expect(businessCalls, 1);
      expect(api.sessionExpired, isFalse);
    });

    test(
      'sonraki token nesli gerektiğinde kendi yenilemesini başlatıyor',
      () async {
        var businessCalls = 0;
        var refreshCalls = 0;
        final storage = FakeTokenStorage(
          accessToken: 'erisim-0',
          refreshToken: 'gecerli-yenileme',
        );
        final api = FakeApi(
          handler: (options) {
            if (options.path == ApiPaths.refreshToken) {
              refreshCalls++;
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'token': 'erisim-$refreshCalls'},
                },
              );
            }

            businessCalls++;
            if (businessCalls.isOdd) {
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
          tokenStorage: storage,
        );

        final client = api.client;
        for (var request = 0; request < 2; request++) {
          expect(
            await client.get<String>(
              ApiPaths.currentUser,
              parse: (data) => data! as String,
            ),
            'tamam',
          );
        }

        expect(refreshCalls, 2);
        expect(storage.accessToken, 'erisim-2');
        expect(api.sessionExpired, isFalse);
      },
    );
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
