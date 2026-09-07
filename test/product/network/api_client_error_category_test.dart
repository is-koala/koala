import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/app_update_gate.dart';

import '../../support/fake_api.dart';

/// Hata sınıflandırmasının kaynağı: backend'in `errorCategory` alanı
/// (is-koala/koala#82). Durum kodu yalnızca yedek.
void main() {
  setUp(() => AppUpdateGate().reset());
  tearDown(() => AppUpdateGate().reset());

  group('errorCategory tipi belirliyor', () {
    // Backend'in `ErrorCategory` enum'unun tamamı (17 değer). Kapalı kümenin
    // her elemanı burada: yeni bir değer eklendiğinde eşlemenin bilinçli
    // olarak yazılması gerekiyor.
    const mapping = <String, ApiErrorType>{
      'VALIDATION_FAILED': ApiErrorType.validation,
      'REQUEST_MALFORMED': ApiErrorType.validation,
      'PARAMETER_MISSING': ApiErrorType.validation,
      'AUTHENTICATION_REQUIRED': ApiErrorType.unauthenticated,
      'INVALID_CREDENTIALS': ApiErrorType.unauthenticated,
      'TOKEN_EXPIRED': ApiErrorType.unauthenticated,
      'ACCESS_DENIED': ApiErrorType.forbidden,
      'RESOURCE_NOT_FOUND': ApiErrorType.notFound,
      'ENDPOINT_NOT_FOUND': ApiErrorType.notFound,
      'BUSINESS_RULE_VIOLATION': ApiErrorType.businessRule,
      'DATA_CONFLICT': ApiErrorType.dataConflict,
      'METHOD_NOT_ALLOWED': ApiErrorType.unknown,
      'MEDIA_TYPE_NOT_SUPPORTED': ApiErrorType.unknown,
      'RATE_LIMITED': ApiErrorType.tooManyRequests,
      'CLIENT_TOO_OLD': ApiErrorType.upgradeRequired,
      'UPSTREAM_FAILED': ApiErrorType.server,
      'UNEXPECTED': ApiErrorType.server,
    };

    mapping.forEach((category, expected) {
      test('$category → ${expected.name}', () async {
        // Durum kodu bilerek 500: eşleme kategoriden gelmiyorsa hepsi
        // `server` çıkar ve yalnızca iki satır yeşil kalır.
        expect(await _typeFor(statusCode: 500, category: category), expected);
      });
    });

    test('kapalı kümenin tamamı sınanıyor', () {
      // Sunucudaki `ErrorCategory` 17 değer taşıyor; tablo eksilirse bu
      // testin kendisi düşer.
      expect(mapping, hasLength(17));
    });
  });

  // Issue'nun sebebi: bu iki çift bugün tek tipe iniyordu.
  group('durum kodunun kaybettiği ayrımlar', () {
    test('TOKEN_EXPIRED oturum, ACCESS_DENIED yetki hatası üretir', () async {
      final expired = await _typeFor(
        statusCode: 401,
        category: 'TOKEN_EXPIRED',
      );
      final denied = await _typeFor(statusCode: 403, category: 'ACCESS_DENIED');

      expect(expired, ApiErrorType.unauthenticated);
      expect(denied, ApiErrorType.forbidden);
      expect(expired, isNot(denied));

      // Yukarıdaki iki satır durum kodu yolundan da geçebilir (`401` ve `403`
      // zaten ayrı tiplere düşüyor), yani tek başlarına ayrımın kategoriden
      // geldiğini kanıtlamaz. Durum kodunu ters çevirince kanıtlıyor.
      expect(
        await _typeFor(statusCode: 403, category: 'TOKEN_EXPIRED'),
        ApiErrorType.unauthenticated,
      );
      expect(
        await _typeFor(statusCode: 401, category: 'ACCESS_DENIED'),
        ApiErrorType.forbidden,
      );
    });

    test('BUSINESS_RULE_VIOLATION ile DATA_CONFLICT ayrı tip', () async {
      final rule = await _typeFor(
        statusCode: 409,
        category: 'BUSINESS_RULE_VIOLATION',
      );
      final data = await _typeFor(statusCode: 409, category: 'DATA_CONFLICT');

      expect(rule, ApiErrorType.businessRule);
      expect(data, ApiErrorType.dataConflict);
      expect(rule, isNot(data));
    });

    // Asıl kanıt burada: kategori ile durum kodu **çeliştiğinde** kategori
    // kazanıyor. Sınıflandırma hâlâ durum kodundan yapılıyor olsaydı bu iki
    // beklenti ters çıkardı.
    test('kategori, çelişen durum kodunu eziyor', () async {
      expect(
        await _typeFor(statusCode: 200, category: 'BUSINESS_RULE_VIOLATION'),
        ApiErrorType.businessRule,
      );
      expect(
        await _typeFor(statusCode: 500, category: 'RESOURCE_NOT_FOUND'),
        ApiErrorType.notFound,
      );
    });

    // `success: false` taşıyan 2xx yanıtı ayrı bir koddan geçiyor
    // (`_send`), hata yanıtı ayrı bir koddan (`_fromResponse`). İkisi de
    // kategoriyi okumalı; yalnız birini bağlamak sessiz bir boşluk bırakır.
    test('2xx gövdesindeki success:false de kategoriyi okuyor', () async {
      expect(
        await _typeFor(statusCode: 200, category: 'ACCESS_DENIED'),
        ApiErrorType.forbidden,
      );
      expect(
        await _typeFor(statusCode: 200, category: 'DATA_CONFLICT'),
        ApiErrorType.dataConflict,
      );
    });
  });

  group('kapalı küme büyüyebilir', () {
    // Sunucu yeni bir kategori eklediğinde uygulama çökmemeli.
    for (final unknown in [
      'BRAND_NEW_CATEGORY',
      'token_expired', // küçük harf: enum adı değil
      '',
    ]) {
      test('tanınmayan kategori "$unknown" durum koduna düşüyor', () async {
        expect(
          await _typeFor(statusCode: 409, category: unknown),
          ApiErrorType.dataConflict,
        );
        expect(
          await _typeFor(statusCode: 403, category: unknown),
          ApiErrorType.forbidden,
        );
        expect(
          await _typeFor(statusCode: 500, category: unknown),
          ApiErrorType.server,
        );
      });
    }

    test('kategori dizge değilse çökmüyor, durum koduna düşüyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Bulunamadı',
            // Sunucu sözleşmesi dizge diyor; yine de gövdenin biçimi
            // istemciyi düşürmemeli.
            'errorCategory': 42,
          },
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.login),
      );

      expect(error.type, ApiErrorType.notFound);
    });
  });

  group('errorCategory yokken bugünkü davranış', () {
    // `ErrorResult` `@JsonInclude(NON_NULL)` taşıyor: alan hiç gelmeyebilir.
    // Eski sunucu ve zarfı elle yazan filtreler için tek yol bu.
    const statusTable = <int, ApiErrorType>{
      400: ApiErrorType.validation,
      422: ApiErrorType.validation,
      401: ApiErrorType.unauthenticated,
      403: ApiErrorType.forbidden,
      404: ApiErrorType.notFound,
      409: ApiErrorType.dataConflict,
      426: ApiErrorType.upgradeRequired,
      429: ApiErrorType.tooManyRequests,
      500: ApiErrorType.server,
      503: ApiErrorType.server,
      418: ApiErrorType.unknown,
    };

    statusTable.forEach((statusCode, expected) {
      test('$statusCode → ${expected.name}', () async {
        expect(await _typeFor(statusCode: statusCode), expected);
      });
    });

    test('alan null gelirse de durum kodu geçerli', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Çakışma', 'errorCategory': null},
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.login),
      );

      expect(error.type, ApiErrorType.dataConflict);
    });
  });

  group('kategoriden gelmeyen yollar', () {
    // Bu ikisi HTTP'ye hiç ulaşamamış hâller: zarf da kategori de yok.
    test('bağlantı kurulamazsa network kalıyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse.connectionError(),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.login),
      );

      expect(error.type, ApiErrorType.network);
      expect(error.message, contains('İnternet'));
    });

    test('zaman aşımı timeout kalıyor', () async {
      final api = FakeApi(handler: (_) => const FakeApiResponse.timeout());

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.login),
      );

      expect(error.type, ApiErrorType.timeout);
      expect(error.message, contains('zamanında'));
    });

    test('JSON olmayan gövde kategori aramadan durum koduna düşüyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse.raw(statusCode: 403, body: 'yasak'),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.login),
      );

      expect(error.type, ApiErrorType.forbidden);
    });
  });

  group('oturumu bitiren yol ile yetki reddi ayrı', () {
    // `AuthInterceptor` yalnızca `401`'de token yenilemeye çalışıyor ve
    // başaramazsa oturumu kapatıyor. `403` — kategori `ACCESS_DENIED` —
    // oturumu **kapatmamalı**: kullanıcının yetkisi yok, oturumu geçersiz
    // değil.
    test('ACCESS_DENIED oturumu kapatmıyor ve yenileme denemiyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 403,
          body: {
            'success': false,
            'message': 'Bu işlem için yetkin yok.',
            'errorCategory': 'ACCESS_DENIED',
          },
        ),
        tokenStorage: FakeTokenStorage(
          accessToken: 'gecerli',
          refreshToken: 'gecerli-yenileme',
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.currentUser),
      );

      expect(error.type, ApiErrorType.forbidden);
      expect(api.sessionExpired, isFalse);
      expect(api.requests.map((request) => request.path), [
        ApiPaths.currentUser,
      ]);
    });

    test('TOKEN_EXPIRED yenilemeyi ve oturum kapatmayı tetikliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 401,
          body: {
            'success': false,
            'message': 'Oturum süresi doldu.',
            'errorCategory': 'TOKEN_EXPIRED',
          },
        ),
        tokenStorage: FakeTokenStorage(
          accessToken: 'suresi-dolmus',
          refreshToken: 'gecersiz-yenileme',
        ),
      );

      final error = await _captureError(
        () => api.client.postWithoutData(ApiPaths.currentUser),
      );

      expect(error.type, ApiErrorType.unauthenticated);
      expect(api.sessionExpired, isTrue);
      expect(api.requests.map((request) => request.path), [
        ApiPaths.currentUser,
        ApiPaths.refreshToken,
      ]);
    });
  });

  // Sürüm kapısı `upgradeRequired` tipine bakıyor; tip artık kategoriden
  // türediği için filtrenin yazdığı `CLIENT_TOO_OLD` da kapıyı kapatmalı.
  test('CLIENT_TOO_OLD güncelleme kapısını kapatıyor', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 426,
        body: {
          'success': false,
          'httpStatus': 'UPGRADE_REQUIRED',
          'errorCategory': 'CLIENT_TOO_OLD',
          'errorCode': 'UPGRADE_REQUIRED',
          'message': 'Lutfen uygulamayi guncelleyin.',
        },
      ),
    );

    final error = await _captureError(
      () => api.client.postWithoutData(ApiPaths.login),
    );

    expect(error.type, ApiErrorType.upgradeRequired);
    expect(AppUpdateGate().message.value, 'Lutfen uygulamayi guncelleyin.');
  });
}

/// Verilen zarfı istemciden geçirip ürettiği [ApiErrorType]'ı döndürür.
///
/// Yol olarak [ApiPaths.login] seçildi: `publicPaths` içinde olduğu için
/// `AuthInterceptor` araya girmiyor, ölçülen şey yalnızca sınıflandırma.
Future<ApiErrorType> _typeFor({required int statusCode, String? category}) {
  final api = FakeApi(
    handler: (_) => FakeApiResponse(
      statusCode: statusCode,
      body: {
        'success': false,
        'message': 'Olmadı',
        // `category` null ise alan zarfa **hiç** konmuyor: sunucunun
        // `@JsonInclude(NON_NULL)` davranışının aynısı.
        'errorCategory': ?category,
      },
    ),
  );

  return _captureError(
    () => api.client.postWithoutData(ApiPaths.login),
  ).then((error) => error.type);
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
