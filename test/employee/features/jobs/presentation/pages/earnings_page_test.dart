import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // Satırlar açıklama satırıyla uzadı; son kayıtlar ilk karede ekran dışı.
    expect(
      find.text('Hesabınıza geçti', skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.text('Transfer yolda', skipOffstage: false), findsOneWidget);
    expect(find.text('Çıkışa alındı', skipOffstage: false), findsOneWidget);
    expect(find.text('Başarısız', skipOffstage: false), findsOneWidget);
    expect(
      find.text(
        'Kazanç ödemesi tamamlanamadı. Lütfen destekle iletişime geç.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text(rawFailureReason, skipOffstage: false), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(rawFailureReason))),
      findsNothing,
    );
    expect(find.text('99,99 ₺', skipOffstage: false), findsOneWidget);
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

  // Kazançlar satırı hakedişin detayını açıyor (is-koala/koala#189); işin
  // detayına (is-koala/koala#177) oradan geçiliyor.
  group('ödeme satırı → hakediş detayı → iş detayı', () {
    const payoutBody = {
      'id': 'payout-1',
      'jobAssignmentId': 'assignment-1',
      'jobTitle': 'Barista',
      'companyName': 'Koala Cafe',
      'maskedIban': 'TR18***2315',
      'bankAccountId': 'bank-1',
      'providerReference': 'IYZ-77',
      'amount': '950.00',
      'currency': 'TRY',
      'status': 'COMPLETED',
      'releasedAt': '2026-09-11T08:00:00Z',
      'settledAt': '2026-09-11T09:00:00Z',
      'completedAt': '2026-09-11T09:00:00Z',
      'createdAt': '2026-09-11T08:00:00Z',
    };
    final completedAssignment = assignmentJson(
      status: 'COMPLETED',
      paymentStatus: 'RELEASED_TO_WORKER',
    );
    final row = find.byKey(const ValueKey('payout-payout-1'));
    final openWork = find.byKey(const ValueKey('payout-detail-open-work'));

    Future<({FakeApi assignmentsApi, List<MyJob> opened})> pumpEarnings(
      WidgetTester tester, {
      required FakeApiResponse Function(String path) assignmentHandler,
      Map<String, Object?> payout = payoutBody,
      Brightness brightness = Brightness.light,
    }) async {
      final payoutApi = FakeApi(handler: (_) => dataResponse([payout]));
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
        MaterialApp.router(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      return (assignmentsApi: assignmentsApi, opened: opened);
    }

    for (final brightness in Brightness.values) {
      testWidgets('satır: tutar, durum, iş adı ve maskeli IBAN kuyruğu '
          '(${brightness.name})', (tester) async {
        await pumpEarnings(
          tester,
          brightness: brightness,
          assignmentHandler: (_) => pageResponse(const []),
        );

        // Tutar özet kartında ("Tamamlanan") ve satırda.
        expect(find.text('950,00 ₺'), findsNWidgets(2));
        expect(find.text('Hesabınıza geçti'), findsOneWidget);
        expect(
          find.text('Hesabınıza geçti (ekstre ile doğrulandı)'),
          findsOneWidget,
        );
        // İş adı sunucunun `jobTitle` alanından; atama listesi boş.
        expect(find.text('Barista'), findsOneWidget);
        expect(find.text("…2315 IBAN'ına"), findsOneWidget);
        // Tam IBAN hiçbir yerde yok; maske bile satırda değil.
        expect(find.textContaining('TR18'), findsNothing);
      });

      testWidgets('detay: iş, şirket, IBAN, referans, zamanlar ve not '
          '(${brightness.name})', (tester) async {
        await pumpEarnings(
          tester,
          brightness: brightness,
          assignmentHandler: (_) => pageResponse(const []),
        );

        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(find.text('Hakediş Detayı'), findsOneWidget);
        expect(find.text('Koala Cafe'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('payout-detail-iban')),
          findsOneWidget,
        );
        expect(find.text('TR18***2315'), findsOneWidget);
        expect(find.text('IYZ-77'), findsOneWidget);
        expect(find.textContaining('Bu hesap silinmişse'), findsOneWidget);
        expect(find.text('Çıkışa alındı'), findsOneWidget);
        expect(find.text('Mutabakat'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('payout-detail-settled')))
              .data,
          isNot('—'),
        );
        expect(openWork, findsOneWidget);
      });
    }

    testWidgets('sağlayıcı referansı panoya kopyalanır', (tester) async {
      final copied = <String?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String?);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpEarnings(
        tester,
        assignmentHandler: (_) => pageResponse(const []),
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payout-detail-copy')));
      await tester.pumpAndSettle();

      expect(copied, ['IYZ-77']);
      expect(find.text('Referans kopyalandı'), findsOneWidget);
    });

    // Hesap silinmiş ya da eski sunucu: IBAN ve referans yok → "—", kopyalama
    // düğmesi yok; PENDING'de mutabakat da yok. Kesin ifade yalnız
    // COMPLETED'da.
    testWidgets('hesap ve referans yoksa "—", bekleyen çıkışta mutabakat yok', (
      tester,
    ) async {
      await pumpEarnings(
        tester,
        payout: const {
          'id': 'payout-1',
          'jobAssignmentId': 'assignment-1',
          'amount': '950.00',
          'currency': 'TRY',
          'status': 'PENDING',
          'createdAt': '2026-09-11T08:00:00Z',
        },
        assignmentHandler: (_) => pageResponse([completedAssignment]),
      );

      expect(find.textContaining("IBAN'ına"), findsNothing);
      expect(
        find.text('Çıkışa alındı — sağlayıcı onayı bekleniyor'),
        findsOneWidget,
      );
      expect(find.textContaining('Hesabınıza geçti'), findsNothing);
      // Eski sunucu `jobTitle` göndermiyor; ad atama listesinden.
      expect(find.text('Barista'), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();

      Text valueOf(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key)));
      expect(valueOf('payout-detail-iban').data, '—');
      expect(valueOf('payout-detail-reference').data, '—');
      expect(valueOf('payout-detail-settled').data, '—');
      expect(find.byKey(const ValueKey('payout-detail-copy')), findsNothing);
      expect(find.textContaining('Hesabınıza geçti'), findsNothing);
    });

    testWidgets('atama listede varsa iş detayı doğrudan açılır', (
      tester,
    ) async {
      final harness = await pumpEarnings(
        tester,
        assignmentHandler: (path) => path == '/users/me/assignments'
            ? pageResponse([completedAssignment])
            : throw StateError('tekil atama istenmemeli: $path'),
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(openWork);
      await tester.pumpAndSettle();

      expect(find.text(workDetailStubTitle), findsOneWidget);
      expect(harness.opened.single.assignmentId, 'assignment-1');
      expect(harness.opened.single.status, MyJobStatus.past);
    });

    // Atama listesi ilk 20 kaydı getiriyor; eski bir ödemenin ataması orada
    // olmayabilir. Kayıt "İş detayını aç" anında kimliğiyle çekilir.
    testWidgets('atama listede yoksa kimliğiyle çekilir', (tester) async {
      final harness = await pumpEarnings(
        tester,
        assignmentHandler: (path) => path == '/users/me/assignments'
            ? pageResponse(const [])
            : dataResponse(completedAssignment),
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(openWork);
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

      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(openWork);
      await tester.pumpAndSettle();

      expect(find.text('Atama bulunamadı.'), findsOneWidget);
      expect(find.text(workDetailStubTitle), findsNothing);
      expect(harness.opened, isEmpty);
    });
  });
}
