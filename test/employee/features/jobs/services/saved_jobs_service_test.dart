import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/services/saved_jobs_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('SavedJobsService.fetchSavedJobs', () {
    // Liste ucu sayfalı değil: backend düz dizi döndürüyor.
    test('düz dizi modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'job_1',
                'title': 'Garson',
                'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garsonluk'},
                'salary': 800,
              },
            ],
          },
        ),
      );

      final jobs = await SavedJobsService.withClient(
        api.client,
      ).fetchSavedJobs();

      expect(api.requests.single.path, '/users/me/saved-jobs');
      expect(jobs.single.title, 'Garson');
    });

    test('boş liste hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      expect(
        await SavedJobsService.withClient(api.client).fetchSavedJobs(),
        isEmpty,
      );
    });
  });

  group('SavedJobsService.save / remove', () {
    test('kaydetme POST, kaldırma DELETE', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );
      final service = SavedJobsService.withClient(api.client);

      await service.save('job_1');
      await service.remove('job_1');

      expect(api.requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(
        api.requests.map((r) => r.path),
        everyElement('/users/me/saved-jobs/job_1'),
      );
    });

    test('oturum düşmüşse ApiException', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 401,
          body: {'success': false, 'message': 'Oturum bulunamadı'},
        ),
      );

      expect(
        () => SavedJobsService.withClient(api.client).save('job_1'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
