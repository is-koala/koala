import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/widgets/b_selection_field.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';
import '../../../../../support/keyboard.dart';

/// İlan konum kuralı (Yusuf, 04.11.2026): şirket ilanında tam konum
/// varsayılan olarak herkese açık, işveren "Adresi gizle" ile kapatabiliyor
/// ve istek `addressPublic` taşıyor. Bireysel ilanda anahtar yok, alan da
/// gönderilmiyor — bireysel ilan herkese her zaman yaklaşık. Kesinliği
/// sunucu belirliyor; istemci yalnız tercihi iletiyor.
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

const List<Map<String, dynamic>> _approvedCompany = [
  {
    'companyId': 'company-1',
    'companyName': 'Koala A.Ş.',
    'approved': true,
    'role': 'OWNER',
  },
];

/// Formu çizer; [companies] boşsa işveren bireysel. Dönen sahte API, ilan
/// açma isteğini (`POST`) yakalıyor.
Future<FakeApi> _pumpCreate(
  WidgetTester tester, {
  required List<Map<String, dynamic>> companies,
  required Brightness brightness,
}) async {
  final userApi = FakeApi(
    handler: (_) => FakeApiResponse(
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
          'companies': companies,
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
  final jobsApi = FakeApi(
    handler: (request) {
      if (request.method == 'POST') {
        return FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'job-new',
              'title': 'Etkinlik fotoğrafçısı',
              'category': _category,
              'type': 'ONE_TIME',
              'employerType': companies.isEmpty ? 'INDIVIDUAL' : 'COMPANY',
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

  final router = GoRouter(
    initialLocation: _createLocation,
    routes: [
      GoRoute(
        path: _createLocation,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: BCreatePage(
            paymentService: BPaymentService.withClient(emptyApi.client),
            initialAddress: _moda,
          ),
        ),
      ),
      GoRoute(
        path: '/business/posts',
        pageBuilder: (context, state) =>
            const MaterialPage<void>(child: Scaffold(body: Text('ilanlarım'))),
      ),
      GoRoute(
        path: '/business/job-detail',
        pageBuilder: (context, state) => const MaterialPage<void>(
          child: Scaffold(body: Text('ilan detayı')),
        ),
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
  return jobsApi;
}

Finder _hideAddressRow() => find.widgetWithText(Row, 'Adresi gizle');

Finder _hideAddressSwitch() =>
    find.descendant(of: _hideAddressRow(), matching: find.byType(Switch));

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

Future<Map<dynamic, dynamic>> _publishAndReadBody(
  WidgetTester tester,
  FakeApi jobsApi,
) async {
  await tester.tap(findBottomBarButton());
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();

  final post = jobsApi.requests.where((r) => r.method == 'POST').single;
  return post.data as Map;
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('İlan formu adres görünürlüğü ($themeName tema)', () {
      testWidgets('şirket ilanında anahtar kapalı başlar; adres herkese açık '
          'gider', (tester) async {
        final jobsApi = await _pumpCreate(
          tester,
          companies: _approvedCompany,
          brightness: brightness,
        );

        expect(_hideAddressSwitch(), findsOneWidget);
        expect(tester.widget<Switch>(_hideAddressSwitch()).value, isFalse);
        expect(find.text(BCreatePage.addressPublicNotice), findsOneWidget);
        expect(find.text(BCreatePage.addressHiddenNotice), findsNothing);

        await _fillRequired(tester);
        final body = await _publishAndReadBody(tester, jobsApi);

        expect(
          jobsApi.requests.where((r) => r.method == 'POST').single.path,
          '/companies/company-1/jobs',
        );
        expect(body['addressPublic'], isTrue);
      });

      testWidgets('"Adresi gizle" açılınca metin değişir ve false gider', (
        tester,
      ) async {
        final jobsApi = await _pumpCreate(
          tester,
          companies: _approvedCompany,
          brightness: brightness,
        );

        await _tapVisible(tester, _hideAddressSwitch());

        expect(tester.widget<Switch>(_hideAddressSwitch()).value, isTrue);
        expect(find.text(BCreatePage.addressHiddenNotice), findsOneWidget);
        expect(find.text(BCreatePage.addressPublicNotice), findsNothing);

        await _fillRequired(tester);
        final body = await _publishAndReadBody(tester, jobsApi);

        expect(body['addressPublic'], isFalse);
      });

      testWidgets('bireysel ilanda anahtar ve açıklama yok, alan gitmiyor', (
        tester,
      ) async {
        final jobsApi = await _pumpCreate(
          tester,
          companies: const [],
          brightness: brightness,
        );

        expect(_hideAddressRow(), findsNothing);
        expect(find.text(BCreatePage.addressPublicNotice), findsNothing);
        expect(find.text(BCreatePage.addressHiddenNotice), findsNothing);

        await _fillRequired(tester);
        final body = await _publishAndReadBody(tester, jobsApi);

        expect(
          jobsApi.requests.where((r) => r.method == 'POST').single.path,
          '/users/me/jobs',
        );
        expect(body.containsKey('addressPublic'), isFalse);
      });
    });
  }
}
