import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

/// Oturum açan uçlar (`login`, `completeRegistration`) burada test edilmiyor:
/// token'ları Keychain/Keystore'a yazdıkları için gerçek platform kanalı
/// gerekiyor. Oturuma dokunmayan uçlar sahte sunucuyla doğrulanıyor.
void main() {
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
