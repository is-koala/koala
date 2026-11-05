import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/pages/worker_boarding_qr_page.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_qr_view.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/dispute_evidence_fixtures.dart';
import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

void main() {
  Future<FakeApi> pump(
    WidgetTester tester, {
    required FakeApiResponse Function() respond,
    Brightness brightness = Brightness.light,
  }) async {
    final api = FakeApi(handler: (_) => respond());
    await pumpInApp(
      tester,
      WorkerBoardingQrPage(
        assignmentId: 'asg-1',
        direction: ShuttleDirection.outbound,
        transportService: TransportService.withClient(api.client),
      ),
      brightness: brightness,
    );
    await tester.pumpAndSettle();
    return api;
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'işçinin QR\'ı yönüyle istenir ve çizilir (${brightness.name})',
      (tester) async {
        final api = await pump(
          tester,
          brightness: brightness,
          respond: () => FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': boardingQrJson(token: workerTokenValue),
            },
          ),
        );

        final request = api.requests.single;
        expect(request.path, '/job-assignments/asg-1/transport/qr');
        expect(request.queryParameters, {'direction': 'OUTBOUND'});
        expect(find.byType(BoardingQrView), findsOne);
        expect(find.text('Gidiş servisi'), findsOne);
        expect(find.text(WorkerBoardingQrPage.brightnessTip), findsOne);
      },
    );
  }

  testWidgets('koltuk seçilmemişse nedeni ve tekrar dene', (tester) async {
    await pump(
      tester,
      respond: () => errorResponse(
        409,
        'TRANSPORT_SEAT_NOT_SELECTED',
        category: 'DATA_CONFLICT',
      ),
    );

    expect(find.byKey(const ValueKey('worker-boarding-qr-error')), findsOne);
    expect(
      find.text(BoardingFailure.seatNotSelected.message(BoardingActor.worker)),
      findsOne,
    );
    expect(find.byType(BoardingQrView), findsNothing);
  });

  testWidgets('başkasının ataması 404: QR alınamadı denir', (tester) async {
    await pump(
      tester,
      respond: () => errorResponse(
        404,
        'JOB_ASSIGNMENT_NOT_FOUND',
        category: 'RESOURCE_NOT_FOUND',
      ),
    );

    expect(find.textContaining('biniş QR\'ı alınamadı'), findsOne);
  });
}
