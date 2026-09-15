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

  group('SessionService.fetchDetail', () {
    test('oturum ayrıntısı modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'ses_1',
              'deviceId': 'dev_1',
              'deviceType': 'IOS',
              'deviceName': 'iPhone 14 Pro Max · iOS 18.1 · Koala 1.1.0',
              'ipAddress': '85.100.1.1',
              'location': 'İstanbul, TR',
              'current': true,
              'logins': 3,
              'loginHistory': [
                {
                  'at': '2026-09-14T08:30:00Z',
                  'ipAddress': '85.100.1.1',
                  'location': 'İstanbul, TR',
                  'success': true,
                },
              ],
            },
          },
        ),
      );

      final detail = await SessionService.withClient(
        api.client,
      ).fetchDetail('ses_1');

      final request = api.requests.single;
      expect(request.path, '/users/me/sessions/ses_1');
      expect(request.method, 'GET');
      expect(detail.deviceId, 'dev_1');
      expect(detail.logins, 3);
      expect(detail.loginHistory.single.successful, isTrue);
    });

    // Eski sunucu ucu tanımıyor; başkasının oturumu da aynı `404`.
    test('404 notFound tipiyle yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Oturum bulunamadı',
            'errorCategory': 'RESOURCE_NOT_FOUND',
          },
        ),
      );

      await expectLater(
        SessionService.withClient(api.client).fetchDetail('ses_9'),
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

  group('SessionService.renameDevice', () {
    test('cihaz kimliği yola, ad gövdeye yazılır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'dev_1', 'customName': 'İş telefonum'},
          },
        ),
      );

      await SessionService.withClient(
        api.client,
      ).renameDevice('dev_1', 'İş telefonum');

      final request = api.requests.single;
      expect(request.path, '/users/me/devices/dev_1');
      expect(request.method, 'PATCH');
      expect(request.data, {'name': 'İş telefonum'});
    });

    test('boş ya da uzun ad 400 ile yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Cihaz adı en fazla 60 karakter olabilir',
            'errorCategory': 'VALIDATION_FAILED',
          },
        ),
      );

      await expectLater(
        SessionService.withClient(api.client).renameDevice('dev_1', 'x' * 61),
        throwsA(
          isA<ApiException>()
              .having((error) => error.type, 'type', ApiErrorType.validation)
              .having(
                (error) => error.message,
                'message',
                'Cihaz adı en fazla 60 karakter olabilir',
              ),
        ),
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
