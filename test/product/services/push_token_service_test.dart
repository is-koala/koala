import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/services/push_token_service.dart';

import '../../support/fake_api.dart';

void main() {
  group('PushTokenService.save', () {
    test('PUT /users/me/devices/push-token gövdesinde token taşır', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await PushTokenService.withClient(api.client).save('fcm-token-1');

      final request = api.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/users/me/devices/push-token');
      expect(request.data, {'pushToken': 'fcm-token-1'});
    });

    test('uç oturum ister, publicPaths içinde değildir', () {
      expect(
        ApiPaths.publicPaths.contains(ApiPaths.currentUserPushToken),
        isFalse,
      );
    });
  });

  group('PushTokenService.clear', () {
    test('DELETE /users/me/devices/push-token gövdesiz gider', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await PushTokenService.withClient(api.client).clear();

      final request = api.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/users/me/devices/push-token');
      expect(request.data, isNull);
    });
  });

  group('PushTokenService hataları', () {
    test('404 kullanıcıya yükseltilir, sessizlik çağıranın işi', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'errorCode': 'DEVICE_NOT_FOUND',
            'errorCategory': 'RESOURCE_NOT_FOUND',
            'message': 'Cihaz bulunamadı',
          },
        ),
      );

      await expectLater(
        PushTokenService.withClient(api.client).save('token'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });
  });
}
