import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/account/presentation/pages/address_page.dart';
import 'package:koala/product/providers/map_first_address_controller.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_address_search_gateway.dart';
import '../../../../../support/fake_api.dart';
import '../../../../../support/fake_maps_availability.dart';

const _originLocation = '/account-info';
const _addressLocation = '/address';

/// Haritadan gelen ham kamera hedefi; sunucu altı ondalık ister.
const _rawPin = LatLng(40.98251234567, 29.02541134567);

Map<String, dynamic> _savedAddress({required bool saved}) => {
  'id': 'address-1',
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

/// `/users/me` ve `PUT /users/me/address` uçlarını karşılayan sahte sunucu.
/// Adres yazıldıktan sonra `/users/me` yeni adresi taşımaya başlıyor.
class _Server {
  _Server({this.isEmployer = false});

  /// `/users/me` işveren mi dönsün. Adres ekranı iki rol için aynı; işveren
  /// de aynı `PUT`'u gönderiyor.
  final bool isEmployer;

  bool saved = false;
  FakeApiResponse? putResponse;

  late final FakeApi api = FakeApi(handler: handle);

  FakeApiResponse handle(RequestOptions request) {
    switch (request.path) {
      case '/users/me':
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'user-1',
              'firstName': 'Ada',
              'lastName': 'Kaya',
              'email': 'ada@ornek.com',
              'isEmployer': isEmployer,
              'address': _savedAddress(saved: saved),
            },
          },
        );
      case '/users/me/address':
        final override = putResponse;
        if (override != null) return override;
        saved = true;
        return FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _savedAddress(saved: true)},
        );
    }
    return const FakeApiResponse(statusCode: 404, body: {'success': false});
  }

  RequestOptions get putRequest =>
      api.requests.singleWhere((request) => request.method == 'PUT');

  Map<String, dynamic> get putBody {
    final data = putRequest.data;
    return data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
  }
}

void main() {
  late _Server server;
  late UserProvider userProvider;
  late FakeAddressSearchGateway gateway;

  setUp(() {
    server = _Server();
    gateway = FakeAddressSearchGateway();
  });

  /// Hesap ekranını temsil eden kökten `/address`'i açar ve dönüşü izler.
  ///
  /// [withExtra] `false` ise rota kullanıcısız açılıyor: ödeme kapısından
  /// gelen yönlendirme gibi, ekran kullanıcıyı sağlayıcıdan okumalı.
  Future<void> pumpAddress(
    WidgetTester tester, {
    bool withExtra = true,
    bool mapsAvailable = true,
  }) async {
    userProvider = UserProvider(
      userService: UserService.withClient(server.api.client),
    );
    await tester.runAsync(userProvider.load);
    final user = userProvider.user!;

    final router = GoRouter(
      initialLocation: _originLocation,
      routes: [
        GoRoute(
          path: _originLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: Scaffold(
              body: Consumer<UserProvider>(
                builder: (context, provider, _) =>
                    Text(provider.user?.address?.displayAddress ?? 'Adres yok'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: _addressLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: AddressPage(
              user: state.extra is CurrentUser
                  ? state.extra! as CurrentUser
                  : null,
              userService: UserService.withClient(server.api.client),
              addressSearchGateway: gateway,
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
          value: userProvider,
          child: MaterialApp.router(theme: lightTheme, routerConfig: router),
        ),
        available: mapsAvailable,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Eski Sokak 1, Eski Mahalle'), findsOneWidget);

    router.push(_addressLocation, extra: withExtra ? user : null);
    await tester.pumpAndSettle();
    expect(find.byType(MapFirstAddressPage), findsOneWidget);
  }

  Future<void> dropPin(WidgetTester tester, LatLng target) async {
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onCameraMove!(CameraPosition(target: target));
    map.onCameraIdle!();
    await tester.pump(MapFirstAddressController.defaultReverseDebounce);
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const ValueKey('address-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'kayıtlı adres haritayı kendi pinine açar ve alanları önceden doldurur',
    (tester) async {
      await pumpAddress(tester);

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.initialCameraPosition.target, const LatLng(40.99, 29.03));
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == 'Mahalle *',
              ),
            )
            .controller
            ?.text,
        'Eski Mahalle',
      );
      expect(find.text('KADIKÖY'), findsOneWidget);
      expect(gateway.reverseCalls, isEmpty, reason: 'pin oynamadan istek yok');
    },
  );

  // is-koala/koala#172: harita anahtarı olmayan derlemede kullanıcı adresi
  // ekranı çökmez; harita yerine yer tutucu, kayıtlı pin korunur ve kayıt
  // haritasız da çalışır.
  testWidgets(
    'harita anahtarı yokken yer tutucu çizer, kayıtlı pin korunur ve kaydeder',
    (tester) async {
      await pumpAddress(tester, mapsAvailable: false);

      expect(find.byType(GoogleMap), findsNothing);
      expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);
      expect(find.text('Harita bu derlemede kullanılamıyor'), findsOneWidget);
      expect(find.text('KADIKÖY'), findsOneWidget);
      expect(gateway.reverseCalls, isEmpty);

      await tapSave(tester);

      expect(server.putRequest.path, '/users/me/address');
      expect(server.putBody['position'], {
        'latitude': 40.99,
        'longitude': 29.03,
        'source': 'USER_CONFIRMED_PIN',
      });
      expect(server.putBody['candidateToken'], isNull);
      expect(find.byType(MapFirstAddressPage), findsNothing);
      expect(find.text('Adresiniz kaydedildi'), findsOneWidget);
    },
  );

  testWidgets(
    'pin → ters geokod → kaydet: AddressWriteV2 gövdesi UUID ve yuvarlanmış '
    'koordinatla PUT edilir, kullanıcı tazelenir ve ekran kapanır',
    (tester) async {
      await pumpAddress(tester);

      await dropPin(tester, _rawPin);
      await tapSave(tester);

      expect(server.putRequest.path, '/users/me/address');
      expect(server.putBody, {
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

      expect(find.byType(MapFirstAddressPage), findsNothing);
      expect(find.text('Adresiniz kaydedildi'), findsOneWidget);
      // Çağıran ekran tazelenmiş sağlayıcıdan yeni adresi gösteriyor.
      expect(userProvider.user?.address?.displayAddress, contains('Moda'));
      expect(find.text('Moda Caddesi 12, Caferağa Mahallesi'), findsOneWidget);
    },
  );

  testWidgets('sunucu adresi reddederse ekran açık kalır ve hata görünür', (
    tester,
  ) async {
    server.putResponse = const FakeApiResponse(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Posta kodu ilçeyle uyuşmuyor.',
        'errorCode': 'ADDRESS_POSTAL_CODE_MISMATCH',
        'errorCategory': 'VALIDATION_FAILED',
      },
    );
    await pumpAddress(tester);

    await dropPin(tester, _rawPin);
    await tapSave(tester);

    expect(find.byType(MapFirstAddressPage), findsOneWidget);
    expect(find.text('Posta kodu ilçeyle uyuşmuyor.'), findsOneWidget);
    expect(userProvider.user?.address?.displayAddress, contains('Eski'));
  });

  // İşverenin daha önce hiç yolu olmayan ekran: aynı `PUT /users/me/address`
  // gövdesi, aynı tazeleme. Kabul kriteri "işveren adres kaydı → PUT gövdesi".
  testWidgets('işveren adresini kaydedince aynı PUT gövdesi gider', (
    tester,
  ) async {
    server = _Server(isEmployer: true);
    await pumpAddress(tester);
    expect(userProvider.user?.isEmployer, isTrue);

    await dropPin(tester, _rawPin);
    await tapSave(tester);

    expect(server.putRequest.path, '/users/me/address');
    expect(server.putBody['position'], {
      'latitude': 40.982512,
      'longitude': 29.025411,
      'source': 'REVERSE_GEOCODE_CONFIRMED',
    });
    expect(server.putBody['districtId'], 'district-1');
    expect(find.byType(MapFirstAddressPage), findsNothing);
    expect(find.text('Moda Caddesi 12, Caferağa Mahallesi'), findsOneWidget);
  });

  // Ödeme kapısından gelen yönlendirme rotayı `extra`'sız açabiliyor; ekran
  // sağlayıcıdaki kullanıcının adresine açılmalı, boş haritaya değil.
  testWidgets("extra'sız açılış sağlayıcıdaki kullanıcının adresine açılır", (
    tester,
  ) async {
    server = _Server(isEmployer: true);
    await pumpAddress(tester, withExtra: false);

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.initialCameraPosition.target, const LatLng(40.99, 29.03));
    expect(find.text('KADIKÖY'), findsOneWidget);
  });
}
