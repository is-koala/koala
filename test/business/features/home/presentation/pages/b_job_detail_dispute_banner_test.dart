import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/features/dispute/dispute_routes.dart';

import '../../../../../support/dispute_evidence_fixtures.dart'
    show dataResponse, disputeJson;
import '../../../../../support/fake_api.dart';
import 'b_job_detail_test_harness.dart';

/// Uyuşmazlık ekranının yerine geçen sahte rota: açıldığı konumu yazıyor,
/// geri düğmesiyle kapanıyor.
List<GoRoute> _stubDisputeRoute(List<String> opened) => [
  GoRoute(
    path: DisputeRoutes.pattern,
    pageBuilder: (context, state) {
      opened.add(state.matchedLocation);
      return MaterialPage<void>(
        key: state.pageKey,
        child: Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('stub-dispute-back'),
              onPressed: context.pop,
              child: const Text('uyuşmazlık ekranı'),
            ),
          ),
        ),
      );
    },
  ),
];

/// Emanette para olan, süren atama: "Sorun Bildir" düğmesi çıkıyor.
final Map<String, Object?> _heldAssignment = {
  ...assignmentJson,
  'status': 'IN_PROGRESS',
  'paymentStatus': 'HELD_IN_ESCROW',
};

void main() {
  for (final brightness in Brightness.values) {
    group('Açık uyuşmazlık bandı (${brightness.name})', () {
      testWidgets(
        'kanıt ekleme çağrısını yazar, dokununca ekranı açar ve dönünce tazeler',
        (tester) async {
          final opened = <String>[];
          final harness = await pumpPage(
            tester,
            openDispute: true,
            brightness: brightness,
            extraRoutes: _stubDisputeRoute(opened),
          );
          int disputeReads() => harness.assignmentApi.requests
              .where((request) => request.path.endsWith('/disputes'))
              .length;

          final banner = find.byKey(const ValueKey('open-dispute-banner'));
          await tester.scrollUntilVisible(
            banner,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Açık sorun bildirimi'), findsOneWidget);
          expect(find.text('Kanıt ekle ya da görüntüle'), findsOneWidget);
          final readsBefore = disputeReads();

          await tester.tap(banner);
          await tester.pumpAndSettle();

          // Atama kimliği uyuşmazlığın kendisinden: sayfa o ekranda yeniden
          // atamanın uyuşmazlıklarını okuyor.
          expect(opened, ['/assignment-dispute/assignment-1']);

          await tester.tap(find.byKey(const ValueKey('stub-dispute-back')));
          for (var index = 0; index < 20; index++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          await tester.pumpAndSettle();

          // Karar bu arada verilmiş olabilir: dönüşte bant tazeleniyor.
          expect(disputeReads(), readsBefore + 1);
        },
      );

      testWidgets('sonuçlanmış uyuşmazlık özet kartıyla ekranı açar', (
        tester,
      ) async {
        final opened = <String>[];
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [_heldAssignment],
          extraRoutes: _stubDisputeRoute(opened),
          assignmentHandler: (request) => request.path.endsWith('/disputes')
              ? dataResponse([
                  disputeJson(
                    'dispute-1',
                    status: 'RESOLVED',
                    reason: 'Ücret eksik ödendi',
                    resolution: 'REFUND_EMPLOYER',
                  ),
                ])
              : const FakeApiResponse(
                  statusCode: 200,
                  body: {'success': true, 'data': []},
                ),
        );

        // Karardan sonra giriş kalıyor: sonuç ve kanıtlar orada görülüyor.
        final summary = find.byKey(const ValueKey('dispute-summary'));
        await tester.scrollUntilVisible(
          summary,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Sonuçlandı'), findsOneWidget);
        expect(find.text('Kanıtları görüntüle'), findsOneWidget);
        // Açık uyarı bandı yok.
        expect(find.byKey(const ValueKey('open-dispute-banner')), findsNothing);

        await tester.tap(summary);
        await tester.pumpAndSettle();

        expect(opened, ['/assignment-dispute/assignment-1']);
      });

      testWidgets('bant mürekkep verebilir: Material + InkWell', (
        tester,
      ) async {
        await pumpPage(tester, openDispute: true, brightness: brightness);

        final banner = find.byKey(const ValueKey('open-dispute-banner'));
        await tester.scrollUntilVisible(
          banner,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        // Süslü bir `Container`'ın altında mürekkep görünmezdi; zemin Material.
        expect(
          find.ancestor(of: banner, matching: find.byType(Material)),
          findsWidgets,
        );
        expect(tester.widget<InkWell>(banner).onTap, isNotNull);
      });

      testWidgets('sorun bildirilince uyuşmazlık ekranı açılır', (
        tester,
      ) async {
        var opened = false;
        final screens = <String>[];
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [_heldAssignment],
          extraRoutes: _stubDisputeRoute(screens),
          assignmentHandler: (request) {
            if (request.path.endsWith('/disputes') &&
                request.method == 'POST') {
              opened = true;
              return dataResponse(
                disputeJson('dispute-new', reason: 'Ücret uyuşmazlığı'),
              );
            }
            if (request.path.endsWith('/disputes')) {
              return dataResponse([
                if (opened)
                  disputeJson('dispute-new', reason: 'Ücret uyuşmazlığı'),
              ]);
            }
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': []},
            );
          },
        );

        final button = find.text('Sorun Bildir');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Ücret uyuşmazlığı');
        await tester.pump();
        await tester.tap(find.text('Bildir'));
        for (var index = 0; index < 20; index++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();

        // Açılır açılmaz kanıt ekleme ekranına geçiliyor.
        expect(screens, ['/assignment-dispute/assignment-1']);
      });

      testWidgets('reddedilen bildirim ekranı açmaz', (tester) async {
        final screens = <String>[];
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [_heldAssignment],
          extraRoutes: _stubDisputeRoute(screens),
          assignmentHandler: (request) =>
              request.path.endsWith('/disputes') && request.method == 'POST'
              ? const FakeApiResponse(
                  statusCode: 409,
                  body: {
                    'success': false,
                    'message': 'Zaten açık bir uyuşmazlık var.',
                    'errorCategory': 'DATA_CONFLICT',
                  },
                )
              : const FakeApiResponse(
                  statusCode: 200,
                  body: {'success': true, 'data': []},
                ),
        );

        final button = find.text('Sorun Bildir');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Ücret uyuşmazlığı');
        await tester.pump();
        await tester.tap(find.text('Bildir'));
        await tester.pumpAndSettle();

        expect(find.text('Zaten açık bir uyuşmazlık var.'), findsOneWidget);
        expect(screens, isEmpty);
      });

      testWidgets('uyuşmazlık yoksa bant da yok', (tester) async {
        await pumpPage(tester, brightness: brightness);

        expect(find.byKey(const ValueKey('open-dispute-banner')), findsNothing);
      });
    });
  }
}
