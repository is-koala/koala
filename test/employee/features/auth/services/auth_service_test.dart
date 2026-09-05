import 'dart:convert';

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

  group('Giriş servisi', () {
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

    test('canlı /users/me gövdesiyle oturum açılır', () async {
      const raw =
          r'''{"id": "542630ce-2362-3850-84e2-e3b5b2e22b07", "firstName": "QA", "lastName": "QA", "email": "qa@example.com", "profilePictureUrl": "https://api.iskoala.com/qa-assets/avatars/calisan-00.png", "phoneNumber": "+905300001000", "birthDate": "1992-01-01", "gender": "FEMALE", "maskedTcIdentityNumber": "***********", "jobTitle": "Fotoğrafçılık Uzmanı", "about": "İstanbul'da esnek işlerde çalışan, dakik ve iletişimi güçlü bir Koala üyesiyim.", "qualifications": "Müşteri iletişimi, ekip çalışması, zaman yönetimi", "experiences": [], "interests": "Kahve, müzik, şehir etkinlikleri", "maskedIban": "TR18***2315", "cvUrl": "https://api.iskoala.com/qa-assets/cv/ornek-cv.pdf", "educations": [], "badges": [], "address": {"id": "5029d77f-b853-3a54-898f-963882ddb7bc", "countryId": "26a60ab5-db94-4167-8678-1bb6a85fce30", "countryName": "TÜRKİYE", "countryCode": "TR", "cityId": "e3eecc83-7fa1-4405-bc61-04dd36656ebd", "cityName": "İSTANBUL", "districtId": "bec316bb-3148-421b-9a0c-53ac90844468", "districtName": "ADALAR", "components": {"neighborhood": "Adalar Mahallesi", "thoroughfare": "1. Sokak", "siteName": null, "block": null, "buildingName": null, "buildingNumber": "2", "floor": null, "unitNumber": null, "postalCode": "34000", "additionalDirections": null}, "position": {"latitude": 40.88, "longitude": 28.67, "source": "USER_CONFIRMED_PIN"}, "displayAddress": "Adalar Mahallesi, 1. Sokak, No: 2, ADALAR/İSTANBUL, 34000", "confirmedAt": "2026-08-01T09:00:00Z", "canonicalVersion": 1, "needsReview": false}, "isEmployer": false, "emailVerified": true, "phoneVerified": true, "identityVerified": true, "roles": ["ROLE_USER"], "companies": []}''';
      final api = FakeApi(
        handler: (request) => request.path == '/auth/login'
            ? const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {'token': 'access', 'refreshToken': 'refresh'},
                },
              )
            : FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': jsonDecode(raw) as Map<String, dynamic>,
                },
              ),
      );

      final user = await AuthService.withClient(
        api.client,
        sessionManager: session,
      ).login(email: 'qa@example.com', password: 'TestPassword1');

      expect(user.isEmployer, isFalse);
      expect(session.isLoggedIn, isTrue);
    });

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

    test('yerel depolama hata verirse giriş hatası nedenini taşır', () async {
      final api = FakeApi(
        handler: (request) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'token': 'access', 'refreshToken': 'refresh'},
          },
        ),
      );
      final failingSession = SessionManager.withTokenStorage(
        _FailingTokenStorage(),
      );
      addTearDown(failingSession.dispose);

      try {
        await AuthService.withClient(
          api.client,
          sessionManager: failingSession,
        ).login(email: 'isveren@example.com', password: 'TestPassword1');
        fail('ApiException bekleniyordu');
      } on ApiException catch (error) {
        // Kullanıcıya gösterilen mesaj sade kalmalı ama nedeni yutulmamalı;
        // aksi halde cihazda çıkan hata teşhis edilemiyor.
        expect(error.cause, isA<StateError>());
        expect(error.toString(), contains('cause:'));
      }
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

/// Anahtarlık yazımının cihazda başarısız olduğu durumu taklit eder.
class _FailingTokenStorage extends TokenStorage {
  _FailingTokenStorage()
    : super.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://test.local',
      );

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    DateTime? refreshExpiresAt,
  }) async {
    throw StateError('anahtarlık kullanılamıyor');
  }
}
