import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_address_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_info_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/providers/map_first_address_controller.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_address_search_gateway.dart';
import '../../../../../support/fake_api.dart';
import '../../../../../support/fake_maps_availability.dart';
import '../../../../../support/identity_gate_test_support.dart';
import '../../../../../support/keyboard.dart';

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

/// Aynı şirketin yönetici olmayan yetkilisi (is-koala/koala#184).
const _contactMembership = {
  'companyId': 'company_1',
  'companyName': 'Moda Kahve Atölyesi',
  'approved': false,
  'role': 'CONTACT',
};

/// Şirketin kayıtlı adresi; [saved] `true` ise haritada yeni seçilen hâli.
Map<String, dynamic> _companyAddress({required bool saved}) => {
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
    'source': saved ? 'REVERSE_GEOCODE_CONFIRMED' : 'USER_CONFIRMED_PIN',
  },
  'displayAddress': saved
      ? 'Moda Caddesi 12, Caferağa Mahallesi'
      : 'Eski Sokak 1, Eski Mahalle',
  'canonicalVersion': 1,
  'needsReview': false,
};

/// Haritadan gelen ham kamera hedefi; sunucu altı ondalık ister.
const _rawPin = LatLng(40.98251234567, 29.02541134567);

/// Bireysel işverenin (şirket üyeliği yok) ayarlardan şirket kurma yolunu
/// karşılayan sahte sunucu: `POST /companies` başarınca `/users/me` üyeliği
/// taşımaya başlıyor.
class _Server {
  _Server({
    required this.identityVerified,
    this.companies = const [],
    this.withAddress = false,
  });

  bool identityVerified;
  List<Map<String, dynamic>> companies;

  /// Şirket kaydı adres taşısın mı; adres bölümü testleri için.
  final bool withAddress;

  /// Adres haritadan kaydedildi mi; sonrasında şirket yeni adresi taşıyor.
  bool addressSaved = false;

  /// `PATCH /companies/company_1` yerine dönecek yanıt (eski sunucu hatası).
  FakeApiResponse? patchResponse;

  Map<String, dynamic> get company => withAddress
      ? {..._companyJson, 'address': _companyAddress(saved: addressSaved)}
      : _companyJson;

  RequestOptions get patchRequest =>
      api.requests.singleWhere((request) => request.method == 'PATCH');

  Map<String, dynamic> get patchBody =>
      patchRequest.data as Map<String, dynamic>;

  /// `/users/me`'nin daha kaç kez `500` döneceği; ana sayfanın sessiz
  /// yüklemesi düşmüş bir kullanıcıyı canlandırıyor.
  int meFailuresLeft = 0;

  late final FakeApi api = FakeApi(handler: handle);

  FakeApiResponse handle(RequestOptions request) {
    switch (request.path) {
      case '/users/me':
        if (meFailuresLeft > 0) {
          meFailuresLeft--;
          return const FakeApiResponse(
            statusCode: 500,
            body: {
              'success': false,
              'message': 'Sunucu hatası',
              'errorCategory': 'INTERNAL_ERROR',
            },
          );
        }
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
        if (request.method == 'PATCH') {
          final override = patchResponse;
          if (override != null) return override;
          if ((request.data as Map).containsKey('address')) {
            addressSaved = true;
          }
        }
        return FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': company},
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
  List<Map<String, dynamic>> companies = const [],
  Brightness brightness = Brightness.light,
  bool withAddress = false,
  FakeAddressSearchGateway? gateway,

  /// `false`: sayfa `/users/me` hiç okunmamışken açılıyor — ana sayfanın
  /// sessiz yüklemesi düşmüş ya da kullanıcı doğrudan buraya gelmiş.
  bool preloadUser = true,

  /// `/users/me` ilk kaç istekte düşsün.
  int meFailures = 0,

  /// `false`: ilk kareden sonra durup ara durumu incelemek için.
  bool settle = true,
}) async {
  final server = _Server(
    identityVerified: identityVerified,
    companies: companies,
    withAddress: withAddress,
  )..meFailuresLeft = meFailures;
  final userProvider = UserProvider(
    userService: UserService.withClient(server.api.client),
  );
  if (preloadUser) await tester.runAsync(userProvider.load);

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
          // Gerçek form; adres haritada onaylanmış gibi hazır ki kayıt tek
          // ekranda bitsin.
          child: CompanyInformationsPage(
            service: BCompanyService.withClient(server.api.client),
            initialAddress: const ConfirmedAddress(
              country: ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
              city: ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
              district: ReferenceLocation(id: 'district-1', name: 'KADIKÖY'),
              components: AddressComponents(
                neighborhood: 'Caferağa Mahallesi',
                thoroughfare: 'Moda Caddesi',
                buildingNumber: '12',
                postalCode: '34710',
              ),
              position: AddressPosition(
                latitude: 40.9819,
                longitude: 29.0263,
                source: AddressPositionSource.userConfirmedPin,
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/business/company-address',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          // Gerçek harita ekranı: sahte geokod ve konum kaynağıyla.
          child: BCompanyAddressPage(
            addressSearchGateway: gateway ?? FakeAddressSearchGateway(),
            referenceService: ReferenceLocationService.withClient(
              server.api.client,
            ),
            locationSource: FakeDeviceLocationSource(),
          ),
        ),
      ),
      stubIdentityVerificationRoute(),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    withMapsAvailability(
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
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return server;
}

Future<void> _tapCreateCompany(WidgetTester tester) async {
  await tester.tap(find.text('Firma Kaydı Oluştur'));
  await tester.pumpAndSettle();
}

final _changeAddressButton = find.byKey(
  const ValueKey('company-address-change'),
);

Future<void> _openAddressMap(WidgetTester tester) async {
  await tester.ensureVisible(_changeAddressButton);
  await tester.pump();
  await tester.tap(_changeAddressButton);
  await tester.pumpAndSettle();
  expect(find.byType(MapFirstAddressPage), findsOneWidget);
}

Future<void> _dropPin(WidgetTester tester, LatLng target) async {
  final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
  map.onCameraMove!(CameraPosition(target: target));
  map.onCameraIdle!();
  await tester.pump(MapFirstAddressController.defaultReverseDebounce);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('address-save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('kullanıcı yüklenmemişken', () {
    testWidgets(
      'şirketi olan işverene kurma düğmesi gösterilmez, şirket gelir',
      (tester) async {
        await _pumpCompanyInfo(
          tester,
          identityVerified: true,
          companies: const [_membership],
          preloadUser: false,
          settle: false,
        );

        // İlk kare: kullanıcı daha okunmadı. "Firmanız yok" demek, şirketi
        // olan işverene ikinci bir şirket kurdurmak olur.
        expect(find.text('Firma Kaydı Oluştur'), findsNothing);
        expect(find.text('Kayıtlı firmanız yok'), findsNothing);

        await tester.pump();
        expect(find.text('Firma Kaydı Oluştur'), findsNothing);

        await tester.pumpAndSettle();

        expect(find.text('Firma Kaydı Oluştur'), findsNothing);
        expect(find.text('Kayıtlı firmanız yok'), findsNothing);
        expect(
          tester
              .widget<TextField>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is TextField &&
                      widget.decoration?.labelText == 'Firma Adı',
                ),
              )
              .controller
              ?.text,
          'Moda Kahve Atölyesi',
        );
      },
    );

    testWidgets(
      '/users/me düşerse tekrar dene gösterilir, kurma düğmesi değil',
      (tester) async {
        await _pumpCompanyInfo(
          tester,
          identityVerified: true,
          preloadUser: false,
          meFailures: 1,
        );

        expect(find.text('Firma Kaydı Oluştur'), findsNothing);
        expect(find.text('Tekrar Dene'), findsOneWidget);

        // Sunucu toparladı: kullanıcı okunuyor, şirketi yok, düğme şimdi doğru.
        await tester.tap(find.text('Tekrar Dene'));
        await tester.pumpAndSettle();

        expect(find.text('Kayıtlı firmanız yok'), findsOneWidget);
        expect(find.text('Firma Kaydı Oluştur'), findsOneWidget);
      },
    );
  });

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

  // is-koala/koala#184: adres artık "Değiştirilemeyen Bilgiler"de değil;
  // ADMIN haritadan değiştiriyor, diğer yetkililer salt okunur görüyor.
  group('şirket adresi', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada ADMIN adresi ve düğmeyi görür', (
        tester,
      ) async {
        await _pumpCompanyInfo(
          tester,
          identityVerified: true,
          companies: const [_membership],
          withAddress: true,
          brightness: brightness,
        );

        expect(find.text('Şirket Adresi'), findsOneWidget);
        expect(find.text('Eski Sokak 1, Eski Mahalle'), findsOneWidget);
        expect(find.text('KADIKÖY'), findsOneWidget);
        expect(find.text('İSTANBUL'), findsOneWidget);
        expect(_changeAddressButton, findsOneWidget);
        expect(find.text('Adresi değiştir'), findsOneWidget);
        expect(find.textContaining('yalnızca şirket yöneticisi'), findsNothing);
        // Kilitli bölümün notu artık yalnız vergi numarasını anlatıyor.
        expect(find.textContaining('Vergi numarası ve adres'), findsNothing);
        expect(find.textContaining('Vergi numarası firma'), findsOneWidget);
      });

      testWidgets(
        '${brightness.name} temada CONTACT adresi salt okunur görür',
        (tester) async {
          await _pumpCompanyInfo(
            tester,
            identityVerified: true,
            companies: const [_contactMembership],
            withAddress: true,
            brightness: brightness,
          );

          expect(find.text('Eski Sokak 1, Eski Mahalle'), findsOneWidget);
          expect(find.text('KADIKÖY'), findsOneWidget);
          expect(_changeAddressButton, findsNothing);
          expect(find.text('Adresi değiştir'), findsNothing);
          expect(
            find.textContaining('yalnızca şirket yöneticisi'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('adressiz şirkette bölüm "kayıtlı değil" der', (tester) async {
      await _pumpCompanyInfo(
        tester,
        identityVerified: true,
        companies: const [_membership],
      );

      expect(find.text('Adres kayıtlı değil'), findsOneWidget);
      expect(_changeAddressButton, findsOneWidget);
    });

    testWidgets(
      'Adresi değiştir haritayı şirket pinine açar; kayıt PATCH gövdesinde '
      'address taşır, sağlayıcı tazelenir ve sayfa yeni adresi gösterir',
      (tester) async {
        final gateway = FakeAddressSearchGateway();
        final server = await _pumpCompanyInfo(
          tester,
          identityVerified: true,
          companies: const [_membership],
          withAddress: true,
          gateway: gateway,
        );

        await _openAddressMap(tester);

        expect(find.text('Şirket Adresi'), findsOneWidget);
        final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(map.initialCameraPosition.target, const LatLng(40.99, 29.03));
        expect(find.text('KADIKÖY'), findsOneWidget);
        expect(
          gateway.reverseCalls,
          isEmpty,
          reason: 'pin oynamadan istek yok',
        );

        await _dropPin(tester, _rawPin);
        await _tapSave(tester);

        expect(server.patchRequest.path, '/companies/company_1');
        expect(server.patchBody.keys, ['address']);
        expect(server.patchBody['address'], {
          'countryId': 'country-1',
          'cityId': 'city-1',
          'districtId': 'district-1',
          'components': {
            'neighborhood': 'Caferağa Mahallesi',
            'thoroughfare': 'Moda Caddesi',
            'buildingNumber': '12',
            'postalCode': '34710',
          },
          'position': {
            'latitude': 40.982512,
            'longitude': 29.025411,
            'source': 'REVERSE_GEOCODE_CONFIRMED',
          },
          'candidateToken': 'reverse-proof',
        });

        // Harita kapandı, firma bilgileri sağlayıcıdan yeni adresi çiziyor.
        expect(find.byType(MapFirstAddressPage), findsNothing);
        expect(find.text('Şirket adresiniz kaydedildi'), findsOneWidget);
        expect(
          find.text('Moda Caddesi 12, Caferağa Mahallesi'),
          findsOneWidget,
        );
        expect(find.text('Eski Sokak 1, Eski Mahalle'), findsNothing);
        // Şirket yeniden okunmadı: PATCH yanıtı yeterli.
        expect(
          server.api.requests
              .where(
                (r) => r.method == 'GET' && r.path == '/companies/company_1',
              )
              .length,
          1,
        );
      },
    );

    testWidgets(
      'eski sunucu adresi reddederse harita açık kalır ve hata toast olur',
      (tester) async {
        final server = await _pumpCompanyInfo(
          tester,
          identityVerified: true,
          companies: const [_membership],
          withAddress: true,
        );
        server.patchResponse = const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Geçersiz alan: address',
            'errorCategory': 'VALIDATION_FAILED',
          },
        );

        await _openAddressMap(tester);
        await _dropPin(tester, _rawPin);
        await _tapSave(tester);

        expect(find.byType(MapFirstAddressPage), findsOneWidget);
        expect(find.text('Geçersiz alan: address'), findsOneWidget);
        expect(find.text('Şirket adresiniz kaydedildi'), findsNothing);

        // Geri dönünce eski adres duruyor.
        await tester.tap(find.byTooltip('Geri'));
        await tester.pumpAndSettle();
        expect(find.text('Eski Sokak 1, Eski Mahalle'), findsOneWidget);
      },
    );
  });

  group('klavye', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} tema: Kaydet çubuğu klavyenin üstüne çıkar, boş '
        'alana dokununca odak düşer',
        (tester) async {
          await _pumpCompanyInfo(
            tester,
            identityVerified: true,
            companies: const [_membership],
            brightness: brightness,
          );
          await showKeyboard(tester);

          await expectAboveKeyboard(tester, findBottomBarButton());
          await expectTapOutsideDropsFocus(
            tester,
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.labelText == 'Telefon',
            ),
          );
        },
      );
    }
  });
}
