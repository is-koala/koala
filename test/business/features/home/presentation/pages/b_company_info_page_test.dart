import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_info_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_gate_test_support.dart';
import '../../../../../support/reference_location_fixtures.dart';

const _companyJson = {
  'id': 'company_1',
  'name': 'Moda Kahve Atölyesi',
  'approved': false,
};

const _membership = {
  'companyId': 'company_1',
  'companyName': 'Moda Kahve Atölyesi',
  'approved': false,
  'role': 'ADMIN',
};

/// Bireysel işverenin (şirket üyeliği yok) ayarlardan şirket kurma yolunu
/// karşılayan sahte sunucu: `POST /companies` başarınca `/users/me` üyeliği
/// taşımaya başlıyor.
class _Server {
  _Server({required this.identityVerified});

  bool identityVerified;
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
        companies = const [_membership];
        return const FakeApiResponse(
          statusCode: 201,
          body: {'success': true, 'data': _companyJson},
        );
      case '/companies/company_1':
        return const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _companyJson},
        );
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
}

Future<_Server> _pumpCompanyInfo(
  WidgetTester tester, {
  required bool identityVerified,
  Brightness brightness = Brightness.light,
}) async {
  final server = _Server(identityVerified: identityVerified);
  final userProvider = UserProvider(
    userService: UserService.withClient(server.api.client),
  );
  await tester.runAsync(userProvider.load);

  final router = GoRouter(
    initialLocation: '/business/company-info',
    routes: [
      GoRoute(
        path: '/business/company-info',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const BCompanyInfoPage(),
        ),
      ),
      GoRoute(
        path: RegistrationRoutes.companyInformations,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          // Gerçek form; adres önceden dolu ki kayıt tek ekranda bitsin.
          child: CompanyInformationsPage(
            service: BCompanyService.withClient(server.api.client),
            referenceService: ReferenceLocationService.withClient(
              server.api.client,
            ),
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
          ),
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
        ChangeNotifierProvider(
          create: (_) => BCompanyProvider(
            service: BCompanyService.withClient(server.api.client),
            companyService: CompanyService.withClient(server.api.client),
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
  return server;
}

Future<void> _tapCreateCompany(WidgetTester tester) async {
  await tester.tap(find.text('Firma Kaydı Oluştur'));
  await tester.pumpAndSettle();
}

void main() {
  group('şirketi olmayan işveren', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada firma kaydı düğmesini görür', (
        tester,
      ) async {
        await _pumpCompanyInfo(
          tester,
          identityVerified: true,
          brightness: brightness,
        );

        expect(find.text('Kayıtlı firmanız yok'), findsOneWidget);
        expect(find.text('Firma Kaydı Oluştur'), findsOneWidget);
        expect(
          find.textContaining('henüz eklenmedi'),
          findsNothing,
          reason: 'Akış artık var; eski açıklama kullanıcıyı yanıltır.',
        );
      });
    }

    testWidgets('doğrulanmışsa düğme şirket formunu açar', (tester) async {
      await _pumpCompanyInfo(tester, identityVerified: true);

      await _tapCreateCompany(tester);

      expect(find.text('Kimlik doğrulaması gerekli'), findsNothing);
      expect(find.text('Şirket Bilgilerini Giriniz'), findsOneWidget);
    });

    testWidgets('doğrulanmamışsa düğme önce kimlik ekranına götürür', (
      tester,
    ) async {
      await _pumpCompanyInfo(tester, identityVerified: false);

      await _tapCreateCompany(tester);

      expect(find.text('Şirket Bilgilerini Giriniz'), findsNothing);
      expect(find.text('Kimlik doğrulaması gerekli'), findsOneWidget);

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(find.text(identityStubTitle), findsOneWidget);
    });

    testWidgets('kurulan şirket dönüşte firma bilgilerinde görünür', (
      tester,
    ) async {
      await _pumpCompanyInfo(tester, identityVerified: true);
      await _tapCreateCompany(tester);

      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field('Firma Adı*'), 'Moda Kahve Atölyesi');
      await tester.enterText(field('Vergi Numarası*'), '1234567890');
      await tester.enterText(field('Şirket Numarası*'), '+905551112233');
      await tester.enterText(field('Şirket E-posta*'), 'merhaba@moda.test');
      final save = find.text('KAYDET');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Şirket Bilgilerini Giriniz'), findsNothing);
      expect(find.text('Kayıtlı firmanız yok'), findsNothing);
      expect(find.text('Firma Bilgileri'), findsWidgets);
      expect(
        tester.widget<TextField>(field('Firma Adı')).controller?.text,
        'Moda Kahve Atölyesi',
      );
    });
  });
}
