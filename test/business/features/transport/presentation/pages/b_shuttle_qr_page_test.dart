import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_qr_page.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_qr_view.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

FakeApiResponse _data(Object? data) =>
    FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data});

void main() {
  Future<FakeApi> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final api = FakeApi(
      handler: (options) {
        final isStatic = options.queryParameters['static'] == true;
        return _data(
          isStatic
              ? boardingQrJson(isStatic: true, refreshAt: null, expiresAt: null)
              : boardingQrJson(),
        );
      },
    );
    await pumpInApp(
      tester,
      BShuttleQrPage(
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
    testWidgets('dönen QR açılır, basılıya geçilince static istenir '
        '(${brightness.name})', (tester) async {
      final api = await pump(tester, brightness: brightness);

      expect(api.requests.single.queryParameters, {'static': false});
      expect(find.byType(BoardingQrView), findsOne);
      expect(find.text(BShuttleQrPage.rotatingNote), findsOne);

      await tester.tap(find.byKey(const ValueKey('b-shuttle-qr-mode-static')));
      await tester.pumpAndSettle();

      expect(api.requests.last.queryParameters, {'static': true});
      expect(find.text(BShuttleQrPage.staticNote), findsOne);
    });
  }

  testWidgets('QR yenileme onaysız gitmez', (tester) async {
    final api = await pump(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('b-shuttle-qr-rotate')),
    );
    await tester.tap(find.byKey(const ValueKey('b-shuttle-qr-rotate')));
    await tester.pumpAndSettle();
    expect(find.text(BShuttleQrPage.rotateMessage), findsOne);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('onaylanan yenileme POST eder ve yeni QR\'ı gösterir', (
    tester,
  ) async {
    final api = await pump(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('b-shuttle-qr-rotate')),
    );
    await tester.tap(find.byKey(const ValueKey('b-shuttle-qr-rotate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yenile'));
    await tester.pumpAndSettle();

    final post = api.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/shuttles/$shuttleUuid/qr/rotate');
    expect(find.byType(BoardingQrView), findsOne);
  });
}
