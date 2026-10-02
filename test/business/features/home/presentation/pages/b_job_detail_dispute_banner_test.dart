import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/features/dispute/dispute_routes.dart';

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

      testWidgets('uyuşmazlık yoksa bant da yok', (tester) async {
        await pumpPage(tester, brightness: brightness);

        expect(find.byKey(const ValueKey('open-dispute-banner')), findsNothing);
      });
    });
  }
}
