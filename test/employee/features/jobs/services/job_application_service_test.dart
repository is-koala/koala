import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('JobApplicationService.fetchMyAssignments', () {
    test('sayfalı yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'asg_1',
                  'status': 'CONFIRMED',
                  'paymentStatus': 'HELD_IN_ESCROW',
                  'workerPayout': 1350,
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
      ).fetchMyAssignments();

      expect(api.requests.single.path, '/users/me/assignments');
      expect(api.requests.single.queryParameters, {'page': 0, 'size': 20});
      expect(page.assignments.single.workerPayout, 1350);
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
      ).fetchMyAssignments();

      expect(page.assignments, isEmpty);
    });
  });
}
