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
  };
}

UserProvider buildProvider(FakeApi api) {
  return UserProvider(userService: UserService.withClient(api.client));
}

void main() {
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
  });
}
