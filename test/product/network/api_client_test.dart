import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';

import '../../support/fake_api.dart';

void main() {
  group('ApiClient zarfı', () {
    for (final payload in [null, 'sayı değil']) {
      test('bozuk veri $payload anlaşılır API hatası olur', () async {
        final api = FakeApi(
          handler: (_) => FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': payload},
          ),
        );

        await expectLater(
          api.client.get<int>(
            '/reference/value',
            parse: (data) => int.parse(data as String),
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'Sunucudan beklenmeyen bir yanıt geldi.',
            ),
          ),
        );
      });
    }

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

  group('ApiClient dosya yükleme', () {
    late Directory tempDir;
    late File imageFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('koala_post_file');
      imageFile = File('${tempDir.path}/galeri.jpg');
      await imageFile.writeAsString('koala-galeri-gorseli');
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('postFile dosyayı verilen parça adıyla multipart POST eder', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': [
              {'id': 'img-1'},
            ],
          },
        ),
      );

      final ids = await api.client.postFile<List<String>>(
        ApiPaths.companyImages('c-1'),
        fieldName: 'image',
        filePath: imageFile.path,
        parse: (data) => [
          for (final item in data! as List<dynamic>)
            (item as Map<String, dynamic>)['id'] as String,
        ],
      );

      expect(ids, ['img-1']);

      final request = api.requests.single;
      expect(request.path, '/companies/c-1/images');
      expect(request.method, 'POST');
      // Taban ayarlar `application/json` yazıyor; galeri ucu bunu `415` ile
      // geri çevirirdi.
      expect(
        request.headers[Headers.contentTypeHeader],
        startsWith(Headers.multipartFormDataContentType),
      );

      // Sunucu uçları yalnız bir `MultipartFile` alıyor, yanında JSON parçası
      // beklemiyor.
      final formData = request.data! as FormData;
      expect(formData.fields, isEmpty);
      expect(formData.files, hasLength(1));
      expect(formData.files.single.key, 'image');
      expect(formData.files.single.value.filename, 'galeri.jpg');
    });

    test('postFile success false yanıtını ApiException yapar', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {
            'success': false,
            'message': 'Galeri sınırı aşıldı.',
            'errorCode': 'GALLERY_LIMIT_EXCEEDED',
          },
        ),
      );

      final error = await _captureError(
        () => api.client.postFile<List<String>>(
          ApiPaths.companyImages('c-1'),
          fieldName: 'image',
          filePath: imageFile.path,
          // data yok; ayrıştırma çağrılsaydı burada patlardı.
          parse: (data) => (data! as List<dynamic>).cast<String>(),
        ),
      );

      expect(error.type, ApiErrorType.dataConflict);
      expect(error.statusCode, 409);
      expect(error.message, 'Galeri sınırı aşıldı.');
      expect(error.errorCode, 'GALLERY_LIMIT_EXCEEDED');
    });

    test(
      'postMultipartJsonFiles JSON parçasını ve her dosyayı kendi parçasında '
      'gönderir',
      () async {
        final second = File('${tempDir.path}/arka.png')
          ..writeAsStringSync('koala-arka');
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 201,
            body: {
              'success': true,
              'data': {'id': 'r-1'},
            },
          ),
        );

        final id = await api.client.postMultipartJsonFiles<String>(
          ApiPaths.currentUserIdentityDocuments,
          jsonFieldName: 'identity',
          jsonBody: const {'firstName': 'Çağrı'},
          files: {'front': imageFile.path, 'back': second.path},
          parse: (data) => (data! as Map<String, dynamic>)['id'] as String,
        );

        expect(id, 'r-1');
        final request = api.requests.single;
        expect(request.method, 'POST');
        expect(
          request.headers[Headers.contentTypeHeader],
          startsWith(Headers.multipartFormDataContentType),
        );
        final formData = request.data! as FormData;
        expect(formData.fields, isEmpty);
        expect(formData.files.map((part) => part.key), [
          'identity',
          'front',
          'back',
        ]);
        final byKey = {for (final part in formData.files) part.key: part.value};
        expect(byKey['identity']!.contentType?.mimeType, 'application/json');
        expect(byKey['front']!.filename, 'galeri.jpg');
        expect(byKey['front']!.contentType?.mimeType, 'image/jpeg');
        expect(byKey['back']!.filename, 'arka.png');
        expect(byKey['back']!.contentType?.mimeType, 'image/png');
        expect(byKey['back']!.length, 'koala-arka'.length);
      },
    );

    test(
      'postMultipartJsonFiles ilerleme geri çağrısını dio\'ya iletir',
      () async {
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 201,
            body: {'success': true, 'data': 1},
          ),
        );
        void onProgress(int sent, int total) {}

        await api.client.postMultipartJsonFiles<int>(
          ApiPaths.currentUserIdentityDocuments,
          jsonFieldName: 'identity',
          jsonBody: const {},
          files: {'front': imageFile.path},
          onSendProgress: onProgress,
          parse: (data) => data! as int,
        );

        // Sahte adaptör akışı okumadığı için geri çağrı burada tetiklenmiyor;
        // ölçülen şey isteğe takılmış olması. Gerçek adaptör her parçada
        // çağırıyor.
        expect(api.requests.single.onSendProgress, same(onProgress));
      },
    );
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

    test('401 yanıtı unauthenticated olur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 401,
          body: {'success': false, 'message': 'Oturum bulunamadı'},
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData('/users/me'),
      );

      expect(error.type, ApiErrorType.unauthenticated);
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

  // Zarfın metin alanları `as String?` ile okunursa, beklenmedik türde gelen
  // bir alan `_TypeError` atar. Hata yanıtında bu cast `_toApiException`'ın
  // *içinden* çalışıyor, yani `ApiClient`'ın `TypeError` ağına hiç uğramadan
  // çağırana ham hâliyle ulaşır: sayfa `on ApiException` yakalar, uygulama
  // düşer. Koruma alan alan değil zarfın geneline konuldu; bu grup da tek
  // tek her alanı ölçüyor.
  group('ApiClient zarfın tür koruması', () {
    for (final field in ['message', 'errorCode', 'errorCategory', 'success']) {
      test('$field beklenmedik türde gelirse ApiException kalır', () async {
        final api = FakeApi(
          handler: (_) => FakeApiResponse(
            statusCode: 409,
            body: {
              'success': false,
              'message': 'Çakışma',
              'errorCode': 'ALREADY_EXISTS',
              'errorCategory': 'DATA_CONFLICT',
              // Sözleşme dizge (`success` için bool) diyor; bu alan bozuk.
              field: 42,
            },
          ),
        );

        final error = await _captureError(
          () => api.client.postWithoutData(ApiPaths.login),
        );

        // Bozuk alan "gelmedi" sayılıyor, kalan alanlar okunmaya devam ediyor.
        expect(error.statusCode, 409);
        expect(error.type, ApiErrorType.dataConflict);
      });
    }

    test('bozuk errorCode null kalır, kategori okunmayı sürdürür', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 403,
          body: {
            'success': false,
            'message': 'Yetkin yok',
            'errorCode': 42,
            'errorCategory': 'ACCESS_DENIED',
          },
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.login),
      );

      expect(error.errorCode, isNull);
      expect(error.message, 'Yetkin yok');
      expect(error.type, ApiErrorType.forbidden);
    });

    test('details içindeki bozuk alan diğer alan hatasını düşürmez', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Doğrulama hatası',
            'errorCategory': 'VALIDATION_FAILED',
            'details': [
              {'field': 42, 'message': 'Geçersiz'},
              {'field': 'email', 'message': 'Geçersiz e-posta'},
            ],
          },
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.login),
      );

      expect(error.type, ApiErrorType.validation);
      expect(error.messageForField('email'), 'Geçersiz e-posta');
      // Adı okunamayan alan hatası boş adla duruyor; listeyi düşürmüyor.
      expect(error.fieldErrors, hasLength(2));
    });

    test('başarı zarfında da bozuk message çökme üretmiyor', () async {
      // Başarı yolu `_send`'in `try`'ı içinden geçtiği için `TypeError` zaten
      // yakalanıyordu — ama "Sunucudan beklenmeyen bir yanıt geldi." diyerek,
      // yani gerçekten gelen veriyi atarak. Artık `data` okunmayı sürdürüyor.
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'message': 42, 'data': 'değer'},
        ),
      );

      final value = await api.client.get<String>(
        ApiPaths.login,
        parse: (data) => data as String,
      );

      expect(value, 'değer');
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
