import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/models/transport_plan_write.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';
import '../../../../support/transport_fixtures.dart';

void main() {
  group('TransportService', () {
    test('fetchPlan işveren görünümünü okur', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': transportPlanJson()},
        ),
      );

      final plan = await TransportService.withClient(
        api.client,
      ).fetchPlan('job-1');

      final request = api.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/jobs/job-1/transport-plan');
      expect(plan.shuttles.single.plate, '34 ABC 12');
    });

    test('fetchPlan planı olmayan ilanda 404 kodunu taşır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Ulaşım planı bulunamadı.',
            'errorCategory': 'RESOURCE_NOT_FOUND',
            'errorCode': 'TRANSPORT_PLAN_NOT_FOUND',
          },
        ),
      );

      await expectLater(
        TransportService.withClient(api.client).fetchPlan('job-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.notFound)
              .having(
                (e) => e.errorCode,
                'errorCode',
                TransportErrorCodes.planNotFound,
              ),
        ),
      );
    });

    test('savePlan PUT gövdesini yazar ve yeni planı döndürür', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': transportPlanJson()},
        ),
      );

      final plan = await TransportService.withClient(api.client).savePlan(
        'job-1',
        const TransportPlanWrite(
          outboundMethod: TransportMethod.shuttle,
          returnMethod: TransportMethod.none,
          shuttles: [
            ShuttleWrite(
              direction: ShuttleDirection.outbound,
              name: 'Servis',
              capacity: 10,
              stops: [],
            ),
          ],
        ),
      );

      final request = api.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/jobs/job-1/transport-plan');
      final body = request.data as Map;
      expect(body['outboundMethod'], 'SHUTTLE');
      expect((body['shuttles'] as List).single['name'], 'Servis');
      expect(plan.id, 'plan-1');
    });

    test('fetchAssignmentTransport atamanın görünümünü okur', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': assignmentTransportJson(seats: [seatJson()]),
          },
        ),
      );

      final transport = await TransportService.withClient(
        api.client,
      ).fetchAssignmentTransport('assignment-1');

      expect(
        api.requests.single.path,
        '/job-assignments/assignment-1/transport',
      );
      expect(transport.seats.single.stopId, 'stop-1');
    });

    test('selectSeat PUT {shuttleId, stopId} gönderir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': assignmentTransportJson(seats: [seatJson()]),
          },
        ),
      );

      final transport = await TransportService.withClient(
        api.client,
      ).selectSeat('assignment-1', shuttleId: 'shuttle-1', stopId: 'stop-1');

      final request = api.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/job-assignments/assignment-1/transport/seat');
      expect(request.data, {'shuttleId': 'shuttle-1', 'stopId': 'stop-1'});
      expect(transport.seatFor(ShuttleDirection.outbound), isNotNull);
    });

    test('selectSeat dolu serviste 409 kodunu taşır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {
            'success': false,
            'message': 'Servisin kapasitesi dolu.',
            'errorCategory': 'DATA_CONFLICT',
            'errorCode': 'TRANSPORT_SHUTTLE_FULL',
          },
        ),
      );

      await expectLater(
        TransportService.withClient(
          api.client,
        ).selectSeat('assignment-1', shuttleId: 'shuttle-1', stopId: 'stop-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.errorCode, 'errorCode', 'TRANSPORT_SHUTTLE_FULL')
              .having((e) => e.message, 'message', 'Servisin kapasitesi dolu.'),
        ),
      );
    });
  });
}
