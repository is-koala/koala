import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/session_service.dart';

import '../../support/fake_api.dart';

void main() {
  group('SessionService.fetchSessions', () {
    test('oturum listesi modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'ses_1',
                'deviceType': 'IOS',
                'deviceName': 'iPhone 15',
                'current': true,
              },
              {'id': 'ses_2', 'deviceType': 'ANDROID', 'current': false},
            ],
          },
        ),
      );

      final sessions = await SessionService.withClient(
        api.client,
      ).fetchSessions();

      final request = api.requests.single;
      expect(request.path, '/users/me/sessions');
      expect(request.method, 'GET');
      expect(sessions, hasLength(2));
      expect(sessions.first.isCurrent, isTrue);
      expect(sessions.last.deviceType, SessionDeviceType.android);
    });

    test('boş liste hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      expect(
        await SessionService.withClient(api.client).fetchSessions(),
        isEmpty,
      );
    });
  });

  group('SessionService.revoke', () {
    test('oturum kimliği yola eklenir', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await SessionService.withClient(api.client).revoke('ses_2');

      final request = api.requests.single;
      expect(request.path, '/users/me/sessions/ses_2');
      expect(request.method, 'DELETE');
    });

    // Başkasının oturumu "yok" diye dönüyor; kimlik sızmasın diye.
    test('başkasının oturumu 404 yükseltir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {'success': false, 'message': 'Oturum bulunamadı'},
        ),
      );

      await expectLater(
        SessionService.withClient(api.client).revoke('ses_9'),
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

  group('SessionService.revokeOthers', () {
    test('kapatılan oturum sayısını döndürür', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 3},
        ),
      );

      final closed = await SessionService.withClient(api.client).revokeOthers();

      final request = api.requests.single;
      expect(request.path, '/users/me/sessions');
      expect(request.method, 'DELETE');
      expect(closed, 3);
    });

    // Kapatılacak başka oturum yoksa sunucu sıfır dönüyor, hata değil.
    test('kapatılacak oturum yoksa sıfır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 0},
        ),
      );

      expect(await SessionService.withClient(api.client).revokeOthers(), 0);
    });
  });
}
