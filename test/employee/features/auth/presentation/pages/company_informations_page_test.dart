import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/employer_type_page.dart';
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

void main() {
  Future<GoRouter> pumpRegistrationFlow(
    WidgetTester tester, {
    String initialLocation = '/employer-type',
  }) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': <Object>[]},
      ),
    );
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/employer-type',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const EmployerTypePage(),
          ),
        ),
        GoRoute(
          path: '/company-informations',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: CompanyInformationsPage(
              service: BCompanyService.withClient(api.client),
              referenceService: ReferenceLocationService.withClient(api.client),
            ),
          ),
        ),
        GoRoute(
          path: '/origin',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(
              body: TextField(key: ValueKey('origin-draft')),
            ),
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

  testWidgets('boş stackte iOS geri oku önceki kayıt adımına döner', (
    tester,
  ) async {
    final router = await pumpRegistrationFlow(tester);
    await goToCompany(tester);
    await tester.enterText(companyNameField(), 'Kaydedilmemiş taslak');

    expect(router.canPop(), isFalse);

    await tester.tap(findAppIcon(AppIcons.arrowLeft));
    await tester.pumpAndSettle();

    expect(find.text('Nasıl iş vermek istersin?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await goToCompany(tester);
    expect(companyNameController(tester).text, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('boş stackte Android geri eylemi önceki kayıt adımına döner', (
    tester,
  ) async {
    final router = await pumpRegistrationFlow(tester);
    await goToCompany(tester);
    await tester.enterText(companyNameField(), 'Kaydedilmemiş taslak');

    expect(router.canPop(), isFalse);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('Nasıl iş vermek istersin?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await goToCompany(tester);
    expect(companyNameController(tester).text, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'tarayıcı geçmişi önceki kayıt adımını aynı state kaybıyla geri yükler',
    (tester) async {
      final router = await pumpRegistrationFlow(tester);
      final previousHistoryEntry = router.routeInformationProvider.value;
      await goToCompany(tester);
      await tester.enterText(companyNameField(), 'Kaydedilmemiş taslak');

      await router.routeInformationProvider.didPushRouteInformation(
        previousHistoryEntry,
      );
      await tester.pumpAndSettle();

      expect(find.text('Nasıl iş vermek istersin?'), findsOneWidget);

      await goToCompany(tester);
      expect(companyNameController(tester).text, isEmpty);
    },
  );

  testWidgets(
    'dolu stackte iOS kenar hareketi doğal pop yapıp önceki state\'i korur',
    (tester) async {
      final router = await pumpRegistrationFlow(
        tester,
        initialLocation: '/origin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('origin-draft')),
        'Korunan taslak',
      );
      router.push('/company-informations');
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);

      await tester.dragFrom(const Offset(0, 300), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('origin-draft')), findsOneWidget);
      expect(
        textController(tester, const ValueKey('origin-draft')).text,
        'Korunan taslak',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'dolu stackte Android geri eylemi doğal pop yapıp önceki state\'i korur',
    (tester) async {
      final router = await pumpRegistrationFlow(
        tester,
        initialLocation: '/origin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('origin-draft')),
        'Korunan taslak',
      );
      router.push('/company-informations');
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byKey(const ValueKey('origin-draft')), findsOneWidget);
      expect(
        textController(tester, const ValueKey('origin-draft')).text,
        'Korunan taslak',
      );
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

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: CompanyInformationsPage(
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
