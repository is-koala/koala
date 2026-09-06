import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/pages/earnings_page.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/payout_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

Future<void> pumpPage(WidgetTester tester, FakeApi api) {
  final assignmentsApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'content': []},
      },
    ),
  );
  return pumpInApp(
    tester,
    EarningsPage(
      key: UniqueKey(),
      service: PayoutService.withClient(api.client),
      assignmentService: AssignmentService.withClient(assignmentsApi.client),
    ),
  );
}

void main() {
  testWidgets('ilk istek sürerken yükleniyor durumunu gösterir', (
    tester,
  ) async {
    final response = Completer<FakeApiResponse>();
    final api = FakeApi(handler: (_) => response.future);

    await pumpPage(tester, api);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': []},
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('boş liste ve hata birbirinden ayrılır', (tester) async {
    final emptyApi = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': []},
      ),
    );
    await pumpPage(tester, emptyApi);
    await tester.pumpAndSettle();

    expect(find.text('Henüz bir ödeme almadın.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsNothing);

    final failedApi = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Kazançlar alınamadı.'},
      ),
    );
    await pumpPage(tester, failedApi);
    await tester.pumpAndSettle();

    expect(find.text('Kazançlar alınamadı.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.text('Henüz bir ödeme almadın.'), findsNothing);
  });

  testWidgets('durumları, başarısızlık sebebini ve kesin toplamları gösterir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [
            {
              'id': 'completed-1',
              'jobAssignmentId': 'assignment-1',
              'amount': '1000.10',
              'currency': 'TRY',
              'status': 'COMPLETED',
              'completedAt': '2026-09-06T12:05:00Z',
              'createdAt': '2026-09-06T12:00:00Z',
            },
            {
              'id': 'completed-2',
              'jobAssignmentId': 'assignment-2',
              'amount': '249.90',
              'currency': 'TRY',
              'status': 'COMPLETED',
              'completedAt': '2026-09-05T12:05:00Z',
              'createdAt': '2026-09-05T12:00:00Z',
            },
            {
              'id': 'processing',
              'jobAssignmentId': 'assignment-3',
              'amount': '20.15',
              'currency': 'TRY',
              'status': 'PROCESSING',
              'createdAt': '2026-09-04T12:00:00Z',
            },
            {
              'id': 'pending',
              'jobAssignmentId': 'assignment-4',
              'amount': '10.05',
              'currency': 'TRY',
              'status': 'PENDING',
              'createdAt': '2026-09-03T12:00:00Z',
            },
            {
              'id': 'failed',
              'jobAssignmentId': 'assignment-5',
              'amount': '99.99',
              'currency': 'TRY',
              'status': 'FAILED',
              'failureReason': 'Banka hesabı doğrulanamadı.',
              'createdAt': '2026-09-02T12:00:00Z',
            },
          ],
        },
      ),
    );

    await pumpPage(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Tamamlanan'), findsWidgets);
    expect(find.text('1.250,00 ₺'), findsOneWidget);
    expect(find.text('Bekleyen / işlenen'), findsOneWidget);
    expect(find.text('30,20 ₺'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsNWidgets(2));
    expect(find.text('İşleniyor'), findsOneWidget);
    expect(find.text('Bekliyor'), findsOneWidget);
    expect(find.text('Başarısız'), findsOneWidget);
    expect(find.text('Banka hesabı doğrulanamadı.'), findsOneWidget);
    expect(find.text('99,99 ₺'), findsOneWidget);
  });
}
