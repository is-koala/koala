import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/transport/models/transport_plan_draft.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_editor_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_stop_editor_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_transport_plan_page.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';
import '../../../../../support/transport_fixtures.dart';

const _moda = ConfirmedAddress(
  country: ReferenceLocation(id: 'c-1', name: 'Türkiye'),
  city: ReferenceLocation(id: 'ct-1', name: 'İstanbul'),
  district: ReferenceLocation(id: 'd-1', name: 'Kadıköy'),
  components: AddressComponents(
    neighborhood: 'Caferağa',
    thoroughfare: 'Moda Caddesi',
    buildingNumber: '12',
    postalCode: '34710',
  ),
  position: AddressPosition(
    latitude: 40.98765432,
    longitude: 29.02612345,
    source: AddressPositionSource.userConfirmedPin,
  ),
);

/// Harita ekranının yerine geçen rota: [_moda] ile kapanır.
class _PickerStub extends StatefulWidget {
  const _PickerStub();

  @override
  State<_PickerStub> createState() => _PickerStubState();
}

class _PickerStubState extends State<_PickerStub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(_moda);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

typedef Harness = ({FakeApi api, List<Object?> results});

/// Düzenleyiciyi gerçek rotalarıyla (servis ve durak sayfaları) ve sahte
/// haritayla çizer. Sayfa `pop` ile ne döndürdüyse [Harness.results]'a düşer.
Future<Harness> pumpEditor(
  WidgetTester tester, {
  required BTransportPlanArgs args,
  FakeApiResponse Function(String method, String path, Object? body)? handler,
  Brightness brightness = Brightness.light,
}) async {
  final api = FakeApi(
    handler: (request) =>
        handler?.call(request.method, request.path, request.data) ??
        const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Ulaşım planı bulunamadı.',
            'errorCategory': 'RESOURCE_NOT_FOUND',
            'errorCode': 'TRANSPORT_PLAN_NOT_FOUND',
          },
        ),
  );
  final results = <Object?>[];

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  results.add(
                    await context.push<Object>(
                      BusinessRoutes.transportPlan,
                      extra: args,
                    ),
                  );
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.transportPlan,
        pageBuilder: (context, state) => MaterialPage<Object>(
          key: state.pageKey,
          child: BTransportPlanPage(
            args: state.extra as BTransportPlanArgs,
            service: TransportService.withClient(api.client),
          ),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.transportShuttle,
        pageBuilder: (context, state) => MaterialPage<ShuttleDraft>(
          key: state.pageKey,
          child: BShuttleEditorPage(args: state.extra as BShuttleEditorArgs),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.transportStop,
        pageBuilder: (context, state) => MaterialPage<StopDraft>(
          key: state.pageKey,
          child: BStopEditorPage(args: state.extra as BStopEditorArgs),
        ),
      ),
      GoRoute(
        path: '/pick-address',
        pageBuilder: (context, state) => MaterialPage<ConfirmedAddress>(
          key: state.pageKey,
          child: const _PickerStub(),
        ),
      ),
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
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return (api: api, results: results);
}

/// Uzun formda alttaki öğe 600 px'lik test penceresinin dışında kalıyor;
/// önce görünür kılınıyor.
Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Kaydet').last);
  await tester.pumpAndSettle();
}

/// Tarih ve saat seçicileri: ikisinde de varsayılanı onayla.
Future<void> _confirmPickers(WidgetTester tester) async {
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('BTransportPlanPage ($themeName tema)', () {
      testWidgets('taslak modu: servis + durak ekleyip taslakla kapanır', (
        tester,
      ) async {
        final harness = await pumpEditor(
          tester,
          args: BTransportPlanArgs(jobStart: DateTime(2026, 9, 20, 9)),
          brightness: brightness,
        );

        // Gidiş yöntemi: Servis.
        await _tapKey(tester, 'b-transport-method-OUTBOUND');
        await tester.tap(find.text('Servis').last);
        await tester.pumpAndSettle();
        expect(find.text('Gidiş servisleri'), findsOneWidget);
        expect(find.text('Henüz servis eklemediniz.'), findsOneWidget);

        // Dönüş yöntemi: Yol parası → tutar alanı açılır.
        await _tapKey(tester, 'b-transport-method-RETURN');
        await tester.tap(find.text('Yol parası').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          findFieldLabelled('Yol parası tutarı (₺) *'),
          '150',
        );

        // Servis ekle → servis düzenleyicisi.
        await tester.ensureVisible(
          find.byKey(const ValueKey('b-transport-add-shuttle-OUTBOUND')),
        );
        await tester.tap(
          find.byKey(const ValueKey('b-transport-add-shuttle-OUTBOUND')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Gidiş Servisi Ekle'), findsOneWidget);
        await tester.enterText(findFieldLabelled('Servis adı *'), 'Anadolu');
        await tester.enterText(findFieldLabelled('Plaka'), '34 ABC 12');
        await tester.enterText(findFieldLabelled('Kapasite *'), '12');
        await tester.enterText(
          findFieldLabelled('Şoför telefonu'),
          '05551112233',
        );

        // Durak ekle → durak düzenleyicisi: saat + adres.
        await tester.ensureVisible(
          find.byKey(const ValueKey('b-shuttle-add-stop')),
        );
        await tester.tap(find.byKey(const ValueKey('b-shuttle-add-stop')));
        await tester.pumpAndSettle();
        expect(find.text('Durak Ekle'), findsOneWidget);
        await tester.enterText(
          findFieldLabelled('Durak adı (ör. Kadıköy İskele)'),
          'İskele',
        );
        await tester.tap(find.byKey(const ValueKey('b-stop-time')));
        await tester.pumpAndSettle();
        await _confirmPickers(tester);
        await tester.tap(find.byKey(const ValueKey('b-stop-address')));
        await tester.pumpAndSettle();
        expect(find.text(_moda.summary), findsOneWidget);
        await tester.tap(find.text('Durağı Kaydet'));
        await tester.pumpAndSettle();

        // Servis düzenleyicisine dönüldü, durak listede.
        expect(find.textContaining('İskele · '), findsOneWidget);
        await tester.tap(find.text('Servisi Kaydet'));
        await tester.pumpAndSettle();

        // Plan sayfasına dönüldü, servis kartı var.
        expect(find.text('Anadolu'), findsOneWidget);
        expect(find.text('34 ABC 12 · 12 koltuk · 1 durak'), findsOneWidget);

        await _tapSave(tester);

        final draft = harness.results.single! as TransportPlanDraft;
        expect(draft.outboundMethod, TransportMethod.shuttle);
        expect(draft.returnMethod, TransportMethod.cashAllowance);
        expect(draft.allowanceAmount, 150);
        final shuttle = draft.shuttles.single;
        expect(shuttle.name, 'Anadolu');
        expect(shuttle.plate, '34 ABC 12');
        expect(shuttle.capacity, 12);
        expect(shuttle.driverPhone, '05551112233');
        final stop = shuttle.stops.single;
        expect(stop.label, 'İskele');
        expect(stop.scheduledAt, isNotNull);
        expect(stop.pickedAddress, same(_moda));
        // Taslak modunda sunucuya gidilmez.
        expect(harness.api.requests, isEmpty);
      });

      testWidgets('taslak modu: eksik alan toast ile durdurur', (tester) async {
        final harness = await pumpEditor(
          tester,
          args: BTransportPlanArgs(
            initial: TransportPlanDraft(
              outboundMethod: TransportMethod.cashAllowance,
            ),
          ),
          brightness: brightness,
        );

        await _tapSave(tester);

        expect(find.text('Yol parası tutarını girin'), findsOneWidget);
        expect(harness.results, isEmpty);
      });

      testWidgets('ilan modu: plan okunur, koltuklu servis silinirken uyarır', (
        tester,
      ) async {
        var reads = 0;
        final harness = await pumpEditor(
          tester,
          args: const BTransportPlanArgs(jobId: 'job-1'),
          brightness: brightness,
          handler: (method, path, body) {
            if (method == 'GET') {
              reads++;
              return FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': transportPlanJson()},
              );
            }
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': transportPlanJson(shuttles: const []),
              },
            );
          },
        );

        expect(reads, 1);
        expect(find.text('Anadolu yakası servisi'), findsOneWidget);
        expect(find.text('3 koltuk seçildi'), findsOneWidget);

        // Silme: onay kutusu koltuk sayısını yazıyor; vazgeç → servis kalır.
        await _tapKey(tester, 'b-transport-remove-shuttle-0');
        expect(
          find.text(
            '3 çalışanın koltuğu düşecek; plan kaydedilince yeniden koltuk '
            'seçmeleri istenecek.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();
        expect(find.text('Anadolu yakası servisi'), findsOneWidget);

        // Sil → onayla → liste boş; yöntem hâlâ servis olduğundan kaydetmek
        // "en az bir servis" der. Yöntemi değiştirip kaydet: ikinci uyarı
        // (kaydedince düşecek koltuklar) ve PUT.
        await _tapKey(tester, 'b-transport-remove-shuttle-0');
        await tester.tap(find.text('Sil'));
        await tester.pumpAndSettle();
        expect(find.text('Anadolu yakası servisi'), findsNothing);

        await _tapSave(tester);
        expect(
          find.text('Gidiş için en az bir servis ekleyin'),
          findsOneWidget,
        );

        await _tapKey(tester, 'b-transport-method-OUTBOUND');
        await tester.tap(find.text('Kendi imkânı').last);
        await tester.pumpAndSettle();

        await _tapSave(tester);
        expect(find.text('Koltuklar düşecek'), findsOneWidget);
        expect(
          find.textContaining('3 çalışanın koltuğu düşecek ve yeniden'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Kaydet').last);
        await tester.pumpAndSettle();

        final put = harness.api.requests.where((r) => r.method == 'PUT').single;
        expect(put.path, '/jobs/job-1/transport-plan');
        final putBody = put.data as Map;
        expect(putBody['outboundMethod'], 'SELF');
        expect(putBody['shuttles'], isEmpty);
        expect(harness.results.single, isA<TransportPlan>());
      });

      testWidgets('ilan modu: yerinde düzenleme id taşır, 409 toast olur', (
        tester,
      ) async {
        final harness = await pumpEditor(
          tester,
          args: const BTransportPlanArgs(jobId: 'job-1'),
          brightness: brightness,
          handler: (method, path, body) {
            if (method == 'GET') {
              return FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': transportPlanJson()},
              );
            }
            return const FakeApiResponse(
              statusCode: 409,
              body: {
                'success': false,
                'message':
                    'Servis kapasitesi seçilmiş koltuk sayısının altına '
                    'indirilemez.',
                'errorCategory': 'DATA_CONFLICT',
                'errorCode': 'TRANSPORT_SHUTTLE_CAPACITY_BELOW_SEATS',
              },
            );
          },
        );

        // Servisi aç, kapasiteyi değiştir, kaydet.
        await _tapKey(tester, 'b-transport-shuttle-0');
        expect(find.text('Servisi Düzenle'), findsOneWidget);
        expect(
          find.text(
            'Bu serviste 3 koltuk seçildi; kapasite bunun altına inemez.',
          ),
          findsOneWidget,
        );
        await tester.enterText(findFieldLabelled('Kapasite *'), '20');
        await tester.tap(find.text('Servisi Kaydet'));
        await tester.pumpAndSettle();
        expect(find.text('34 ABC 12 · 20 koltuk · 1 durak'), findsOneWidget);

        await _tapSave(tester);

        final put = harness.api.requests.where((r) => r.method == 'PUT').single;
        final shuttle = ((put.data as Map)['shuttles'] as List).single as Map;
        expect(shuttle['id'], 'shuttle-1');
        expect(shuttle['capacity'], 20);
        expect((shuttle['stops'] as List).single['id'], 'stop-1');
        expect(
          find.text(
            'Servis kapasitesi seçilmiş koltuk sayısının altına indirilemez.',
          ),
          findsOneWidget,
        );
        // Sayfa açık kaldı.
        expect(find.text('Ulaşım Planı'), findsOneWidget);
        expect(harness.results, isEmpty);
      });

      testWidgets(
        'ilan modu: yerel kapasite kuralı sunucuya gitmeden durdurur',
        (tester) async {
          final harness = await pumpEditor(
            tester,
            args: const BTransportPlanArgs(jobId: 'job-1'),
            brightness: brightness,
            handler: (method, path, body) => FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': transportPlanJson()},
            ),
          );

          await _tapKey(tester, 'b-transport-shuttle-0');
          await tester.enterText(findFieldLabelled('Kapasite *'), '2');
          await tester.tap(find.text('Servisi Kaydet'));
          await tester.pumpAndSettle();

          expect(
            find.text(
              'Anadolu yakası servisi: kapasite seçilmiş koltuk sayısının (3) '
              'altına inemez',
            ),
            findsOneWidget,
          );
          // Servis düzenleyicisi kapanmadı, PUT yok.
          expect(find.text('Servisi Düzenle'), findsOneWidget);
          expect(harness.api.requests.where((r) => r.method == 'PUT'), isEmpty);
        },
      );

      testWidgets('durak silme koltuk sayısıyla onay ister', (tester) async {
        await pumpEditor(
          tester,
          args: const BTransportPlanArgs(jobId: 'job-1'),
          brightness: brightness,
          handler: (method, path, body) => FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': transportPlanJson(
                shuttles: [
                  shuttleJson(
                    stops: [
                      stopJson(seatsTaken: 2),
                      stopJson(id: 'stop-2', label: 'Bostancı'),
                    ],
                  ),
                ],
              ),
            },
          ),
        );

        await _tapKey(tester, 'b-transport-shuttle-0');
        expect(find.text('2 koltuk seçildi'), findsOneWidget);

        // Koltuklu durak: onay kutusu; vazgeç → durak kalır.
        await _tapKey(tester, 'b-shuttle-remove-stop-0');
        expect(find.text('Durağı sil'), findsOneWidget);
        expect(
          find.text(
            '2 çalışanın koltuğu düşecek; plan kaydedilince yeniden koltuk '
            'seçmeleri istenecek.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Kadıköy İskele · '), findsOneWidget);

        // Sil → onayla → durak gider.
        await _tapKey(tester, 'b-shuttle-remove-stop-0');
        await tester.tap(find.text('Sil'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Kadıköy İskele · '), findsNothing);
        expect(find.textContaining('Bostancı · '), findsOneWidget);

        // Koltuksuz durak onaysuz silinir.
        await _tapKey(tester, 'b-shuttle-remove-stop-0');
        expect(find.text('Durağı sil'), findsNothing);
        expect(find.textContaining('Bostancı · '), findsNothing);
      });

      testWidgets('ilan modu: kapasite 409\'unda plan yeniden okunur', (
        tester,
      ) async {
        var reads = 0;
        final harness = await pumpEditor(
          tester,
          args: const BTransportPlanArgs(jobId: 'job-1'),
          brightness: brightness,
          handler: (method, path, body) {
            if (method == 'GET') {
              reads++;
              // Başka bir cihazda koltuklar arttı: ikinci okuma 8 diyor.
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': transportPlanJson(
                    shuttles: [shuttleJson(seatsTaken: reads == 1 ? 3 : 8)],
                  ),
                },
              );
            }
            return const FakeApiResponse(
              statusCode: 409,
              body: {
                'success': false,
                'message':
                    'Servis kapasitesi seçilmiş koltuk sayısının altına '
                    'indirilemez.',
                'errorCategory': 'DATA_CONFLICT',
                'errorCode': 'TRANSPORT_SHUTTLE_CAPACITY_BELOW_SEATS',
              },
            );
          },
        );

        expect(find.text('3 koltuk seçildi'), findsOneWidget);
        await _tapSave(tester);

        expect(
          find.text(
            'Servis kapasitesi seçilmiş koltuk sayısının altına indirilemez.',
          ),
          findsOneWidget,
        );
        expect(reads, 2);
        expect(find.text('8 koltuk seçildi'), findsOneWidget);
        expect(harness.results, isEmpty);
      });

      testWidgets('ilan modu: yön kilidi 409\'u düzenleyicinin cümlesiyle', (
        tester,
      ) async {
        var reads = 0;
        await pumpEditor(
          tester,
          args: const BTransportPlanArgs(jobId: 'job-1'),
          brightness: brightness,
          handler: (method, path, body) {
            if (method == 'GET') {
              reads++;
              return FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': transportPlanJson()},
              );
            }
            return const FakeApiResponse(
              statusCode: 409,
              body: {
                'success': false,
                'message': 'Var olan servisin yönü değiştirilemez.',
                'errorCategory': 'DATA_CONFLICT',
                'errorCode': 'TRANSPORT_SHUTTLE_DIRECTION_LOCKED',
              },
            );
          },
        );

        await _tapSave(tester);

        expect(
          find.text(BTransportPlanPagemodel.directionLockedText),
          findsOneWidget,
        );
        expect(
          find.text('Var olan servisin yönü değiştirilemez.'),
          findsNothing,
        );
        // Yön kilidi bayat plan demek değil; yeniden okuma yok.
        expect(reads, 1);
      });

      testWidgets('ilan modu: 404 durak kimliği planı yeniden okutur', (
        tester,
      ) async {
        var reads = 0;
        final harness = await pumpEditor(
          tester,
          args: const BTransportPlanArgs(jobId: 'job-1'),
          brightness: brightness,
          handler: (method, path, body) {
            if (method == 'GET') {
              reads++;
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': transportPlanJson(
                    shuttles: [
                      shuttleJson(
                        name: reads == 1 ? 'Eski servis' : 'Sunucudaki servis',
                      ),
                    ],
                  ),
                },
              );
            }
            return const FakeApiResponse(
              statusCode: 404,
              body: {
                'success': false,
                'message': 'Durak bulunamadı.',
                'errorCategory': 'RESOURCE_NOT_FOUND',
                'errorCode': 'TRANSPORT_STOP_NOT_FOUND',
              },
            );
          },
        );

        expect(find.text('Eski servis'), findsOneWidget);
        await _tapSave(tester);

        expect(find.text('Durak bulunamadı.'), findsOneWidget);
        expect(reads, 2);
        expect(find.text('Sunucudaki servis'), findsOneWidget);
        expect(harness.results, isEmpty);
      });

      testWidgets('ilan modu: plan yoksa boş taslakla açılır', (tester) async {
        await pumpEditor(
          tester,
          args: const BTransportPlanArgs(jobId: 'job-1'),
          brightness: brightness,
        );

        expect(find.text('Sağlanmıyor'), findsNWidgets(2));
        expect(find.text('Gidiş servisleri'), findsNothing);
      });
    });
  }
}
