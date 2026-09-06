import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/services/job_alert_service.dart';

import '../../../../support/fake_api.dart';

void main() {
  test('iş alarmları düz listeden modele çevrilir', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [
            {
              'id': 'alert-1',
              'alertName': 'Ankara barista',
              'category': {
                'id': 'category-1',
                'name': 'Barista',
                'code': 'BARISTA',
              },
              'cityName': 'Ankara',
              'districtName': 'Çankaya',
              'minSalary': 1250,
              'type': 'ONE_TIME',
              'active': true,
              'lastNotifiedAt': '2026-09-05T18:30:00Z',
            },
          ],
        },
      ),
    );

    final alerts = await JobAlertService.withClient(api.client).fetchAlerts();

    expect(api.requests.single.path, '/users/me/job-alerts');
    expect(alerts.single.name, 'Ankara barista');
    expect(alerts.single.category?.name, 'Barista');
    expect(alerts.single.cityName, 'Ankara');
    expect(alerts.single.minimumSalary, 1250);
    expect(alerts.single.type?.code, 'ONE_TIME');
    expect(alerts.single.isActive, isTrue);
    expect(alerts.single.lastNotifiedAt, DateTime.utc(2026, 9, 5, 18, 30));
  });

  test(
    'alarm ölçütleri backend sözleşmesindeki alanlarla oluşturulur',
    () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'alert-1',
              'alertName': 'Ankara barista',
              'category': {
                'id': 'category-1',
                'name': 'Barista',
                'code': 'BARISTA',
              },
              'cityName': 'Ankara',
              'districtName': 'Çankaya',
              'minSalary': 1250,
              'type': 'ONE_TIME',
              'active': true,
            },
          },
        ),
      );
      const category = JobCategory(
        id: 'category-1',
        name: 'Barista',
        code: 'BARISTA',
      );

      await JobAlertService.withClient(api.client).createAlert(
        const JobAlertDraft(
          name: ' Ankara barista ',
          category: category,
          cityName: 'Ankara',
          districtName: 'Çankaya',
          minimumSalary: 1250,
          type: JobType.oneTime,
        ),
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/job-alerts');
      expect(request.method, 'POST');
      expect(request.data, {
        'alertName': 'Ankara barista',
        'categoryId': 'category-1',
        'cityName': 'Ankara',
        'districtName': 'Çankaya',
        'minSalary': 1250.0,
        'type': 'ONE_TIME',
        'active': true,
      });
    },
  );

  test('yalnızca ilçe seçiliyse istek gönderilmez', () async {
    final api = FakeApi(
      handler: (_) => throw StateError('İstek gönderilmemeliydi'),
    );
    final service = JobAlertService.withClient(api.client);

    await expectLater(
      service.createAlert(
        const JobAlertDraft(name: 'Yakınımdaki işler', districtName: 'Çankaya'),
      ),
      throwsA(
        isA<JobAlertValidationException>().having(
          (error) => error.message,
          'message',
          'İlçe tek başına yeterli değil; kategori, il, tür ya da asgari '
              'ücretten birini de seçin.',
        ),
      ),
    );
    expect(api.requests, isEmpty);
  });

  test('alarm güncelleme ve silme kayıt yolunu kullanır', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'PUT'
          ? const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'id': 'alert-1',
                  'alertName': 'Pasif alarm',
                  'cityName': 'İzmir',
                  'active': false,
                },
              },
            )
          : const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    final service = JobAlertService.withClient(api.client);

    final updated = await service.updateAlert(
      'alert-1',
      const JobAlertDraft(
        name: 'Pasif alarm',
        cityName: 'İzmir',
        isActive: false,
      ),
    );
    await service.deleteAlert('alert-1');

    expect(api.requests.map((request) => request.method), ['PUT', 'DELETE']);
    expect(
      api.requests.map((request) => request.path),
      everyElement('/users/me/job-alerts/alert-1'),
    );
    expect(updated.isActive, isFalse);
    expect(
      (api.requests.first.data as Map<String, dynamic>)['active'],
      isFalse,
    );
  });
}
