import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/services/job_template_service.dart';

import '../../../../../support/fake_api.dart';

Map<String, dynamic> templateJson(int index) => {
  'id': 'template-$index',
  'templateName': 'Şablon $index',
  'title': 'Başlık $index',
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
};

BJobTemplatesProvider providerWith(FakeApi api) =>
    BJobTemplatesProvider(service: JobTemplateService.withClient(api.client));

void main() {
  test(
    'şablonlar yükleniyor ve yeni şablon listenin başına ekleniyor',
    () async {
      final api = FakeApi(
        handler: (request) => request.method == 'GET'
            ? FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': [templateJson(1)],
                },
              )
            : FakeApiResponse(
                statusCode: 201,
                body: {'success': true, 'data': templateJson(2)},
              ),
      );
      final provider = providerWith(api);

      await provider.load();
      final created = await provider.createFromJob(
        jobId: 'job-1',
        templateName: 'Şablon 2',
      );

      expect(created, isTrue);
      expect(provider.templates.map((template) => template.id), [
        'template-2',
        'template-1',
      ]);
      expect(provider.hasLoaded, isTrue);
      expect(provider.errorMessage, isNull);
    },
  );

  test('liste alınamazsa hata mesajı yazılıyor ve liste boş kalıyor', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Şablonlar alınamadı.'},
      ),
    );
    final provider = providerWith(api);

    await provider.load();

    expect(provider.templates, isEmpty);
    expect(provider.errorMessage, 'Şablonlar alınamadı.');
    expect(provider.hasLoaded, isTrue);
  });

  test(
    'yetkisi olmayan ilandan şablon çıkarma anlaşılır mesaj veriyor',
    () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Not found',
            'errorCode': 'JOB_TEMPLATE_JOB_NOT_FOUND',
          },
        ),
      );
      final provider = providerWith(api);

      final created = await provider.createFromJob(
        jobId: 'job-1',
        templateName: 'Şablon',
      );

      expect(created, isFalse);
      expect(
        provider.errorMessage,
        'Bu ilandan şablon çıkaramazsınız. Yalnızca kendi ilanlarınızdan '
        'şablon oluşturulabilir.',
      );
    },
  );

  test('silme iyimser: satır hemen kalkıyor', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [templateJson(1), templateJson(2)],
              },
            )
          : const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    final provider = providerWith(api);
    await provider.load();

    final removed = await provider.delete('template-1');

    expect(removed, isTrue);
    expect(provider.templates.map((template) => template.id), ['template-2']);
  });

  test('sunucu silmeyi reddederse satır eski yerine geri geliyor', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [templateJson(1), templateJson(2)],
              },
            )
          : const FakeApiResponse(
              statusCode: 500,
              body: {'success': false, 'message': 'Şablon silinemedi.'},
            ),
    );
    final provider = providerWith(api);
    await provider.load();

    final removed = await provider.delete('template-2');

    expect(removed, isFalse);
    expect(provider.templates.map((template) => template.id), [
      'template-1',
      'template-2',
    ]);
    expect(provider.errorMessage, 'Şablon silinemedi.');
  });

  test('çıkışta liste ve durum temizleniyor', () async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [templateJson(1)],
        },
      ),
    );
    final provider = providerWith(api);
    await provider.load();

    provider.clear();

    expect(provider.templates, isEmpty);
    expect(provider.hasLoaded, isFalse);
    expect(provider.errorMessage, isNull);
  });
}
