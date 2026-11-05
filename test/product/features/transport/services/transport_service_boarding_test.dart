import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/boarding_fixtures.dart';
import '../../../../support/fake_api.dart';

FakeApiResponse _data(Object? data) =>
    FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data});

void main() {
  group('TransportService biniş uçları (koala-backend#298)', () {
    test('işçi QR\'ı yönle istenir', () async {
      final api = FakeApi(handler: (_) => _data(boardingQrJson()));

      final qr = await TransportService.withClient(
        api.client,
      ).fetchWorkerQr('asg-1', direction: ShuttleDirection.returnTrip);

      final request = api.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/job-assignments/asg-1/transport/qr');
      expect(request.queryParameters, {'direction': 'RETURN'});
      expect(qr.token, shuttleTokenValue);
    });

    test('servis QR\'ı static bayrağıyla, yenileme POST ile', () async {
      final api = FakeApi(
        handler: (_) => _data(boardingQrJson(isStatic: true)),
      );
      final service = TransportService.withClient(api.client);

      await service.fetchShuttleQr(shuttleUuid, isStatic: true);
      await service.rotateShuttleQr(shuttleUuid);

      expect(api.requests[0].path, '/shuttles/$shuttleUuid/qr');
      expect(api.requests[0].queryParameters, {'static': true});
      expect(api.requests[1].method, 'POST');
      expect(api.requests[1].path, '/shuttles/$shuttleUuid/qr/rotate');
    });

    test('servis binişi gövdesi sözleşmeye birebir uyar', () async {
      final api = FakeApi(handler: (_) => _data(boardingEventJson()));

      final event = await TransportService.withClient(api.client)
          .boardOnShuttle(
            shuttleUuid,
            token: shuttleTokenValue,
            capturedAt: DateTime.utc(2026, 9, 20, 3, 41, 5),
            clientEventId: 'cid-1',
            latitude: 40.987654321,
            longitude: 29.0261234567,
          );

      final request = api.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/shuttles/$shuttleUuid/boardings');
      expect(request.data, {
        'token': shuttleTokenValue,
        'capturedAt': '2026-09-20T03:41:05.000Z',
        'latitude': 40.987654,
        'longitude': 29.026123,
        'clientEventId': 'cid-1',
      });
      expect(event.kind, BoardingKind.boarded);
    });

    test('yarım konum hiç gönderilmez', () async {
      final api = FakeApi(handler: (_) => _data(boardingEventJson()));

      await TransportService.withClient(api.client).boardOnShuttle(
        shuttleUuid,
        token: shuttleTokenValue,
        capturedAt: DateTime.utc(2026, 9, 20, 3, 41),
        clientEventId: 'cid-1',
        latitude: 40.9,
      );

      final body = api.requests.single.data as Map<String, Object?>;
      expect(body.containsKey('latitude'), isFalse);
      expect(body.containsKey('longitude'), isFalse);
    });

    test('işveren işaretlemesi token\'sız, okutma token\'lı gider', () async {
      final api = FakeApi(handler: (_) => _data(boardingEventJson()));
      final service = TransportService.withClient(api.client);

      await service.markSeatBoarding(
        seatUuid,
        clientEventId: 'cid-2',
        kind: BoardingKind.noShow,
      );
      await service.markSeatBoarding(
        seatUuid,
        clientEventId: 'cid-3',
        token: workerTokenValue,
        capturedAt: DateTime.utc(2026, 9, 20, 3, 42),
      );

      expect(api.requests[0].path, '/seat-assignments/$seatUuid/boardings');
      expect(api.requests[0].data, {
        'clientEventId': 'cid-2',
        'kind': 'NO_SHOW',
      });
      expect(api.requests[1].data, {
        'token': workerTokenValue,
        'capturedAt': '2026-09-20T03:42:00.000Z',
        'clientEventId': 'cid-3',
      });
    });

    test('biniş listesi okunur', () async {
      final api = FakeApi(
        handler: (_) => _data([
          boardingRowJson(),
          boardingRowJson(
            seatAssignmentId: 'seat-2',
            boarded: true,
            event: boardingEventJson(seatAssignmentId: 'seat-2'),
          ),
        ]),
      );

      final rows = await TransportService.withClient(
        api.client,
      ).fetchShuttleBoardings(shuttleUuid);

      expect(api.requests.single.path, '/shuttles/$shuttleUuid/boardings');
      expect(rows, hasLength(2));
      expect(rows.last.boarded, isTrue);
    });

    test('hata kodu ApiException.errorCode ile taşınır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {
            'success': false,
            'message': 'Bu servis size ayrılan servis değil.',
            'errorCategory': 'DATA_CONFLICT',
            'errorCode': 'TRANSPORT_WRONG_SHUTTLE',
          },
        ),
      );

      await expectLater(
        TransportService.withClient(api.client).boardOnShuttle(
          shuttleUuid,
          token: shuttleTokenValue,
          capturedAt: DateTime.utc(2026, 9, 20),
          clientEventId: 'cid-1',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            TransportErrorCodes.wrongShuttle,
          ),
        ),
      );
    });
  });
}
