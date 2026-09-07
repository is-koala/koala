import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

Map<String, dynamic> get _jobBody => {
  'id': 'job-1',
  'title': 'Garson',
  'position': 'Hafta sonu garson',
  'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 800,
  'status': 'OPEN',
  'latitude': 39.9,
  'longitude': 32.8,
};

void main() {
  group('JobService.search', () {
    test('sayfalı yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [_jobBody],
              'page': 0,
              'size': 20,
              'totalElements': 1,
              'totalPages': 1,
              'first': true,
              'last': true,
            },
          },
        ),
      );

      final result = await JobService.withClient(
        api.client,
      ).search(const JobSearchQuery());

      expect(api.requests.single.path, '/jobs');
      expect(result.jobs.single.title, 'Garson');
      expect(result.totalElements, 1);
      expect(result.last, isTrue);
    });

    test('sayfa parametreleri her zaman gönderilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      await JobService.withClient(api.client).search(const JobSearchQuery());

      expect(api.requests.single.queryParameters, {'page': 0, 'size': 20});
    });

    test('verilmeyen süzgeç sorguya konmaz', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      await JobService.withClient(api.client).search(
        const JobSearchQuery(
          query: 'garson',
          categoryId: 'cat-1',
          type: JobType.recurring,
        ),
      );

      expect(api.requests.single.queryParameters, {
        'query': 'garson',
        'categoryId': 'cat-1',
        'type': 'RECURRING',
        'page': 0,
        'size': 20,
      });
    });

    test('harita sınır kutusu sorguya eklenir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      await JobService.withClient(api.client).search(
        const JobSearchQuery(
          bounds: JobMapBounds(
            minLatitude: 39.8,
            maxLatitude: 40.0,
            minLongitude: 32.7,
            maxLongitude: 32.9,
          ),
        ),
      );

      final query = api.requests.single.queryParameters;
      expect(query['minLatitude'], 39.8);
      expect(query['maxLongitude'], 32.9);
    });

    test('sayfa ve boyut çağıranın verdiği gibi gidiyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      await JobService.withClient(
        api.client,
      ).search(const JobSearchQuery(), page: 2, size: 100);

      final query = api.requests.single.queryParameters;
      expect(query['page'], 2);
      expect(query['size'], 100);
    });

    test('sıralama sorgu modelinden geliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      await JobService.withClient(
        api.client,
      ).search(const JobSearchQuery(sort: JobSortOption.salaryDesc));

      expect(api.requests.single.queryParameters['sort'], 'salary,desc');
    });

    test('boş sayfa hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      final result = await JobService.withClient(
        api.client,
      ).search(const JobSearchQuery());

      expect(result.jobs, isEmpty);
    });
  });

  group('JobService.getById', () {
    test('detay modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              ..._jobBody,
              'description': 'Hafta sonu garson aranıyor.',
              'duties': 'Servis, kasa',
            },
          },
        ),
      );

      final detail = await JobService.withClient(api.client).getById('job-1');

      expect(api.requests.single.path, '/jobs/job-1');
      expect(detail.description, 'Hafta sonu garson aranıyor.');
      expect(detail.duties, 'Servis, kasa');
    });

    test('bulunamayan ilan ApiException olarak yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {'success': false, 'message': 'İlan bulunamadı'},
        ),
      );

      expect(
        () => JobService.withClient(api.client).getById('yok'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'İlan bulunamadı')
              .having((e) => e.type, 'type', ApiErrorType.notFound),
        ),
      );
    });
  });
}
