import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_address_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_address_search_gateway.dart';
import '../../../../../support/fake_api.dart';
import '../../../../../support/fake_maps_availability.dart';

const _originLocation = '/business/company-info';
const _addressLocation = '/business/company-address';

Map<String, dynamic> _address({required bool saved}) => {
  'id': saved ? 'address-2' : 'address-1',
  'countryId': 'country-1',
  'countryName': 'TÜRKİYE',
  'countryCode': 'TR',
  'cityId': 'city-1',
  'cityName': 'İSTANBUL',
  'districtId': 'district-1',
  'districtName': 'KADIKÖY',
  'components': {
    'neighborhood': saved ? 'Caferağa Mahallesi' : 'Eski Mahalle',
    'thoroughfare': saved ? 'Moda Caddesi' : 'Eski Sokak',
    'buildingNumber': saved ? '12' : '1',
    'postalCode': saved ? '34710' : '34000',
  },
  'position': {
    'latitude': saved ? 40.982512 : 40.99,
    'longitude': saved ? 29.025411 : 29.03,
    'source': 'USER_CONFIRMED_PIN',
  },
  'displayAddress': saved
      ? 'Moda Caddesi 12, Caferağa Mahallesi'
      : 'Eski Sokak 1, Eski Mahalle',
  'canonicalVersion': 1,
  'needsReview': false,
};

/// `GET`/`PATCH /companies/company_1` ve istatistik ucunu karşılayan sahte
/// sunucu; adres yazıldıktan sonra şirket yeni adresi taşıyor.
class _Server {
  bool saved = false;
  FakeApiResponse? patchResponse;

  late final FakeApi api = FakeApi(handler: handle);

  FakeApiResponse handle(RequestOptions request) {
    switch (request.path) {
      case '/companies/company_1':
        if (request.method == 'PATCH') {
          final override = patchResponse;
          if (override != null) return override;
          saved = true;
        }
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'company_1',
              'name': 'Moda Kahve Atölyesi',
              'address': _address(saved: saved),
            },
          },
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
    return const FakeApiResponse(statusCode: 404, body: {'success': false});
  }

  RequestOptions get patchRequest =>
      api.requests.singleWhere((request) => request.method == 'PATCH');

  Map<String, dynamic> get patchBody =>
      patchRequest.data as Map<String, dynamic>;
}

void main() {
  late _Server server;
  late BCompanyProvider provider;

  setUp(() => server = _Server());

  /// Firma bilgilerini temsil eden kökten şirket adresi ekranını açar.
  ///
  /// [withCompany] `false` ise sağlayıcı boş: ekran harita yerine "firmanız
  /// yok" durumunu çizmeli, çökmemeli.
  Future<void> pumpAddress(
    WidgetTester tester, {
    bool withCompany = true,
    bool mapsAvailable = true,
    Brightness brightness = Brightness.light,
  }) async {
    provider = BCompanyProvider(
      service: BCompanyService.withClient(server.api.client),
      companyService: CompanyService.withClient(server.api.client),
    );
    if (withCompany) {
      // Sahte ağ gerçek zamanda çalışıyor; widget testinin sahte saatinde
      // beklenirse hiç dönmez.
      await tester.runAsync(
        () => provider.load(userId: 'employer-1', companyId: 'company_1'),
      );
    }

    final router = GoRouter(
      initialLocation: _originLocation,
      routes: [
        GoRoute(
          path: _originLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: Scaffold(
              body: Consumer<BCompanyProvider>(
                builder: (context, provider, _) => Text(
                  provider.company?.address?.displayAddress ?? 'Adres yok',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: _addressLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: BCompanyAddressPage(
              addressSearchGateway: FakeAddressSearchGateway(),
              referenceService: ReferenceLocationService.withClient(
                server.api.client,
              ),
              locationSource: FakeDeviceLocationSource(),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      withMapsAvailability(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp.router(
            theme: brightness == Brightness.dark ? darkTheme : lightTheme,
            routerConfig: router,
          ),
        ),
        available: mapsAvailable,
      ),
    );
    await tester.pumpAndSettle();

    router.push(_addressLocation);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const ValueKey('address-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} temada kayıtlı adres haritayı kendi pinine açar',
      (tester) async {
        await pumpAddress(tester, brightness: brightness);

        expect(find.byType(MapFirstAddressPage), findsOneWidget);
        expect(find.text('Şirket Adresi'), findsOneWidget);
        final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(map.initialCameraPosition.target, const LatLng(40.99, 29.03));
        expect(find.text('KADIKÖY'), findsOneWidget);
      },
    );
  }

  // is-koala/koala#172 ile aynı kural: harita anahtarı olmayan derlemede
  // ekran çökmez, kayıtlı pin korunur ve kayıt haritasız da çalışır.
  testWidgets(
    'harita yokken yer tutucu çizer ve pini USER_CONFIRMED_PIN ile PATCH eder',
    (tester) async {
      await pumpAddress(tester, mapsAvailable: false);

      expect(find.byType(GoogleMap), findsNothing);
      expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);

      await tapSave(tester);

      expect(server.patchRequest.path, '/companies/company_1');
      expect(server.patchBody.keys, ['address']);
      expect(server.patchBody['address']['position'], {
        'latitude': 40.99,
        'longitude': 29.03,
        'source': 'USER_CONFIRMED_PIN',
      });
      expect(server.patchBody['address']['candidateToken'], isNull);
      expect(find.byType(MapFirstAddressPage), findsNothing);
      expect(find.text('Şirket adresiniz kaydedildi'), findsOneWidget);
      // Çağıran ekran tazelenmiş sağlayıcıdan yeni adresi gösteriyor.
      expect(find.text('Moda Caddesi 12, Caferağa Mahallesi'), findsOneWidget);
    },
  );

  testWidgets('sunucu reddederse ekran açık kalır, sağlayıcı değişmez', (
    tester,
  ) async {
    server.patchResponse = const FakeApiResponse(
      statusCode: 404,
      body: {
        'success': false,
        'message': 'Bu şirkette yetkiniz yok.',
        'errorCode': 'USER_NOT_ASSOCIATED_WITH_COMPANY',
        'errorCategory': 'RESOURCE_NOT_FOUND',
      },
    );
    await pumpAddress(tester);

    await tapSave(tester);

    expect(find.byType(MapFirstAddressPage), findsOneWidget);
    expect(find.text('Bu şirkette yetkiniz yok.'), findsOneWidget);
    expect(provider.company?.address?.displayAddress, contains('Eski'));
  });

  testWidgets('şirket yüklü değilse harita yerine firmanız yok durumu', (
    tester,
  ) async {
    await pumpAddress(tester, withCompany: false);

    expect(find.byType(MapFirstAddressPage), findsNothing);
    expect(find.text('Şirket Adresi'), findsOneWidget);
    expect(find.text('Kayıtlı firmanız yok'), findsOneWidget);
    expect(server.api.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });
}
