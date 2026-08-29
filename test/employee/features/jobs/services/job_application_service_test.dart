import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('JobApplicationService.fetchMyApplications', () {
    test('sayfalı yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'app_1',
                  'status': 'PENDING',
                  'job': {
                    'id': 'job_1',
                    'title': 'Garson',
                    'category': {
                      'id': 'c',
                      'code': 'WAITER',
                      'name': 'Garsonluk',
                    },
                    'salary': 1500,
                  },
                },
              ],
              'totalElements': 1,
              'last': true,
            },
          },
        ),
      );

      final page = await JobApplicationService.withClient(
        api.client,
      ).fetchMyApplications();

      expect(api.requests.single.path, '/users/me/applications');
      expect(page.applications.single.id, 'app_1');
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

      final page = await JobApplicationService.withClient(
        api.client,
      ).fetchMyApplications();

      expect(page.applications, isEmpty);
    });
  });
}
