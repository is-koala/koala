import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_boardings_page.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/dispute_evidence_fixtures.dart';
import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const String _secondSeat = '7f1c2d3e-4a5b-4c6d-8e7f-0a1b2c3d4e5f';

FakeApiResponse _data(Object? data) =>
    FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data});

void main() {
  Future<FakeApi> pump(
    WidgetTester tester, {
    FakeApiResponse Function(String method)? mark,
    Brightness brightness = Brightness.light,
  }) async {
    final api = FakeApi(
      handler: (options) {
        if (options.method == 'POST') {
          return mark?.call(options.method) ??
              _data(
                boardingEventJson(
                  source: 'EMPLOYER_MARKED',
                  kind: (options.data as Map)['kind'] as String,
                ),
              );
        }
        return _data([
          boardingRowJson(),
          boardingRowJson(
            seatAssignmentId: _secondSeat,
            firstName: 'Mehmet',
            lastName: 'Kaya',
            boarded: true,
            event: boardingEventJson(
              seatAssignmentId: _secondSeat,
              flags: ['LATE_SYNC'],
            ),
          ),
          boardingRowJson(
            seatAssignmentId: 'seat-3',
            firstName: null,
            lastName: null,
            stopId: 'stop-2',
            stopLabel: 'Üsküdar',
            scheduledAt: '2026-09-20T03:55:00Z',
          ),
        ]);
      },
    );
    await pumpInApp(
      tester,
      BShuttleBoardingsPage(
        shuttleId: shuttleUuid,
        shuttleName: 'Anadolu yakası servisi',
        transportService: TransportService.withClient(api.client),
      ),
      brightness: brightness,
    );
    await tester.pumpAndSettle();
    return api;
  }

  for (final brightness in Brightness.values) {
    testWidgets('liste durak ve saate göre gruplanır (${brightness.name})', (
      tester,
    ) async {
      await pump(tester, brightness: brightness);

      expect(find.text('Anadolu yakası servisi'), findsOne);
      expect(find.text('1/2 bindi'), findsOne);
      expect(find.text('0/1 bindi'), findsOne);
      expect(find.text('Ayşe Yılmaz'), findsOne);
      expect(find.text('Adı olmayan çalışan'), findsOne);
      expect(find.text('Geç gönderildi'), findsOne);
      expect(
        find.byKey(const ValueKey('b-boarding-boarded-$_secondSeat')),
        findsNothing,
        reason: 'binmiş koltukta işaret düğmesi yok',
      );
    });
  }

  testWidgets('elle "Binmedi" işareti token\'sız gider ve satırı günceller', (
    tester,
  ) async {
    final api = await pump(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('b-boarding-no-show-$seatUuid')),
    );
    await tester.tap(
      find.byKey(const ValueKey('b-boarding-no-show-$seatUuid')),
    );
    await tester.pumpAndSettle();

    final post = api.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/seat-assignments/$seatUuid/boardings');
    final body = post.data as Map;
    expect(body['kind'], 'NO_SHOW');
    expect(body.containsKey('token'), isFalse);
    expect(body['clientEventId'], isA<String>());
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('b-boarding-status-$seatUuid')),
          )
          .data,
      'Binmedi',
    );
  });

  testWidgets('binmiş koltuğa NO_SHOW reddi listeyi yeniden okur', (
    tester,
  ) async {
    final api = await pump(
      tester,
      mark: (_) => errorResponse(
        409,
        'TRANSPORT_ALREADY_BOARDED',
        category: 'DATA_CONFLICT',
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('b-boarding-no-show-$seatUuid')),
    );
    await tester.tap(
      find.byKey(const ValueKey('b-boarding-no-show-$seatUuid')),
    );
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.method == 'GET'), hasLength(2));
  });

  testWidgets('yetkisiz ya da olmayan servis tek bir hata ekranı', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => errorResponse(
        404,
        'TRANSPORT_SHUTTLE_NOT_FOUND',
        category: 'RESOURCE_NOT_FOUND',
      ),
    );
    await pumpInApp(
      tester,
      BShuttleBoardingsPage(
        shuttleId: shuttleUuid,
        transportService: TransportService.withClient(api.client),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Biniş listesi yüklenemedi'), findsOne);
    expect(find.byKey(const ValueKey('b-boardings-retry')), findsOne);
  });
}
