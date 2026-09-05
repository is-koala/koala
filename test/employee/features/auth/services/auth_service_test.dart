import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService.login', () {
    late TokenStorage storage;
    late SessionManager session;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      storage = TokenStorage.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://test.local',
      );
      session = SessionManager.withTokenStorage(storage);
    });

    tearDown(() => session.dispose());

    for (final isEmployer in [true, false]) {
      test(
        '${isEmployer ? 'işveren' : 'iş arayan'} oturumu yalnız profil doğrulandıktan sonra açılır',
        () async {
          final api = FakeApi(
            handler: (request) {
              if (request.path == '/auth/login') {
                return const FakeApiResponse(
                  statusCode: 200,
                  body: {
                    'success': true,
                    'data': {'token': 'access', 'refreshToken': 'refresh'},
                  },
                );
              }
              expect(request.path, '/users/me');
              expect(session.isLoggedIn, isFalse);
              expect(session.userType, isNull);
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'id': 'user-id',
                    'email': 'hesap@example.com',
                    'isEmployer': isEmployer,
                  },
                },
              );
            },
          );

          final user = await AuthService.withClient(
            api.client,
            sessionManager: session,
          ).login(email: 'hesap@example.com', password: 'TestPassword1');

          expect(user.isEmployer, isEmployer);
          session.resetForTest();
          await session.load();
          expect(session.isLoggedIn, isTrue);
          expect(
            session.userType,
            isEmployer
                ? SessionManager.businessType
                : SessionManager.employeeType,
          );
          expect(await storage.readAccessToken(), 'access');
          expect(await storage.readRefreshToken(), 'refresh');
        },
      );
    }

    test(
      'profil yüklenemezse giriş hata verir ve yarım oturum silinir',
      () async {
        final api = FakeApi(
          handler: (request) => request.path == '/auth/login'
              ? const FakeApiResponse(
                  statusCode: 200,
                  body: {
                    'success': true,
                    'data': {
                      'token': 'access',
                      'refreshToken': 'refresh',
                      'refreshExpiresAt': '2026-10-05T12:00:00Z',
                    },
                  },
                )
              : const FakeApiResponse(
                  statusCode: 503,
                  body: {'success': false, 'message': 'Profil yüklenemedi'},
                ),
        );

        await expectLater(
          AuthService.withClient(
            api.client,
            sessionManager: session,
          ).login(email: 'isveren@example.com', password: 'TestPassword1'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'Profil yüklenemedi',
            ),
          ),
        );

        expect(session.isLoggedIn, isFalse);
        expect(session.userType, isNull);
        expect(await storage.readAccessToken(), isNull);
        expect(await storage.readRefreshToken(), isNull);
        expect(await storage.readRefreshExpiresAt(), isNull);
      },
    );

    test('bozuk profil yanıtı hata verir ve yarım oturum bırakmaz', () async {
      final api = FakeApi(
        handler: (request) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': request.path == '/auth/login'
                ? {'token': 'access', 'refreshToken': 'refresh'}
                : null,
          },
        ),
      );

      await expectLater(
        AuthService.withClient(
          api.client,
          sessionManager: session,
        ).login(email: 'isveren@example.com', password: 'TestPassword1'),
        throwsA(isA<ApiException>()),
      );

      expect(session.isLoggedIn, isFalse);
      expect(session.userType, isNull);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    });

    for (final roleFields in <Map<String, Object?>>[
      {},
      {'isEmployer': null},
      {'isEmployer': 'true'},
    ]) {
      test('geçersiz rol $roleFields iş arayan varsayılmaz', () async {
        final api = FakeApi(
          handler: (request) => FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': request.path == '/auth/login'
                  ? {'token': 'access', 'refreshToken': 'refresh'}
                  : {'id': 'user-id', ...roleFields},
            },
          ),
        );

        await expectLater(
          AuthService.withClient(
            api.client,
            sessionManager: session,
          ).login(email: 'isveren@example.com', password: 'TestPassword1'),
          throwsA(isA<ApiException>()),
        );

        expect(session.isLoggedIn, isFalse);
        expect(session.userType, isNull);
        expect(await storage.readAccessToken(), isNull);
        expect(await storage.readRefreshToken(), isNull);
      });
    }
  });

  group('AuthService.startRegistration', () {
    test('ad, soyad, e-posta ve isEmployer gövdeye konur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'message': 'Kayıt başlatıldı'},
        ),
      );

      await AuthService.withClient(api.client).startRegistration(
        firstName: 'Yakup',
        lastName: 'Kahraman',
        email: 'a@b.com',
        isEmployer: true,
      );

      final request = api.requests.single;
      expect(request.path, '/auth/start-registration');
      expect(request.data, {
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
        'isEmployer': true,
      });
    });
  });

  group('AuthService.verifyRegistrationToken', () {
    test('token gövdeye konur ve yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'setPasswordToken': 'jwt', 'isEmployer': true},
          },
        ),
      );

      final verification = await AuthService.withClient(
        api.client,
      ).verifyRegistrationToken('token-uuid');

      expect(api.requests.single.path, '/auth/verify-registration-token');
      expect(api.requests.single.data, {'registrationToken': 'token-uuid'});
      expect(verification.setPasswordToken, 'jwt');
      expect(verification.isEmployer, isTrue);
    });

    test('süresi dolmuş token ApiException olarak yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Kayıt bağlantısının süresi dolmuş',
          },
        ),
      );

      await expectLater(
        AuthService.withClient(api.client).verifyRegistrationToken('eski'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Kayıt bağlantısının süresi dolmuş',
          ),
        ),
      );
    });
  });

  group('AuthService.forgotPassword', () {
    test('e-posta gövdeye konur', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await AuthService.withClient(api.client).forgotPassword('a@b.com');

      expect(api.requests.single.path, '/auth/forgot-password');
      expect(api.requests.single.data, {'email': 'a@b.com'});
    });
  });
}
