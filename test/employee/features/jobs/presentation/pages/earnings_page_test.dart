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
  // ödemesiyse onun detayına açılmalı.
  group('ödeme satırı → iş detayı', () {
    const payoutBody = {
      'id': 'payout-1',
      'jobAssignmentId': 'assignment-1',
      'amount': '950.00',
      'currency': 'TRY',
      'status': 'COMPLETED',
      'completedAt': '2026-09-11T09:00:00Z',
      'createdAt': '2026-09-11T08:00:00Z',
    };
    final completedAssignment = assignmentJson(
      status: 'COMPLETED',
      paymentStatus: 'RELEASED_TO_WORKER',
    );

    Future<({FakeApi assignmentsApi, List<MyJob> opened})> pumpEarnings(
      WidgetTester tester, {
      required FakeApiResponse Function(String path) assignmentHandler,
    }) async {
      final payoutApi = FakeApi(
        handler: (_) => dataResponse(const [payoutBody]),
      );
      final assignmentsApi = FakeApi(
        handler: (request) => assignmentHandler(request.path),
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
      return (assignmentsApi: assignmentsApi, opened: opened);
    }

    testWidgets('atama listede varsa doğrudan açılır', (tester) async {
      final harness = await pumpEarnings(
        tester,
        assignmentHandler: (path) => path == '/users/me/assignments'
            ? pageResponse([completedAssignment])
            : throw StateError('tekil atama istenmemeli: $path'),
      );

      expect(find.text('Barista'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('payout-payout-1')));
      await tester.pumpAndSettle();

      expect(find.text(workDetailStubTitle), findsOneWidget);
      expect(harness.opened.single.assignmentId, 'assignment-1');
      expect(harness.opened.single.status, MyJobStatus.past);
    });

    // Atama listesi ilk 20 kaydı getiriyor; eski bir ödemenin ataması orada
    // olmayabilir. Satır yine tıklanır, kayıt dokununca kimliğiyle çekilir.
    testWidgets('atama listede yoksa dokununca kimliğiyle çekilir', (
      tester,
    ) async {
      final harness = await pumpEarnings(
        tester,
        assignmentHandler: (path) => path == '/users/me/assignments'
            ? pageResponse(const [])
            : dataResponse(completedAssignment),
      );

      // Etiket yok: liste bu atamayı tanımıyor.
      expect(find.text('Barista'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('payout-payout-1')));
      await tester.pumpAndSettle();

      expect(
        harness.assignmentsApi.requests.map((request) => request.path),
        contains('/job-assignments/assignment-1'),
      );
      expect(find.text(workDetailStubTitle), findsOneWidget);
      expect(harness.opened.single.assignmentId, 'assignment-1');
    });

    testWidgets('tekil atama çekilemezse toast, detay açılmaz', (tester) async {
      final harness = await pumpEarnings(
        tester,
        assignmentHandler: (path) => path == '/users/me/assignments'
            ? pageResponse(const [])
            : const FakeApiResponse(
                statusCode: 404,
                body: {
                  'success': false,
                  'message': 'Atama bulunamadı.',
                  'errorCategory': 'RESOURCE_NOT_FOUND',
                },
              ),
      );

      await tester.tap(find.byKey(const ValueKey('payout-payout-1')));
      await tester.pumpAndSettle();

      expect(find.text('Atama bulunamadı.'), findsOneWidget);
      expect(find.text(workDetailStubTitle), findsNothing);
      expect(harness.opened, isEmpty);
    });
  });
}
