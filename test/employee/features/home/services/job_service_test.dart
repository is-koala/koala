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

    test('yakınlık sıralaması lat/lng ve distanceKm okur', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {..._jobBody, 'distanceKm': 3.4},
              ],
            },
          },
        ),
      );

      final result = await JobService.withClient(api.client).search(
        const JobSearchQuery(
          latitude: 41.008238123,
          longitude: 28.978359456,
          sort: JobSortOption.nearest,
        ),
      );

      final query = api.requests.single.queryParameters;
      expect(query['lat'], 41.008238);
      expect(query['lng'], 28.978359);
      expect(query['sort'], 'distance,asc');
      expect(result.jobs.single.distanceKm, 3.4);
    });

    test('başlangıç penceresi Instant olarak gidiyor', () async {
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
        JobSearchQuery(
          startFrom: DateTime.parse('2026-09-14T21:00:00.000Z'),
          startTo: DateTime.parse('2026-09-15T20:59:59.999Z'),
        ),
      );

      final query = api.requests.single.queryParameters;
      expect(query['startFrom'], '2026-09-14T21:00:00.000Z');
      expect(query['startTo'], '2026-09-15T20:59:59.999Z');
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

  group('JobService.fetchByCompany', () {
    test(
      'şirket kimliğini sunucuya gönderip bütün sayfaları koruyor',
      () async {
        final api = FakeApi(
          handler: (request) {
            final page = request.queryParameters['page'] as int;
            final firstIndex = page * 100;
            final itemCount = page == 0 ? 100 : 1;
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': List.generate(itemCount, (index) {
                    final jobIndex = firstIndex + index;
                    return {
                      ..._jobBody,
                      'id': 'job-$jobIndex',
                      'companyName': jobIndex < 100
                          ? 'Aynı Ad'
                          : 'Farklı Sunucu Adı',
                    };
                  }),
                  'page': page,
                  'size': 100,
                  'totalElements': 101,
                  'totalPages': 2,
                  'last': page == 1,
                },
              },
            );
          },
        );

        final jobs = await JobService.withClient(
          api.client,
        ).fetchByCompany('company-7');

        expect(jobs, hasLength(101));
        expect(jobs.first.id, 'job-0');
        expect(jobs.last.id, 'job-100');
        expect(jobs.last.company, 'Farklı Sunucu Adı');
        expect(api.requests, hasLength(2));
        expect(
          api.requests.map((request) => request.path),
          everyElement('/jobs'),
        );
        expect(
          api.requests.map((request) => request.method),
          everyElement('GET'),
        );
        expect(
          api.requests.map((request) => request.queryParameters['companyId']),
          everyElement('company-7'),
        );
        expect(api.requests.map((request) => request.queryParameters['page']), [
          0,
          1,
        ]);
        expect(
          api.requests.map((request) => request.queryParameters['size']),
          everyElement(100),
        );
        expect(
          api.requests.every(
            (request) => !request.queryParameters.containsKey('query'),
          ),
          isTrue,
        );
      },
    );
  });
}
