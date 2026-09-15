import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/widgets/b_selection_field.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/business/features/transport/models/transport_plan_draft.dart';
import 'package:koala/business/features/transport/presentation/pages/b_transport_plan_page.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';
import '../../../../../support/keyboard.dart';

/// İlan formundaki "Ulaşım" adımı (is-koala/koala#197): taslak
/// düzenleyiciden geliyor, ilan açıldıktan **sonra** ilanın kimliğiyle
/// `PUT /jobs/{id}/transport-plan` ile yazılıyor.
const _createLocation = '/business/create';

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

const Map<String, dynamic> _category = {
  'id': 'cat-foto',
  'name': 'Fotoğrafçılık',
  'code': 'PHOTOGRAPHY',
  'requiresInsurance': false,
};

/// Bir servisli, yol paralı taslak.
TransportPlanDraft _draft() => TransportPlanDraft(
  outboundMethod: TransportMethod.shuttle,
  returnMethod: TransportMethod.cashAllowance,
  allowanceAmount: 150,
  shuttles: [
    ShuttleDraft(
      direction: ShuttleDirection.outbound,
      name: 'Anadolu',
      plate: '34 ABC 12',
      capacity: 12,
      stops: [
        StopDraft(
          label: 'İskele',
          scheduledAt: DateTime(2026, 9, 20, 6, 40),
          pickedAddress: _moda,
        ),
      ],
    ),
  ],
);

/// Düzenleyicinin yerine geçen rota: aldığı `extra`'yı kaydeder ve
/// [result] ile kapanır.
class _EditorStub extends StatefulWidget {
  const _EditorStub({required this.extra, required this.onOpened, this.result});

  final Object? extra;
  final ValueChanged<Object?> onOpened;
  final TransportPlanDraft? result;

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

typedef Harness = ({
  FakeApi jobsApi,
  FakeApi transportApi,
  List<Object?> opened,
});

Future<Harness> _pumpCreate(
  WidgetTester tester, {
  TransportPlanDraft? initialTransport,
  TransportPlanDraft? editorResult,
  FakeApiResponse Function(String method, String path)? transportHandler,
  Brightness brightness = Brightness.light,
}) async {
  final userApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': 'employer-1',
          'firstName': 'Ayşe',
          'lastName': 'İşveren',
          'email': 'ayse@example.com',
          'isEmployer': true,
          'identityVerified': true,
          'companies': [],
        },
      },
    ),
  );
  final userProvider = UserProvider(
    userService: UserService.withClient(userApi.client),
  );
  await tester.runAsync(userProvider.load);

  final categoryApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': [_category],
      },
    ),
  );
  final emptyApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );
  // İlan açma: `POST /users/me/jobs` açılan ilanı döndürüyor; liste boş.
  final jobsApi = FakeApi(
    handler: (request) {
      if (request.method == 'POST') {
        return const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'job-new',
              'title': 'Etkinlik fotoğrafçısı',
              'category': _category,
              'type': 'ONE_TIME',
              'employerType': 'INDIVIDUAL',
              'salaryType': 'DAILY',
              'salary': 1500,
              'status': 'OPEN',
            },
          },
        );
      }
      return const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {'content': []},
        },
      );
    },
  );
  final transportApi = FakeApi(
    handler: (request) =>
        transportHandler?.call(request.method, request.path) ??
        const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'plan-1',
              'jobId': 'job-new',
              'outboundMethod': 'SHUTTLE',
              'returnMethod': 'CASH_ALLOWANCE',
              'allowanceAmount': 150,
              'shuttles': [],
            },
          },
        ),
  );

  final opened = <Object?>[];
  final router = GoRouter(
    initialLocation: _createLocation,
    routes: [
      GoRoute(
        path: _createLocation,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: BCreatePage(
            paymentService: BPaymentService.withClient(emptyApi.client),
            transportService: TransportService.withClient(transportApi.client),
            initialAddress: _moda,
            initialTransport: initialTransport,
          ),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.transportPlan,
        pageBuilder: (context, state) => MaterialPage<TransportPlanDraft>(
          key: state.pageKey,
          child: _EditorStub(
            extra: state.extra,
            onOpened: opened.add,
            result: editorResult,
          ),
        ),
      ),
      GoRoute(
        path: '/business/posts',
        pageBuilder: (context, state) =>
            const MaterialPage<void>(child: Scaffold(body: Text('ilanlarım'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(
          create: (_) => JobCategoryProvider(
            service: JobCategoryService.withClient(categoryApi.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BJobsProvider(
            service: EmployerJobService.withClient(jobsApi.client),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (jobsApi: jobsApi, transportApi: transportApi, opened: opened);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Formun zorunlu alanlarını doldurur (adres açılışta verildi).
Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(
    findFieldLabelled('İlan Başlığı *'),
    'Etkinlik fotoğrafçısı',
  );
  await tester.enterText(findFieldLabelled('Pozisyon *'), 'Fotoğrafçı');
  await tester.enterText(findFieldLabelled('Açıklama *'), 'Düğün çekimi.');
  await tester.enterText(findFieldLabelled('Ücret (₺) *'), '1500');
  await _tapVisible(
    tester,
    find.widgetWithText(BSelectionField, 'Kategori *').first,
  );
  await tester.tap(find.text('Fotoğrafçılık').last);
  await tester.pumpAndSettle();
  await _tapVisible(
    tester,
    find.widgetWithText(BSelectionField, 'Başlangıç *').first,
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.enterText(findFieldLabelled('Min Yaş *'), '18');
  await tester.enterText(findFieldLabelled('Max Yaş *'), '60');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _publish(WidgetTester tester) async {
  await tester.tap(findBottomBarButton());
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('İlan formu ulaşım adımı ($themeName tema)', () {
      testWidgets('taslak yokken giriş düğmesi; düzenleyici taslakla döner', (
        tester,
      ) async {
        final harness = await _pumpCreate(
          tester,
          editorResult: _draft(),
          brightness: brightness,
        );

        expect(find.text('Ulaşım'), findsOneWidget);
        final add = find.byKey(const ValueKey('b-create-transport-add'));
        expect(add, findsOneWidget);

        await _tapVisible(tester, add);

        final args = harness.opened.single! as BTransportPlanArgs;
        expect(args.jobId, isNull);
        expect(args.initial, isNull);
        expect(
          find.text('Gidiş: Servis · Dönüş: Yol parası (₺150)'),
          findsOneWidget,
        );
        expect(find.text('Anadolu · Gidiş'), findsOneWidget);
        expect(find.text('34 ABC 12 · 0/12 dolu'), findsOneWidget);
        expect(find.byKey(const ValueKey('b-transport-edit')), findsOneWidget);

        // Kaldır → düğme geri gelir.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('b-transport-remove')),
        );
        expect(add, findsOneWidget);
      });

      testWidgets('düzenle taslağı düzenleyiciye verir', (tester) async {
        final draft = _draft();
        final harness = await _pumpCreate(
          tester,
          initialTransport: draft,
          brightness: brightness,
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('b-transport-edit')),
        );

        final args = harness.opened.single! as BTransportPlanArgs;
        expect(args.initial, same(draft));
      });

      testWidgets('ilan açılınca plan ilanın kimliğiyle yazılır', (
        tester,
      ) async {
        final harness = await _pumpCreate(
          tester,
          initialTransport: _draft(),
          brightness: brightness,
        );
        await _fillRequired(tester);

        await _publish(tester);

        expect(
          harness.jobsApi.requests.where((r) => r.method == 'POST'),
          hasLength(1),
        );
        final put = harness.transportApi.requests.single;
        expect(put.method, 'PUT');
        expect(put.path, '/jobs/job-new/transport-plan');
        final body = put.data as Map;
        expect(body['outboundMethod'], 'SHUTTLE');
        expect(body['allowanceAmount'], 150);
        final shuttle = (body['shuttles'] as List).single as Map;
        expect(shuttle.containsKey('id'), isFalse);
        expect(shuttle['plate'], '34 ABC 12');
        final stop = (shuttle['stops'] as List).single as Map;
        expect(stop['label'], 'İskele');
        expect((stop['address'] as Map)['districtId'], 'd-1');
        expect(find.text('İlan Oluşturuldu!'), findsOneWidget);
      });

      testWidgets('plan yazımı düşerse ilan yine açılmış, toast söyler', (
        tester,
      ) async {
        final harness = await _pumpCreate(
          tester,
          initialTransport: _draft(),
          transportHandler: (_, _) => const FakeApiResponse(
            statusCode: 409,
            body: {
              'success': false,
              'message':
                  'Servis yalnız yöntemi SHUTTLE olan yönde tanımlanabilir.',
              'errorCategory': 'DATA_CONFLICT',
              'errorCode': 'TRANSPORT_SHUTTLE_DIRECTION_RULE',
            },
          ),
          brightness: brightness,
        );
        await _fillRequired(tester);

        await _publish(tester);

        expect(harness.transportApi.requests, hasLength(1));
        expect(
          find.textContaining('İlan açıldı ancak ulaşım planı kaydedilemedi'),
          findsOneWidget,
        );
        expect(find.text('İlan Oluşturuldu!'), findsOneWidget);
      });

      testWidgets('taslak yoksa plan ucu hiç çağrılmaz', (tester) async {
        final harness = await _pumpCreate(tester, brightness: brightness);
        await _fillRequired(tester);

        await _publish(tester);

        expect(
          harness.jobsApi.requests.where((r) => r.method == 'POST'),
          hasLength(1),
        );
        expect(harness.transportApi.requests, isEmpty);
        expect(find.text('İlan Oluşturuldu!'), findsOneWidget);
      });
    });
  }
}
