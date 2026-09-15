import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/transport/presentation/pages/b_transport_plan_page.dart';
import 'package:koala/business/features/transport/presentation/widgets/b_transport_plan_summary.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/router/business_routes.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/transport_fixtures.dart';
import 'b_job_detail_test_harness.dart';

/// İlan detayındaki (işveren) "Ulaşım" bölümü (is-koala/koala#197): plan
/// özeti + Düzenle; plan yokken "plan ekle"; hata satırı ve tekrar dene.

/// Düzenleyicinin yerine geçen rota; aldığı `extra`'yı kaydeder ve
/// [result] ile kapanır.
class _EditorStub extends StatefulWidget {
  const _EditorStub({required this.extra, required this.onOpened, this.result});

  final Object? extra;
  final ValueChanged<Object?> onOpened;
  final TransportPlan? result;

  @override
  State<_EditorStub> createState() => _EditorStubState();
}

class _EditorStubState extends State<_EditorStub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOpened(widget.extra);
      if (mounted) context.pop(widget.result);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

FakeApiResponse _planResponse([Map<String, Object?>? plan]) => FakeApiResponse(
  statusCode: 200,
  body: {'success': true, 'data': plan ?? transportPlanJson()},
);

Future<void> _scrollToSection(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Ulaşım'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('İlan detayı ulaşım bölümü ($themeName tema)', () {
      testWidgets('plan varsa özet plaka ve dolulukla, Düzenle ile', (
        tester,
      ) async {
        await pumpPage(
          tester,
          brightness: brightness,
          transportHandler: (_) => _planResponse(),
        );
        await _scrollToSection(tester);

        expect(find.byType(BTransportPlanSummary), findsOneWidget);
        expect(
          find.text('Gidiş: Servis · Dönüş: Yol parası (₺150)'),
          findsOneWidget,
        );
        expect(find.text('Anadolu yakası servisi · Gidiş'), findsOneWidget);
        expect(
          find.text('34 ABC 12 · 3/12 dolu · Mehmet Usta'),
          findsOneWidget,
        );
        expect(find.textContaining('Kadıköy İskele · '), findsOneWidget);
        expect(find.byKey(const ValueKey('b-transport-edit')), findsOneWidget);
        expect(find.byKey(const ValueKey('b-transport-add')), findsNothing);
      });

      testWidgets('plan yoksa (404) "Ulaşım planı ekle"', (tester) async {
        await pumpPage(tester, brightness: brightness);
        await _scrollToSection(tester);

        expect(find.byKey(const ValueKey('b-transport-add')), findsOneWidget);
        expect(find.byType(BTransportPlanSummary), findsNothing);
      });

      testWidgets('eski sunucu (ENDPOINT_NOT_FOUND) bölümü hiç çizmez', (
        tester,
      ) async {
        // Ucu tanımayan sunucuda 'plan ekle' çıksaydı PUT de 404 alırdı.
        await pumpPage(
          tester,
          brightness: brightness,
          transportHandler: (_) => const FakeApiResponse(
            statusCode: 404,
            body: {
              'success': false,
              'message': 'Böyle bir uç bulunamadı.',
              'errorCategory': 'ENDPOINT_NOT_FOUND',
              'errorCode': 'ENDPOINT_NOT_FOUND',
            },
          ),
        );

        expect(find.text('Ulaşım'), findsNothing);
        expect(find.byKey(const ValueKey('b-transport-add')), findsNothing);
        expect(find.byKey(const ValueKey('b-transport-error')), findsNothing);
      });

      testWidgets('kodsuz 404 de eski sunucu sayılır, bölüm gizli', (
        tester,
      ) async {
        await pumpPage(
          tester,
          brightness: brightness,
          transportHandler: (_) => const FakeApiResponse(
            statusCode: 404,
            body: {'success': false, 'message': 'Bulunamadı.'},
          ),
        );

        expect(find.text('Ulaşım'), findsNothing);
      });

      testWidgets('plan okunamazsa hata satırı ve tekrar dene', (tester) async {
        var calls = 0;
        await pumpPage(
          tester,
          brightness: brightness,
          transportHandler: (_) {
            calls++;
            return calls == 1
                ? const FakeApiResponse(
                    statusCode: 500,
                    body: {'success': false, 'message': 'Sunucu hatası.'},
                  )
                : _planResponse();
          },
        );
        await _scrollToSection(tester);

        expect(find.byKey(const ValueKey('b-transport-error')), findsOneWidget);
        expect(
          find.text('Ulaşım planı alınamadı: Sunucu hatası.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Tekrar dene').last);
        await tester.pumpAndSettle();

        expect(calls, 2);
        expect(find.byType(BTransportPlanSummary), findsOneWidget);
      });

      testWidgets('Düzenle ilan modunda açar, dönen plan özete yazılır', (
        tester,
      ) async {
        final opened = <Object?>[];
        final updated = TransportPlan.fromJson(
          transportPlanJson(
            shuttles: [shuttleJson(name: 'Yeni servis', plate: '06 XYZ 99')],
          ),
        );
        await pumpPage(
          tester,
          brightness: brightness,
          transportHandler: (_) => _planResponse(),
          extraRoutes: [
            GoRoute(
              path: BusinessRoutes.transportPlan,
              pageBuilder: (context, state) => MaterialPage<TransportPlan>(
                key: state.pageKey,
                child: _EditorStub(
                  extra: state.extra,
                  onOpened: opened.add,
                  result: updated,
                ),
              ),
            ),
          ],
        );
        await _scrollToSection(tester);

        await tester.tap(find.byKey(const ValueKey('b-transport-edit')));
        await tester.pumpAndSettle();

        final args = opened.single! as BTransportPlanArgs;
        expect(args.jobId, 'job-1');
        expect(args.original?.id, 'plan-1');
        expect(args.initial?.shuttles.single.id, 'shuttle-1');
        expect(args.jobStart, DateTime.utc(2026, 9, 10, 9));
        expect(find.text('Yeni servis · Gidiş'), findsOneWidget);
        expect(find.textContaining('06 XYZ 99'), findsOneWidget);
      });
    });
  }
}
