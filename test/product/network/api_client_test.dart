import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../support/fake_api.dart';

void main() {
  group('ApiClient zarfı', () {
    test('başarılı yanıtta yalnızca data alanı döner', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'message': 'Giriş başarılı',
            'data': {'token': 'abc'},
          },
        ),
      );

      final token = await api.client.post<String>(
        '/auth/login',
        body: {'email': 'a@b.com'},
        parse: (data) => (data! as Map<String, dynamic>)['token'] as String,
      );

      expect(token, 'abc');
    });

    test('gövdesiz uçta yanıt çözülür ve hata fırlatmaz', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'message': 'Kayıt başlatıldı'},
        ),
      );

      await expectLater(
        api.client.postWithoutData('/auth/start-registration'),
        completes,
      );
    });

    test('istek gövdesi ve yolu olduğu gibi gider', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await api.client.postWithoutData(
        '/auth/forgot-password',
        body: {'email': 'a@b.com'},
      );

      expect(api.requests.single.path, '/auth/forgot-password');
      expect(api.requests.single.data, {'email': 'a@b.com'});
    });

    test('JSON olmayan yanıt ApiException üretir', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse.raw(statusCode: 200, body: 'merhaba'),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/auth/login'),
      );

      expect(error.type, ApiErrorType.unknown);
    });

    test('success false ise data hiç ayrıştırılmaz', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {'success': false, 'message': 'Olmadı'},
        ),
      );

      final error = await _captureError(
        () => api.client.post<String>(
          '/auth/login',
          // data yok; ayrıştırma çağrılsaydı burada patlardı.
          parse: (data) => (data! as Map<String, dynamic>)['token'] as String,
        ),
      );

      expect(error.message, 'Olmadı');
    });
  });

  group('ApiClient hata çevirisi', () {
    test('400 yanıtı alan hatalarıyla birlikte validation olur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Doğrulama hatası',
            'errorCode': 'VALIDATION_ERROR',
            'details': [
              {'field': 'email', 'message': 'Geçersiz e-posta'},
            ],
          },
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/auth/login'),
      );

      expect(error.type, ApiErrorType.validation);
      expect(error.statusCode, 400);
      expect(error.message, 'Doğrulama hatası');
      expect(error.errorCode, 'VALIDATION_ERROR');
      expect(error.messageForField('email'), 'Geçersiz e-posta');
      expect(error.messageForField('password'), isNull);
    });

    test('401 yanıtı unauthorized olur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 401,
          body: {'success': false, 'message': 'Oturum bulunamadı'},
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/users/me'),
      );

      expect(error.type, ApiErrorType.unauthorized);
      expect(error.message, 'Oturum bulunamadı');
    });

    // Sunucudaki `MinimumAppVersionFilter` eski istemciyi böyle geri
    // çeviriyor. Tekrar denemenin faydası yok, ayrı bir tür olmalı.
    test('426 yanıtı upgradeRequired olur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 426,
          body: {
            'success': false,
            'errorCode': 'UPGRADE_REQUIRED',
            'message': 'Lutfen uygulamayi guncelleyin.',
          },
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/users/me'),
      );

      expect(error.type, ApiErrorType.upgradeRequired);
      expect(error.errorCode, 'UPGRADE_REQUIRED');
      expect(error.message, 'Lutfen uygulamayi guncelleyin.');
    });

    test('429 yanıtı tooManyRequests olur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 429,
          body: {'success': false, 'message': 'Çok fazla istek'},
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/auth/login'),
      );

      expect(error.type, ApiErrorType.tooManyRequests);
    });

    test('500 yanıtı server olur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/auth/login'),
      );

      expect(error.type, ApiErrorType.server);
    });

    test('bağlantı kurulamazsa network olur ve mesaj Türkçe kalır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse.connectionError(),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/auth/login'),
      );

      expect(error.type, ApiErrorType.network);
      expect(error.message, contains('İnternet'));
    });

    test('2xx dönse bile success false ise hata fırlatır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': false, 'message': 'Olmadı'},
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/auth/login'),
      );

      expect(error.message, 'Olmadı');
    });
  });
}

/// Çağrının fırlattığı [ApiException]'ı yakalar; fırlatmazsa testi düşürür.
Future<ApiException> _captureError(Future<void> Function() call) async {
  try {
    await call();
  } on ApiException catch (error) {
    return error;
  }
  fail('ApiException bekleniyordu ama çağrı başarıyla tamamlandı.');
}
