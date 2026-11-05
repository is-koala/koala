import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_scan_page.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_result_panel.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/services/device_location_source.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/dispute_evidence_fixtures.dart';
import '../../../../../support/fake_api.dart';

FakeApiResponse _data(Object? data) =>
    FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final token = BoardingToken.fromValue(workerTokenValue)!;
  final capturedAt = DateTime.utc(2026, 9, 20, 3, 42);

  Future<(BoardingResultPanel, FakeApi, FakeDeviceLocationSource)> record({
    FakeApiResponse? response,
    Map<String, String> names = const {seatUuid: 'Ayşe Yılmaz'},
    String? shuttleId = shuttleUuid,
  }) async {
    final api = FakeApi(
      handler: (_) =>
          response ??
          _data(boardingEventJson(source: 'EMPLOYER_SCANNED_WORKER_QR')),
    );
    final location = FakeDeviceLocationSource(
      granted: const LatLng(40.98, 29.02),
    );
    final panel = await BShuttleScanPage.record(
      service: TransportService.withClient(api.client),
      location: location,
      token: token,
      capturedAt: capturedAt,
      shuttleId: shuttleId,
      names: names,
    );
    return (panel, api, location);
  }

  test('çalışan QR\'ı token, okutma anı ve taze konumla gider', () async {
    final (panel, api, location) = await record();

    final body = api.requests.single.data as Map;
    expect(api.requests.single.path, '/seat-assignments/$seatUuid/boardings');
    expect(body['token'], workerTokenValue);
    expect(body['capturedAt'], '2026-09-20T03:42:00.000Z');
    expect(body['latitude'], 40.98);
    expect(body.containsKey('kind'), isFalse);
    expect(location.lastMaxAge, boardingLocationMaxAge);
    expect(panel.tone, BoardingResultTone.success);
    expect(panel.message, 'Ayşe Yılmaz bindi.');
  });

  test('bu servisin listesinde olmayan koltuk uyarıyla yazılır', () async {
    final (panel, _, _) = await record(names: const {'seat-x': 'Başkası'});

    expect(panel.tone, BoardingResultTone.warning);
    expect(panel.message, contains('bu servisin listesinde yok'));
  });

  test('olay başka servise yazıldıysa ad ve uyarı', () async {
    final (panel, _, _) = await record(
      response: _data({
        ...boardingEventJson(source: 'EMPLOYER_SCANNED_WORKER_QR'),
        'shuttleId': 'aaaaaaaa-0000-4000-8000-000000000000',
      }),
    );

    expect(panel.tone, BoardingResultTone.warning);
    expect(panel.message, 'Ayşe Yılmaz bindi, ama koltuğu başka bir serviste.');
  });

  test('bağlantıdan (servis bilinmeden) okutmada uyarı yok', () async {
    final (panel, _, _) = await record(shuttleId: null, names: const {});

    expect(panel.tone, BoardingResultTone.success);
    expect(panel.message, 'Biniş kaydedildi.');
  });

  test('süresi dolmuş QR işverene uygun cümleyle', () async {
    final (panel, _, _) = await record(
      response: errorResponse(
        400,
        'TRANSPORT_TOKEN_EXPIRED',
        category: 'VALIDATION_FAILED',
      ),
    );

    expect(panel.tone, BoardingResultTone.failure);
    expect(
      panel.message,
      BoardingFailure.tokenExpired.message(BoardingActor.employer),
    );
  });
}
