import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/employer_type_page.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/services/reference_location_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/finders.dart';

const _companyResponse = {
  'success': true,
  'data': {'id': 'company_1', 'name': 'Moda Kahve Atölyesi', 'approved': false},
};
const _companyDraft = 'Kaydedilmemiş taslak';
const _originDraft = 'Korunan taslak';
const _originDraftKey = ValueKey('origin-draft');
const _originLocation = '/origin';

void main() {
  Future<GoRouter> pumpRegistrationFlow(
    WidgetTester tester, {
    String initialLocation = RegistrationRoutes.employerType,
    FakeApi? fakeApi,
    CompanyInformationsPage Function(FakeApi api)? companyPageBuilder,
  }) async {
    final api =
        fakeApi ??
        FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': <Object>[]},
          ),
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
                companyPageBuilder?.call(api) ??
                CompanyInformationsPage(
                  service: BCompanyService.withClient(api.client),
                  referenceService: ReferenceLocationService.withClient(
                    api.client,
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
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: lightTheme, routerConfig: router),
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

  TextEditingController companyNameController(WidgetTester tester) {
    return tester
        .widget<TextField>(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Firma Adı*',
          ),
        )
        .controller!;
  }

  Finder companyNameField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'Firma Adı*',
  );

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
    final api = FakeApi(
      handler: (request) => switch (request.path) {
        '/reference/countries' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'country-1', 'name': 'TÜRKİYE', 'code': 'TR'},
            ],
          },
        ),
        '/reference/countries/country-1/cities' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'city-1', 'name': 'İSTANBUL'},
            ],
          },
        ),
        '/reference/cities/city-1/districts' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'district-1', 'name': 'KADIKÖY'},
            ],
          },
        ),
        _ => const FakeApiResponse(statusCode: 201, body: _companyResponse),
      },
    );
    var saved = false;

    await pumpRegistrationFlow(
      tester,
      initialLocation: RegistrationRoutes.companyInformations,
      fakeApi: api,
      companyPageBuilder: (api) => CompanyInformationsPage(
        service: BCompanyService.withClient(api.client),
        referenceService: ReferenceLocationService.withClient(api.client),
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
        onSaved: () => saved = true,
      ),
    );

    Future<void> enter(String label, String value) async {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field, value);
    }

    await enter('Firma Adı*', 'Moda Kahve Atölyesi');
    await enter('Vergi Numarası*', '1234567890');
    await enter('Şirket Numarası*', '+905551112233');
    await enter('Şirket E-posta*', 'merhaba@modakahve.test');

    final save = find.text('KAYDET');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(api.requests.last.path, '/companies');
  });
}
