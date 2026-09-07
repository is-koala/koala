import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/employee/features/jobs/services/job_alert_service.dart';

import '../../../../../support/fake_api.dart';

Map<String, dynamic> alertJson(int index, {bool active = true}) => {
  'id': 'alert-$index',
  'alertName': 'Alarm $index',
  'cityName': 'Ankara',
  'active': active,
};

JobAlertsProvider providerWith(FakeApi api) =>
    JobAlertsProvider(service: JobAlertService.withClient(api.client));

/// Sunucunun hata zarfı.
///
/// `errorCode` **hiçbir zaman boş gelmiyor**: `ErrorResult:20` boş bırakılanı
/// kategori adıyla dolduruyor, yani alan doğrulamalarının hepsi tek tip
/// `VALIDATION_FAILED` taşıyor (`ErrorContractIT:137` bunu sabitliyor).
/// Kotanın kendi kodu var; alan hatalarını ancak `details` ayırıyor.
///
/// `errorCategory` zarfa gerçeğe sadık kalsın diye konuyor; bugünkü
/// `ApiResponse.fromJson` onu **okumuyor**, yani hiçbir iddia ona dayanmıyor.
FakeApiResponse errorResponse({
  required int statusCode,
  required String message,
  String? errorCode,
  List<Map<String, dynamic>>? details,
}) => FakeApiResponse(
  statusCode: statusCode,
  body: {
    'success': false,
    'message': message,
    'errorCode': errorCode,
    'errorCategory': statusCode == 404
        ? 'RESOURCE_NOT_FOUND'
        : 'VALIDATION_FAILED',
    'details': ?details,
  },
);

/// Yerel ön koşulları geçen, sunucuya gerçekten çıkan bir taslak.
const validDraft = JobAlertDraft(name: 'Ankara garson', cityName: 'Ankara');

void main() {
  test('alarmlar yüklenir ve yeni alarm listenin başına eklenir', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [alertJson(1)],
              },
            )
          : FakeApiResponse(
              statusCode: 201,
              body: {'success': true, 'data': alertJson(2)},
            ),
    );
    final provider = providerWith(api);

    await provider.load();
    final saved = await provider.create(
      const JobAlertDraft(name: 'Alarm 2', cityName: 'Ankara'),
    );

    expect(saved, isTrue);
    expect(provider.alerts.map((alert) => alert.id), ['alert-2', 'alert-1']);
    expect(provider.hasLoaded, isTrue);
    expect(provider.errorMessage, isNull);
  });

  test('on alarma ulaşıldığında yeni istek gönderilmez', () async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': List.generate(10, alertJson)},
      ),
    );
    final provider = providerWith(api);
    await provider.load();

    final saved = await provider.create(
      const JobAlertDraft(name: 'On birinci', cityName: 'Ankara'),
    );

    expect(saved, isFalse);
    expect(api.requests, hasLength(1));
    expect(provider.errorMessage, 'En fazla 10 iş alarmı oluşturabilirsiniz.');
  });

  // Sunucudan gelen kota reddi bugüne kadar hiç testten geçmiyordu; yerel
  // sayaç (`canCreate`) bayat olduğunda görülen tek yol bu.
  //
  // Kaynakta kota **çakışma değil**: `JobAlertManager.createAlert`
  // `ValidationException(TOO_MANY)` atıyor, yani `400` + `VALIDATION_FAILED`
  // + `errorCode: JOB_ALERT_TOO_MANY`. Alan doğrulaması da aynı kategoriyle
  // geldiği için ayrımı yapan tek şey kod.
  test('sunucunun kota reddi kota mesajını basar', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': []},
            )
          : const FakeApiResponse(
              statusCode: 400,
              body: {
                'success': false,
                'message': 'Daha fazla iş alarmı oluşturamazsınız.',
                'errorCode': 'JOB_ALERT_TOO_MANY',
                'errorCategory': 'VALIDATION_FAILED',
              },
            ),
    );
    final provider = providerWith(api);
    await provider.load();

    final saved = await provider.create(
      const JobAlertDraft(name: 'Alarm', cityName: 'Ankara'),
    );

    expect(saved, isFalse);
    expect(provider.errorMessage, 'En fazla 10 iş alarmı oluşturabilirsiniz.');
  });

  // Aynı kategori, farklı kod: ölçüt doğrulaması kota mesajını basmamalı.
  // Kod yerine kategoriye bakılsaydı ikisi de aynı cümleyi verirdi.
  test('aynı kategorideki alan doğrulaması kota mesajı basmaz', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': []},
            )
          : const FakeApiResponse(
              statusCode: 400,
              body: {
                'success': false,
                'message': 'Doğrulama hatası.',
                'errorCode': 'VALIDATION_FAILED',
                'errorCategory': 'VALIDATION_FAILED',
                'details': [
                  {'field': 'alertName', 'message': 'Alarm adı zorunludur.'},
                ],
              },
            ),
    );
    final provider = providerWith(api);
    await provider.load();

    await provider.create(
      const JobAlertDraft(name: 'Alarm', cityName: 'Ankara'),
    );

    expect(provider.errorMessage, 'Alarm için en az bir geçerli ölçüt seçin.');
  });

  // Kaynağa göre bu uçlar çakışma üretmiyor; yine de biri gelirse uydurulmuş
  // bir kota cümlesi değil sunucunun kendi metni gösterilmeli.
  test('çakışma gelirse sunucunun kendi metni gösterilir', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': []},
            )
          : const FakeApiResponse(
              statusCode: 409,
              body: {
                'success': false,
                'message': 'Bu alarm başka bir işlemde kilitli.',
                'errorCode': 'JOB_ALERT_LOCKED',
                'errorCategory': 'BUSINESS_RULE_VIOLATION',
              },
            ),
    );
    final provider = providerWith(api);
    await provider.load();

    await provider.create(
      const JobAlertDraft(name: 'Alarm', cityName: 'Ankara'),
    );

    expect(provider.errorMessage, 'Bu alarm başka bir işlemde kilitli.');
  });

  test('yalnızca ilçe seçiliyse istek gönderilmez', () async {
    final api = FakeApi(
      handler: (_) => throw StateError('İstek gönderilmemeliydi'),
    );
    final provider = providerWith(api);

    final saved = await provider.create(
      const JobAlertDraft(name: 'Yakınımdaki işler', districtName: 'Çankaya'),
    );

    expect(saved, isFalse);
    expect(api.requests, isEmpty);
    expect(
      provider.errorMessage,
      'İlçe tek başına yeterli değil; kategori, il, tür ya da asgari '
      'ücretten birini de seçin.',
    );
  });

  test('aktiflik güncellenir ve silinen alarm listeden kalkar', () async {
    final api = FakeApi(
      handler: (request) {
        if (request.method == 'GET') {
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [alertJson(1)],
            },
          );
        }
        if (request.method == 'PUT') {
          return FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': alertJson(1, active: false)},
          );
        }
        return const FakeApiResponse(statusCode: 200, body: {'success': true});
      },
    );
    final provider = providerWith(api);
    await provider.load();

    final updated = await provider.update(
      'alert-1',
      const JobAlertDraft(name: 'Alarm 1', cityName: 'Ankara', isActive: false),
    );
    final removed = await provider.delete('alert-1');

    expect(updated, isTrue);
    expect(removed, isTrue);
    expect(provider.alerts, isEmpty);
    expect(api.requests.map((request) => request.method), [
      'GET',
      'PUT',
      'DELETE',
    ]);
  });

  test('silme reddedilirse alarm eski yerinde kalır', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [alertJson(1)],
              },
            )
          : const FakeApiResponse(
              statusCode: 500,
              body: {'success': false, 'message': 'Alarm silinemedi.'},
            ),
    );
    final provider = providerWith(api);
    await provider.load();

    final removed = await provider.delete('alert-1');

    expect(removed, isFalse);
    expect(provider.alerts.single.id, 'alert-1');
    expect(provider.errorMessage, 'Alarm silinemedi.');
  });

  test('çıkış temizliği önceki kullanıcının alarmlarını düşürür', () async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [alertJson(1)],
        },
      ),
    );
    final provider = providerWith(api);
    await provider.load();

    provider.clear();

    expect(provider.alerts, isEmpty);
    expect(provider.hasLoaded, isFalse);
  });

  test('çıkıştan sonra tamamlanan eski istek listeyi geri doldurmaz', () async {
    final response = Completer<FakeApiResponse>();
    final api = FakeApi(handler: (_) => response.future);
    final provider = providerWith(api);

    final load = provider.load();
    await Future<void>.delayed(Duration.zero);
    provider.clear();
    response.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [alertJson(1)],
        },
      ),
    );
    await load;

    expect(provider.alerts, isEmpty);
    expect(provider.hasLoaded, isFalse);
    expect(provider.isLoading, isFalse);
  });

  // Bu dört testin tamamı `_messageFor`'un yönlendirmesini sabitliyor.
  // AGENTS.md: "ApiException.errorCode is what routing keys off, never the
  // message text."
  // Bu grubun tamamı `_messageFor`'un yönlendirmesini sabitliyor.
  // AGENTS.md: "ApiException.errorCode is what routing keys off, never the
  // message text."
  group('sunucu hatası doğru mesaja yönleniyor', () {
    test('kota aşımı ölçüt mesajını değil kendi mesajını gösterir', () async {
      // Sunucu kotayı `ValidationException` ile döndürüyor
      // (`JobAlertManager:57`): HTTP **400**, 409 değil. Yani durum kodu ve
      // `ApiErrorType` bunu ölçüt hatasından ayıramıyor; ayıran `errorCode`.
      final api = FakeApi(
        handler: (request) => errorResponse(
          statusCode: 400,
          message: 'Daha fazla iş alarmı oluşturamazsınız.',
          errorCode: 'JOB_ALERT_TOO_MANY',
        ),
      );
      final provider = providerWith(api);

      // Yerel kota koruması listeyi sayıyor; liste boşken istek gerçekten
      // çıkıyor ve kotayı sunucu söylüyor (başka cihazda alarm açılmış olabilir).
      expect(provider.canCreate, isTrue);
      expect(await provider.create(validDraft), isFalse);

      expect(
        provider.errorMessage,
        'En fazla ${JobAlertsProvider.maximumAlertCount} iş alarmı oluşturabilirsiniz.',
      );
    });

    test('ölçüt eksikliği sunucunun kendi alan metnini gösterir', () async {
      // Alan doğrulamalarının hepsi `VALIDATION_FAILED` koduna düşüyor
      // (`ErrorResult:20` boş kodu kategori adıyla dolduruyor), o yüzden kod
      // bunları ayıramaz; ayıran `details`.
      final api = FakeApi(
        handler: (request) => errorResponse(
          statusCode: 400,
          message: 'Gönderdiğiniz bilgilerde hata var.',
          errorCode: 'VALIDATION_FAILED',
          details: [
            // Alan adını Hibernate Validator türetiyor: `has` öneki düşüyor,
            // `hasAtLeastOneCriterion()` → `atLeastOneCriterion`.
            {
              'field': 'atLeastOneCriterion',
              'message': 'En az bir kriter belirtilmelidir.',
            },
          ],
        ),
      );
      final provider = providerWith(api);

      expect(await provider.create(validDraft), isFalse);

      expect(provider.errorMessage, 'En az bir kriter belirtilmelidir.');
    });

    test('boş ad hatası ölçüt mesajına düşmez', () async {
      // `SaveJobAlertDto:23` `@NotBlank`. Ölçüt hatasıyla aynı durum kodunu ve
      // aynı `errorCode`'u taşıyor; yalnız `details` farklı.
      final api = FakeApi(
        handler: (request) => errorResponse(
          statusCode: 400,
          message: 'Gönderdiğiniz bilgilerde hata var.',
          errorCode: 'VALIDATION_FAILED',
          details: [
            {'field': 'alertName', 'message': 'Alarm adı gereklidir.'},
          ],
        ),
      );
      final provider = providerWith(api);

      expect(await provider.create(validDraft), isFalse);

      expect(provider.errorMessage, 'Alarm adı gereklidir.');
    });

    test(
      'ölçütle ilgisi olmayan alan hatası da kendi metnini gösterir',
      () async {
        // Ölçüt metnini yedek yapan eski hâl `cityName` gibi bambaşka bir alan
        // hatasında da "en az bir geçerli ölçüt seçin" yazıyordu.
        final api = FakeApi(
          handler: (request) => errorResponse(
            statusCode: 400,
            message: 'Gönderdiğiniz bilgilerde hata var.',
            errorCode: 'VALIDATION_FAILED',
            details: [
              {
                'field': 'cityName',
                'message': 'Şehir adı en fazla 255 karakter olabilir.',
              },
            ],
          ),
        );
        final provider = providerWith(api);

        expect(await provider.create(validDraft), isFalse);

        expect(
          provider.errorMessage,
          'Şehir adı en fazla 255 karakter olabilir.',
        );
      },
    );

    test('silinmiş alarm, sunucunun kendi 404 metnine düşmüyor', () async {
      // `JobAlertManager:160`. Bu dal eski `ApiErrorType.notFound` dalının
      // yerini aldı; sabiti yanlış yazmak testlerden kaçmamalı.
      final api = FakeApi(
        handler: (request) => request.method == 'GET'
            ? FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': [alertJson(1)],
                },
              )
            : errorResponse(
                statusCode: 404,
                message: 'İş alarmı bulunamadı.',
                errorCode: 'JOB_ALERT_NOT_FOUND',
              ),
      );
      final provider = providerWith(api);
      await provider.load();

      expect(await provider.delete('alert-1'), isFalse);

      // Sunucunun kendi metni yalnız "İş alarmı bulunamadı." — ne yapılacağını
      // söylemiyor. Yedeğe düşülseydi bu görünürdü.
      expect(
        provider.errorMessage,
        'İş alarmı bulunamadı. Listeyi yenileyip tekrar deneyin.',
      );
      expect(provider.alerts.single.id, 'alert-1');
    });

    test('kategori bulunamadı, alarm bulunamadı sanılmıyor', () async {
      // `JobAlertManager:177` kategoriyi `JobCategoryManager:59` ile çözüyor:
      // aynı 404, ama kullanıcıya "listeyi yenile" demek yanlış yönlendirme.
      final api = FakeApi(
        handler: (request) => errorResponse(
          statusCode: 404,
          message: 'Kategori bulunamadı.',
          errorCode: 'JOB_ALERT_CATEGORY_NOT_FOUND',
        ),
      );
      final provider = providerWith(api);

      expect(await provider.create(validDraft), isFalse);

      expect(
        provider.errorMessage,
        'Seçtiğiniz kategori artık yok. Ölçütleri güncelleyip tekrar deneyin.',
      );
    });
  });
}
