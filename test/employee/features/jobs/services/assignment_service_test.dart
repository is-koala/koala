import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('AssignmentService.fetchMyAssignments', () {
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

      final page = await AssignmentService.withClient(
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

      final page = await AssignmentService.withClient(
        api.client,
      ).fetchMyAssignments();

      expect(page.assignments, isEmpty);
    });
  });

  group('AssignmentService.respond', () {
    test('kabul cevabı doğru yola ve gövdeyle gider', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'asg_1', 'status': 'CONFIRMED'},
          },
        ),
      );

      final status = await AssignmentService.withClient(
        api.client,
      ).respond(assignmentId: 'asg_1', accepted: true);

      final request = api.requests.single;
      expect(request.path, '/job-assignments/asg_1/respond');
      expect(request.method, 'POST');
      expect(request.data, {'accepted': true});
      expect(status, AssignmentStatus.confirmed);
    });

    test('ret cevabı REJECTED döndürür', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'asg_1', 'status': 'REJECTED'},
          },
        ),
      );

      final status = await AssignmentService.withClient(
        api.client,
      ).respond(assignmentId: 'asg_1', accepted: false);

      expect(api.requests.single.data, {'accepted': false});
      expect(status, AssignmentStatus.rejected);
    });

    test('atama cevaplanabilir durumda değilse 409 yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Atama bu durumdan cevaplanamaz'},
        ),
      );

      await expectLater(
        AssignmentService.withClient(
          api.client,
        ).respond(assignmentId: 'asg_1', accepted: true),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.conflict,
          ),
        ),
      );
    });
  });
}
