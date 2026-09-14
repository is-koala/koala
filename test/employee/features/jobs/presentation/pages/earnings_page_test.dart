import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/pages/earnings_page.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/payout_service.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';
import '../../../../../support/work_test_support.dart';

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

  testWidgets('güvenli hata açıklaması ham nedeni gizler', (tester) async {
    final semantics = tester.ensureSemantics();
    const rawFailureReason = 'bank_account_validation: IBAN checksum mismatch';
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
              'failureReason': rawFailureReason,
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
    expect(
      find.text('Kazanç ödemesi tamamlanamadı. Lütfen destekle iletişime geç.'),
      findsOneWidget,
    );
    expect(find.text(rawFailureReason), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(rawFailureReason))),
      findsNothing,
    );
    expect(find.text('99,99 ₺'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('bilinen payout hata anahtarını güvenli ayrıntıyla gösterir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [
            {
              'id': 'failed',
              'jobAssignmentId': 'assignment-1',
              'amount': '99.99',
              'currency': 'TRY',
              'status': 'FAILED',
              'failureReason': '{payout.settlement.failed}',
              'createdAt': '2026-09-02T12:00:00Z',
            },
          ],
        },
      ),
    );

    await pumpPage(tester, api);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Kazanç ödemesi tamamlanamadı. Destek ekibi işlemi inceleyecek.',
      ),
      findsOneWidget,
    );
    expect(find.text('{payout.settlement.failed}'), findsNothing);
  });

  // Kazançlar satırı da ölüydü (is-koala/koala#177): ödeme hangi işin
  // ödemesiyse onun detayına açılmalı. Atama etiketi ikinci istekle
  // geliyor; gelmeden satır dokunulmaz kalıyor.
  testWidgets('ödeme satırı atamanın iş detayına açılır', (tester) async {
    final payoutApi = FakeApi(
      handler: (_) => dataResponse(const [
        {
          'id': 'payout-1',
          'jobAssignmentId': 'assignment-1',
          'amount': '950.00',
          'currency': 'TRY',
          'status': 'COMPLETED',
          'completedAt': '2026-09-11T09:00:00Z',
          'createdAt': '2026-09-11T08:00:00Z',
        },
      ]),
    );
    final assignmentsApi = FakeApi(
      handler: (_) => pageResponse([
        assignmentJson(
          status: 'COMPLETED',
          paymentStatus: 'RELEASED_TO_WORKER',
        ),
      ]),
    );
    final opened = <MyJob>[];
    final router = GoRouter(
      initialLocation: '/earnings',
      routes: [
        GoRoute(
          path: '/earnings',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: EarningsPage(
              service: PayoutService.withClient(payoutApi.client),
              assignmentService: AssignmentService.withClient(
                assignmentsApi.client,
              ),
            ),
          ),
        ),
        stubWorkDetailRoute(onOpened: opened.add),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barista'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payout-payout-1')));
    await tester.pumpAndSettle();

    expect(find.text(workDetailStubTitle), findsOneWidget);
    expect(opened.single.assignmentId, 'assignment-1');
    expect(opened.single.status, MyJobStatus.past);
  });
}
