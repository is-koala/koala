import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/employer_type_page.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';
import '../../../../../support/identity_gate_test_support.dart';
import '../../../../../support/reference_location_fixtures.dart';

const _companyResponse = {
  'success': true,
  'data': {'id': 'company_1', 'name': 'Moda Kahve Atölyesi', 'approved': false},
};

/// Sunucunun `POST /companies`'i doğrulanmamış kullanıcıda reddettiği zarf
/// (`CompanyManager.addCompany` → `ValidationException`, `400`).
const _identityRequiredResponse = FakeApiResponse(
  statusCode: 400,
  body: {
    'success': false,
    'message': 'Bu işlem için kimliğinizi doğrulamanız gerekiyor.',
    'errorCode': 'USER_MUST_VERIFY_IDENTITY',
    'errorCategory': 'VALIDATION_FAILED',
  },
);

const _membership = {
  'companyId': 'company_1',
  'companyName': 'Moda Kahve Atölyesi',
  'approved': false,
  'role': 'ADMIN',
};

const _companyDraft = 'Kaydedilmemiş taslak';
const _originDraft = 'Korunan taslak';
const _originDraftKey = ValueKey('origin-draft');
const _originLocation = '/origin';
const _businessHomeLocation = '/business/home';
const _businessHomeTitle = 'İşveren ana sayfası';

/// Şirket formunun konuştuğu bütün uçları karşılayan sahte sunucu.
///
/// Durumu var: `POST /companies` başarılı olunca `/users/me` üyeliği
/// taşımaya başlıyor, tıpkı gerçek sunucuda olduğu gibi. Kayıt sonrası
/// tazeleme iddiası buna dayanıyor.
class _CompanyServer {
  /// Kullanıcı doğrulanmış açılıyor; kapı testleri kendi sunucusunda,
  /// burası formun sunucuya nasıl tepki verdiğine bakıyor.
  bool identityVerified = true;

  FakeApiResponse createResponse = const FakeApiResponse(
    statusCode: 201,
    body: _companyResponse,
  );

  List<Map<String, dynamic>> companies = const [];

  late final FakeApi api = FakeApi(handler: handle);

  FakeApiResponse handle(RequestOptions request) {
    final reference = istanbulReferenceResponse(request.path);
    if (reference != null) return reference;

    switch (request.path) {
      case '/users/me':
        return FakeApiResponse(
          statusCode: 200,
          body: employerMeResponse(
            identityVerified: identityVerified,
            companies: companies,
          ),
        );
      case '/companies':
        if (createResponse.statusCode == 201) companies = const [_membership];
        return createResponse;
      case '/companies/company_1':
        return const FakeApiResponse(statusCode: 200, body: _companyResponse);
      case '/users/employer-1/employer-stats':
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'userId': 'employer-1', 'jobsPosted': 0},
          },
        );
    }
    return const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': <Object>[]},
    );
  }

  List<String> get paths => api.requests.map((r) => r.path).toList();
}

void main() {
  late _CompanyServer server;
  late UserProvider userProvider;
  late BCompanyProvider companyProvider;

  setUp(() {
    server = _CompanyServer();
  });

  /// Adres formunu atlayıp doğrudan kaydedilebilir bir şirket formu.
  CompanyInformationsPage companyPage({VoidCallback? onSaved}) {
    return CompanyInformationsPage(
      service: BCompanyService.withClient(server.api.client),
      referenceService: ReferenceLocationService.withClient(server.api.client),
      initialLocation: const LatLng(40.9819, 29.0263),
      initialAddress: const CanonicalAddress(
        id: 'address-1',
        countryId: 'country-1',
        countryName: 'TÜRKİYE',
        countryCode: 'TR',
        cityId: 'city-1',
        cityName: 'İSTANBUL',
        districtId: 'district-1',
        districtName: 'KADIKÖY',
        components: AddressComponents(
          neighborhood: 'Caferağa Mahallesi',
          thoroughfare: 'Moda Caddesi',
          buildingNumber: '12',
          postalCode: '34710',
        ),
        canonicalVersion: 1,
        needsReview: false,
      ),
      onSaved: onSaved,
    );
  }

  Future<GoRouter> pumpRegistrationFlow(
    WidgetTester tester, {
    String initialLocation = RegistrationRoutes.employerType,
    CompanyInformationsPage Function()? companyPageBuilder,
  }) async {
    userProvider = UserProvider(
      userService: UserService.withClient(server.api.client),
    );
    await tester.runAsync(userProvider.load);
    companyProvider = BCompanyProvider(
      service: BCompanyService.withClient(server.api.client),
      companyService: CompanyService.withClient(server.api.client),
    );

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RegistrationRoutes.employerType,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const EmployerTypePage(),
          ),
        ),
        GoRoute(
          path: RegistrationRoutes.companyInformations,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child:
                companyPageBuilder?.call() ??
                CompanyInformationsPage(
                  service: BCompanyService.withClient(server.api.client),
                  referenceService: ReferenceLocationService.withClient(
                    server.api.client,
                  ),
                ),
          ),
        ),
        GoRoute(
          path: _originLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: TextField(key: _originDraftKey)),
          ),
        ),
        GoRoute(
          path: _businessHomeLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: Text(_businessHomeTitle)),
          ),
        ),
        stubIdentityVerificationRoute(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userProvider),
          ChangeNotifierProvider.value(value: companyProvider),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> goToCompany(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('employer-type-company')));
    await tester.pumpAndSettle();
  }

  TextEditingController textController(WidgetTester tester, Key fieldKey) {
    return tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(fieldKey),
            matching: find.byType(EditableText),
          ),
        )
        .controller;
  }

  Finder labelledField(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  TextEditingController companyNameController(WidgetTester tester) =>
      tester.widget<TextField>(labelledField('Firma Adı*')).controller!;

  Finder companyNameField() => labelledField('Firma Adı*');

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tester.enterText(labelledField('Firma Adı*'), 'Moda Kahve Atölyesi');
    await tester.enterText(labelledField('Vergi Numarası*'), '1234567890');
    await tester.enterText(labelledField('Şirket Numarası*'), '+905551112233');
    await tester.enterText(
      labelledField('Şirket E-posta*'),
      'merhaba@modakahve.test',
    );
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.text('KAYDET');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  Future<void> arrangeEmptyStackCompanyDraft(WidgetTester tester) async {
    final router = await pumpRegistrationFlow(tester);
    await goToCompany(tester);
    await tester.enterText(companyNameField(), _companyDraft);
    expect(router.canPop(), isFalse);
  }

  Future<void> expectFallbackDiscardedCompanyDraft(WidgetTester tester) async {
    expect(find.text('Nasıl iş vermek istersin?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await goToCompany(tester);
    expect(companyNameController(tester).text, isEmpty);
  }

  Future<void> arrangePopulatedStackWithOriginDraft(WidgetTester tester) async {
    final router = await pumpRegistrationFlow(
      tester,
      initialLocation: _originLocation,
    );
    await tester.enterText(find.byKey(_originDraftKey), _originDraft);
    router.push(RegistrationRoutes.companyInformations);
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
  }

  void expectOriginDraftPreserved(WidgetTester tester) {
    expect(find.byKey(_originDraftKey), findsOneWidget);
    expect(textController(tester, _originDraftKey).text, _originDraft);
  }

  testWidgets('boş stackte iOS geri oku önceki kayıt adımına döner', (
    tester,
  ) async {
    await arrangeEmptyStackCompanyDraft(tester);

    await tester.tap(findAppIcon(AppIcons.arrowLeft));
    await tester.pumpAndSettle();

    await expectFallbackDiscardedCompanyDraft(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('boş stackte Android geri eylemi önceki kayıt adımına döner', (
    tester,
  ) async {
    await arrangeEmptyStackCompanyDraft(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    await expectFallbackDiscardedCompanyDraft(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'tarayıcı geçmişi önceki kayıt adımını aynı state kaybıyla geri yükler',
    (tester) async {
      final router = await pumpRegistrationFlow(tester);
      final previousHistoryEntry = router.routeInformationProvider.value;
      await goToCompany(tester);
      await tester.enterText(companyNameField(), _companyDraft);

      await router.routeInformationProvider.didPushRouteInformation(
        previousHistoryEntry,
      );
      await tester.pumpAndSettle();

      await expectFallbackDiscardedCompanyDraft(tester);
    },
  );

  testWidgets(
    'dolu stackte iOS kenar hareketi doğal pop yapıp önceki state\'i korur',
    (tester) async {
      await arrangePopulatedStackWithOriginDraft(tester);

      await tester.dragFrom(const Offset(0, 300), const Offset(500, 0));
      await tester.pumpAndSettle();

      expectOriginDraftPreserved(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'dolu stackte Android geri eylemi doğal pop yapıp önceki state\'i korur',
    (tester) async {
      await arrangePopulatedStackWithOriginDraft(tester);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expectOriginDraftPreserved(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('şirket formu gerçek oluşturma servisini çağırır', (
    tester,
  ) async {
    var saved = false;

    await pumpRegistrationFlow(
      tester,
      initialLocation: RegistrationRoutes.companyInformations,
      companyPageBuilder: () => companyPage(onSaved: () => saved = true),
    );

    await fillRequiredFields(tester);
    await tapSave(tester);

    expect(saved, isTrue);
    expect(server.paths, contains('/companies'));
  });

  group('kimlik kapısı', () {
    testWidgets(
      'sunucu kimlik zorunluluğu dönerse ham toast yerine doğrulama akışı '
      'açılır ve taslak korunur',
      (tester) async {
        // Bayrak yerelde doğrulanmış görünüyor; son sözü sunucu söylüyor.
        server.createResponse = _identityRequiredResponse;
        await pumpRegistrationFlow(
          tester,
          initialLocation: RegistrationRoutes.companyInformations,
          companyPageBuilder: () => companyPage(),
        );

        await fillRequiredFields(tester);
        await tapSave(tester);

        expect(
          find.text('Bu işlem için kimliğinizi doğrulamanız gerekiyor.'),
          findsNothing,
          reason: 'Sunucu metni ham toast olarak gösterilmemeli.',
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text('Kimlik doğrulaması gerekli'), findsOneWidget);

        await tester.tap(find.text('Doğrula'));
        await tester.pumpAndSettle();
        expect(find.text(identityStubTitle), findsOneWidget);

        final meRequestsBefore = server.paths
            .where((path) => path == '/users/me')
            .length;
        server.identityVerified = true;
        await tester.tap(find.byKey(identityVerifiedKey));
        await tester.pumpAndSettle();

        expect(
          server.paths.where((path) => path == '/users/me').length,
          meRequestsBefore + 1,
        );
        expect(
          companyNameController(tester).text,
          'Moda Kahve Atölyesi',
          reason: 'Kullanıcı doğrulamadan dönünce formu yeniden doldurmamalı.',
        );
      },
    );

    testWidgets('başka bir sunucu hatası eskisi gibi toast olarak kalır', (
      tester,
    ) async {
      server.createResponse = const FakeApiResponse(
        statusCode: 400,
        body: {
          'success': false,
          'message': 'Geçersiz şirket türü.',
          'errorCode': 'INVALID_COMPANY_TYPE',
          'errorCategory': 'VALIDATION_FAILED',
        },
      );
      await pumpRegistrationFlow(
        tester,
        initialLocation: RegistrationRoutes.companyInformations,
        companyPageBuilder: () => companyPage(),
      );

      await fillRequiredFields(tester);
      await tapSave(tester);

      expect(find.text('Geçersiz şirket türü.'), findsOneWidget);
      expect(find.text('Kimlik doğrulaması gerekli'), findsNothing);
    });
  });

  group('kayıt sonrası', () {
    testWidgets('üyelik ve şirket sağlayıcısı tazelenir', (tester) async {
      await pumpRegistrationFlow(
        tester,
        initialLocation: RegistrationRoutes.companyInformations,
        companyPageBuilder: () => companyPage(),
      );
      expect(userProvider.user?.primaryCompany, isNull);

      await fillRequiredFields(tester);
      await tapSave(tester);

      final createIndex = server.paths.indexOf('/companies');
      final refreshed = server.paths.sublist(createIndex + 1);
      expect(refreshed, contains('/users/me'));
      expect(refreshed, contains('/companies/company_1'));
      expect(userProvider.user?.primaryCompany?.companyId, 'company_1');
      expect(companyProvider.company?.id, 'company_1');
    });

    testWidgets('kayıt akışındaki form işveren ana sayfasına gider', (
      tester,
    ) async {
      await pumpRegistrationFlow(
        tester,
        initialLocation: RegistrationRoutes.companyInformations,
        companyPageBuilder: () => companyPage(),
      );

      await fillRequiredFields(tester);
      await tapSave(tester);

      expect(find.text(_businessHomeTitle), findsOneWidget);
    });

    testWidgets('ayarlardan açılan form kaydedince açıldığı ekrana döner', (
      tester,
    ) async {
      final router = await pumpRegistrationFlow(
        tester,
        initialLocation: _originLocation,
        companyPageBuilder: () => companyPage(),
      );
      bool? popResult;
      router.push<bool>(RegistrationRoutes.companyInformations).then((value) {
        popResult = value;
      });
      await tester.pumpAndSettle();

      await fillRequiredFields(tester);
      await tapSave(tester);

      expect(popResult, isTrue);
      expect(find.byKey(_originDraftKey), findsOneWidget);
      expect(find.text(_businessHomeTitle), findsNothing);
    });
  });
}
