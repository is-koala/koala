import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/verification_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('VerificationService.confirm', () {
    test('kod doğrulama kimliğinin confirm ucuna POST ediliyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await VerificationService.withClient(
        api.client,
      ).confirm('ver-1', '123456');

      final request = api.requests.single;
      expect(request.path, '/verifications/ver-1/confirm');
      expect(request.method, 'POST');
      expect(request.data, {'token': '123456'});
    });

    test('kod hatalıysa sunucunun mesajıyla 400 yükseliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {'success': false, 'message': 'Doğrulama kodu geçersiz'},
        ),
      );

      await expectLater(
        VerificationService.withClient(api.client).confirm('ver-1', '000000'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Doğrulama kodu geçersiz')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    // Kayıt başkasına aitse `403`, hiç yoksa `404`. İkisinde de ekran
    // kapanmalı, o yüzden durum kodu çağırana ulaşmak zorunda.
    test('kayıt başkasına aitse 403 durum koduyla yükseliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 403,
          body: {'success': false, 'message': 'Bu doğrulama sana ait değil'},
        ),
      );

      await expectLater(
        VerificationService.withClient(api.client).confirm('ver-1', '123456'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('kayıt yoksa 404 durum koduyla yükseliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {'success': false, 'message': 'Doğrulama kaydı bulunamadı'},
        ),
      );

      await expectLater(
        VerificationService.withClient(api.client).confirm('yok', '123456'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.type, 'type', ApiErrorType.notFound),
        ),
      );
    });
  });
}
