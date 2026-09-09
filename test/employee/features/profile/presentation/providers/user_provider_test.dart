import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';

import '../../../../../support/fake_api.dart';

/// Sahte sunucudan dönen, en az alanla dolu bir kullanıcı gövdesi.
Map<String, dynamic> userBody({String firstName = 'Yakup', String? about}) {
  return {
    'id': 'user-1',
    'firstName': firstName,
    'lastName': 'Kahraman',
    'email': 'a@b.com',
    'about': about,
    'isEmployer': false,
  };
}

UserProvider buildProvider(FakeApi api) {
  return UserProvider(userService: UserService.withClient(api.client));
}

void main() {
  group('Kullanıcı durumunda profil fotoğrafı yükleme', () {
    test('yükleme sonrası kullanıcı görünür fotoğrafıyla tazelenir', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'PUT'
            ? const FakeApiResponse(statusCode: 200, body: {'success': true})
            : FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    ...userBody(),
                    'profilePictureUrl': 'https://cdn.test/avatar.jpg',
                  },
                },
              ),
      );
      final provider = buildProvider(api);
      final file = File(
        '${Directory.systemTemp.path}/koala-provider-avatar.jpg',
      )..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.deleteSync());

      final uploaded = await provider.uploadProfilePicture(file.path);

      expect(uploaded, isTrue);
      expect(provider.user?.profilePictureUrl, 'https://cdn.test/avatar.jpg');
      expect(api.requests.map((request) => request.method), ['PUT', 'GET']);
    });
  });

  group('Kullanıcı durumunda özgeçmiş yükleme', () {
    test('CV yüklendikten sonra profil durumu tazelenir', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'PUT'
            ? const FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': '/users/me/cv/file'},
              )
            : FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {...userBody(), 'cvUrl': '/users/me/cv/file'},
                },
              ),
      );
      final provider = buildProvider(api);
      final file = File('${Directory.systemTemp.path}/koala-provider-cv.pdf')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.deleteSync());

      final uploaded = await provider.uploadCv(file.path);

      expect(uploaded, isTrue);
      expect(provider.user?.cvUrl, '/users/me/cv/file');
    });
  });

  group('Kullanıcı durumunda özgeçmiş kaldırma', () {
    test('CV silindikten sonra profil boş durumla tazelenir', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'DELETE'
            ? const FakeApiResponse(statusCode: 200, body: {'success': true})
            : FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': userBody()},
              ),
      );
      final provider = buildProvider(api);

      final deleted = await provider.deleteCv();

      expect(deleted, isTrue);
      expect(provider.user?.cvUrl, isNull);
      expect(api.requests.map((request) => request.method), ['DELETE', 'GET']);
    });
  });

  group('UserProvider.load', () {
    test('başlangıçta kullanıcı yok', () {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(statusCode: 200),
      );

      final provider = buildProvider(api);

      expect(provider.user, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.hasError, isFalse);
    });

    test('başarılı yanıtta kullanıcı dolar', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': userBody(about: 'Merhaba'),
          },
        ),
      );

      final provider = buildProvider(api);
      await provider.load();

      expect(provider.user?.fullName, 'Yakup Kahraman');
      expect(provider.user?.about, 'Merhaba');
      expect(provider.isLoading, isFalse);
      expect(provider.hasError, isFalse);
    });

    test('hata mesajı errorMessage alanına düşer', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );

      final provider = buildProvider(api);
      await provider.load();

      expect(provider.user, isNull);
      expect(provider.errorMessage, 'Sunucu hatası');
      expect(provider.hasError, isTrue);
    });

    test('başarılı yükleme önceki hatayı temizler', () async {
      var shouldFail = true;
      final api = FakeApi(
        handler: (_) => shouldFail
            ? const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Sunucu hatası'},
              )
            : FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': userBody()},
              ),
      );

      final provider = buildProvider(api);
      await provider.load();
      expect(provider.hasError, isTrue);

      shouldFail = false;
      await provider.load();

      expect(provider.hasError, isFalse);
      expect(provider.user, isNotNull);
    });

    test('süren yükleme varken ikinci çağrı ağa çıkmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': userBody()},
        ),
      );

      final provider = buildProvider(api);
      await Future.wait([provider.load(), provider.load()]);

      expect(api.requests, hasLength(1));
    });

    test('sessiz tazelemeler de üst üste binmez', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': userBody()},
        ),
      );

      final provider = buildProvider(api);
      await provider.load();

      await Future.wait([
        provider.load(silent: true),
        provider.load(silent: true),
      ]);

      // İlk yükleme + tek sessiz tazeleme.
      expect(api.requests, hasLength(2));
    });

    test('sessiz tazeleme eldeki veri varken göstergeyi açmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': userBody()},
        ),
      );

      final provider = buildProvider(api);
      await provider.load();

      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));
      await provider.load(silent: true);

      expect(loadingStates, everyElement(isFalse));
    });
  });

  group('UserProvider.updateProfile', () {
    test('yanıttaki kullanıcı eldekinin yerine geçer', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'GET'
            ? FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': userBody()},
              )
            : FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'user': userBody(firstName: 'Ahmet', about: 'Yeni'),
                    'pendingVerifications': const [],
                  },
                },
              ),
      );

      final provider = buildProvider(api);
      await provider.load();

      final pending = await provider.updateProfile(about: 'Yeni');

      expect(pending, isEmpty);
      expect(provider.user?.firstName, 'Ahmet');
      expect(provider.user?.about, 'Yeni');
    });

    test('hata durumunda null döner ve eldeki kullanıcı korunur', () async {
      final api = FakeApi(
        handler: (options) => options.method == 'GET'
            ? FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': userBody()},
              )
            : const FakeApiResponse(
                statusCode: 400,
                body: {'success': false, 'message': 'Ad değiştirilemez'},
              ),
      );

      final provider = buildProvider(api);
      await provider.load();

      final pending = await provider.updateProfile(firstName: 'Ahmet');

      expect(pending, isNull);
      expect(provider.errorMessage, 'Ad değiştirilemez');
      expect(provider.user?.firstName, 'Yakup');
    });
  });

  group('UserProvider.clear', () {
    test('çıkışta kullanıcı ve hata düşer', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': userBody()},
        ),
      );

      final provider = buildProvider(api);
      await provider.load();
      provider.clear();

      expect(provider.user, isNull);
      expect(provider.hasError, isFalse);
    });

    test('geç eski yanıt yeni hesabın profilini ezmez', () async {
      final accountAResponse = Completer<FakeApiResponse>();
      final accountBResponse = Completer<FakeApiResponse>();
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          if (call == 1) return accountAResponse.future;
          return accountBResponse.future;
        },
      );
      final provider = buildProvider(api);

      final accountALoad = provider.load();
      await api.requestsReach(1);

      provider.clear();
      final accountBLoad = provider.load();
      final bStarted = await Future.any([
        api.requestsReach(2).then((_) => true),
        accountBLoad.then((_) => false),
      ]);
      expect(bStarted, isTrue, reason: 'Yeni oturumun isteği engellenmemeli');

      accountAResponse.complete(
        FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': userBody(firstName: 'A'),
          },
        ),
      );
      await accountALoad;

      expect(provider.user, isNull);
      expect(provider.isLoading, isTrue);
      expect(provider.errorMessage, isNull);

      accountBResponse.complete(
        FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': userBody(firstName: 'B'),
          },
        ),
      );
      await accountBLoad;

      expect(api.requests, hasLength(2));
      expect(provider.user?.firstName, 'B');
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test(
      'eski fotoğraf yüklemesi yeni oturumla profil isteği başlatmaz',
      () async {
        final accountAUpload = Completer<FakeApiResponse>();
        final api = FakeApi(
          handler: (options) => options.method == 'PUT'
              ? accountAUpload.future
              : FakeApiResponse(
                  statusCode: 200,
                  body: {
                    'success': true,
                    'data': userBody(firstName: 'B'),
                  },
                ),
        );
        final provider = buildProvider(api);
        final file = File(
          '${Directory.systemTemp.path}/koala-stale-provider-avatar.jpg',
        )..writeAsBytesSync(const [1, 2, 3]);
        addTearDown(() => file.deleteSync());

        final accountAUploadResult = provider.uploadProfilePicture(file.path);
        await api.requestsReach(1);

        provider.clear();
        await provider.load();

        accountAUpload.complete(
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
        );

        expect(await accountAUploadResult, isFalse);
        expect(provider.user?.firstName, 'B');
        expect(provider.errorMessage, isNull);
        expect(api.requests.map((request) => request.method), [
          'PUT',
          'GET',
        ], reason: 'Eski yükleme B oturumunda /users/me çağırmamalı');
      },
    );
  });
}
