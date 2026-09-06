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
}
