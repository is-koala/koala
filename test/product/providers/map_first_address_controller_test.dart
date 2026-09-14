import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_map.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/providers/map_first_address_controller.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';

import '../../support/fake_address_search_gateway.dart';
import '../../support/fake_api.dart';
import '../../support/reference_location_fixtures.dart';

const _debounce = Duration(milliseconds: 600);
const _moda = LatLng(40.982512, 29.025411);
const _device = LatLng(41.04, 29.0);

MapFirstAddressController _controller({
  FakeAddressSearchGateway? gateway,
  FakeDeviceLocationSource? location,
  ConfirmedAddress? initialAddress,
}) {
  final api = FakeApi(
    handler: (request) =>
        istanbulReferenceResponse(request.path) ??
        const FakeApiResponse(statusCode: 404, body: {'success': false}),
  );
  return MapFirstAddressController(
    searchGateway: gateway ?? FakeAddressSearchGateway(),
    referenceService: ReferenceLocationService.withClient(api.client),
    locationSource: location ?? FakeDeviceLocationSource(),
    initialAddress: initialAddress,
  );
}

/// Kullanıcı haritayı [target]'a kaydırıp bıraktı ve pin durdu.
void _dropPin(MapFirstAddressController controller, LatLng target) {
  controller
    ..cameraMoved(target)
    ..cameraIdle();
}

void _fillManually(MapFirstAddressController controller) {
  controller
    ..selectCountry(const ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'))
    ..selectCity(const ReferenceLocation(id: 'city-1', name: 'İSTANBUL'))
    ..selectDistrict(const ReferenceLocation(id: 'district-1', name: 'KADIKÖY'))
    ..neighborhood.text = 'Caferağa Mahallesi'
    ..thoroughfare.text = 'Moda Caddesi'
    ..buildingNumber.text = '12'
    ..postalCode.text = '34710';
}

void main() {
  group('doğrulama', () {
    test('eksik alanlar sırayla anlaşılır mesaj üretir', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      expect(controller.validationMessage, 'İl seçin');
      controller.selectCountry(
        const ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
      );
      expect(controller.validationMessage, 'İl seçin');
      controller.selectCity(
        const ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
      );
      expect(controller.validationMessage, 'İlçe seçin');
      controller.selectDistrict(
        const ReferenceLocation(id: 'district-1', name: 'KADIKÖY'),
      );
      expect(controller.validationMessage, 'Mahalle zorunlu');
    });

    test('satır içi hatalar kaydet denenene kadar gizli kalır', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      expect(controller.errorFor(AddressField.city), isNull);
      expect(controller.submit(), isNull);
      expect(controller.errorFor(AddressField.city), 'İl seçin');
      expect(controller.errorFor(AddressField.postalCode), isNotNull);

      _fillManually(controller);
      expect(controller.errorFor(AddressField.city), isNull);
      expect(controller.errorFor(AddressField.postalCode), isNull);
      expect(controller.errorFor(AddressField.position), isNotNull);
    });

    test(
      'elle dolan form yalnızca Koala kimlikleriyle onaylı adres üretir',
      () {
        final controller = _controller();
        addTearDown(controller.dispose);
        _fillManually(controller);
        _dropPin(controller, _moda);

        final confirmed = controller.confirmed!;
        final body = confirmed.toWrite().toJson();
        expect(body['countryId'], 'country-1');
        expect(body['cityId'], 'city-1');
        expect(body['districtId'], 'district-1');
        expect(body['position'], {
          'latitude': 40.982512,
          'longitude': 29.025411,
          'source': 'USER_CONFIRMED_PIN',
        });
        expect(body.containsKey('candidateToken'), isFalse);
      },
    );
  });

  group('pin ve ters geokod', () {
    testWidgets('pin durunca debounce sonrası ters geokod alanları doldurur', (
      tester,
    ) async {
      final gateway = FakeAddressSearchGateway();
      final controller = _controller(gateway: gateway);
      controller.floor.text = '3';
      controller.unitNumber.text = '7';
      controller.additionalDirections.text = 'Kapıdaki güvenliğe sorun';

      _dropPin(controller, const LatLng(40.98251234567, 29.02541198765));
      await tester.pump(_debounce - const Duration(milliseconds: 1));
      expect(gateway.reverseCalls, isEmpty, reason: 'debounce dolmadı');

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(gateway.reverseCalls, hasLength(1));
      expect(controller.district?.name, 'KADIKÖY');
      expect(controller.neighborhood.text, 'Caferağa Mahallesi');
      expect(controller.thoroughfare.text, 'Moda Caddesi');
      expect(controller.postalCode.text, '34710');
      expect(controller.candidateToken, 'reverse-proof');
      expect(
        controller.positionSource,
        AddressPositionSource.reverseGeocodeConfirmed,
      );
      // Kullanıcıya özel ayrıntılar korunur; sağlayıcı bunları bilemez.
      expect(controller.floor.text, '3');
      expect(controller.unitNumber.text, '7');
      expect(controller.additionalDirections.text, 'Kapıdaki güvenliğe sorun');

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    testWidgets('art arda pin hareketleri tek ters geokod isteği üretir', (
      tester,
    ) async {
      final gateway = FakeAddressSearchGateway();
      final controller = _controller(gateway: gateway);

      _dropPin(controller, const LatLng(40.98, 29.02));
      await tester.pump(const Duration(milliseconds: 300));
      _dropPin(controller, const LatLng(40.981, 29.021));
      await tester.pump(const Duration(milliseconds: 300));
      _dropPin(controller, _moda);
      await tester.pump(_debounce);
      await tester.pump();

      expect(gateway.reverseCalls, [_moda]);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    testWidgets(
      'pin oynayınca sağlayıcı kanıtı düşer, kaynak elle seçime döner',
      (tester) async {
        final controller = _controller();
        _dropPin(controller, _moda);
        await tester.pump(_debounce);
        await tester.pump();
        expect(controller.candidateToken, 'reverse-proof');

        _dropPin(controller, const LatLng(40.983, 29.026));

        expect(controller.candidateToken, isNull);
        expect(
          controller.positionSource,
          AddressPositionSource.userConfirmedPin,
        );
        expect(controller.pin, const LatLng(40.983, 29.026));

        // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
        controller.dispose();
      },
    );

    testWidgets('aynı noktada duran kamera pini ve adayı bozmaz', (
      tester,
    ) async {
      final gateway = FakeAddressSearchGateway();
      final controller = _controller(gateway: gateway);
      _dropPin(controller, _moda);
      await tester.pump(_debounce);
      await tester.pump();

      // Harita animasyon sonrası aynı noktada "durdu" der (yuvarlama payı).
      controller
        ..cameraMoved(const LatLng(40.982512004, 29.025410998))
        ..cameraIdle();
      await tester.pump(_debounce);
      await tester.pump();

      expect(gateway.reverseCalls, hasLength(1));
      expect(controller.candidateToken, 'reverse-proof');

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    for (final status in [400, 502]) {
      testWidgets(
        'ters geokod $status dönerse şerit çıkar, pin ve alanlar kalır',
        (tester) async {
          final gateway = FakeAddressSearchGateway(
            reverseFailure: FakeAddressSearchGateway.failure(status),
          );
          final controller = _controller(gateway: gateway);

          _dropPin(controller, _moda);
          await tester.pump(_debounce);
          await tester.pump();

          expect(controller.reverseError, isNotNull);
          expect(controller.reverseGeocoding, isFalse);
          expect(controller.pin, _moda);
          expect(controller.hasCandidate, isFalse);

          // Elle giriş devam eder ve adres pinle birlikte geçerli olur.
          _fillManually(controller);
          expect(
            controller.confirmed?.position.source.code,
            'USER_CONFIRMED_PIN',
          );
          expect(controller.confirmed?.candidateToken, isNull);
        },
      );
    }

    testWidgets('"Sadece pini kullan" aday metinlerini boşaltır, pini korur', (
      tester,
    ) async {
      final controller = _controller();
      controller.floor.text = '3';
      _dropPin(controller, _moda);
      await tester.pump(_debounce);
      await tester.pump();

      controller.usePinOnly();

      expect(controller.neighborhood.text, isEmpty);
      expect(controller.thoroughfare.text, isEmpty);
      expect(controller.postalCode.text, isEmpty);
      expect(controller.floor.text, '3');
      expect(controller.district?.name, 'KADIKÖY');
      expect(controller.pin, _moda);
      expect(controller.candidateToken, isNull);
      expect(controller.positionSource, AddressPositionSource.userConfirmedPin);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });
  });

  group('arama', () {
    testWidgets('seçilen aday alanları doldurur ve haritayı oraya taşır', (
      tester,
    ) async {
      final gateway = FakeAddressSearchGateway();
      final controller = _controller(gateway: gateway);
      controller.autocomplete.queryChanged('Moda Caddesi');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(controller.autocomplete.suggestions, hasLength(1));

      await controller.selectSuggestion(
        controller.autocomplete.suggestions.single,
      );

      const target = LatLng(40.987654, 29.031111);
      expect(controller.pendingCameraTarget, target);
      expect(controller.pin, target);
      expect(controller.candidateToken, 'search-proof');
      expect(
        controller.positionSource,
        AddressPositionSource.autocompleteConfirmed,
      );
      expect(controller.thoroughfare.text, 'Moda Caddesi');
      expect(controller.searchText.text, contains('Moda Caddesi 12'));

      // Harita adayı izleyip durunca ikinci bir ters geokod üretmez.
      controller.takePendingCameraTarget();
      _dropPin(controller, target);
      await tester.pump(_debounce);
      await tester.pump();
      expect(gateway.reverseCalls, isEmpty);
      expect(controller.candidateToken, 'search-proof');

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });
  });

  group('cihaz konumu', () {
    testWidgets('açılışta izin varsa harita cihaza gider ve pin orada dolar', (
      tester,
    ) async {
      final gateway = FakeAddressSearchGateway();
      final location = FakeDeviceLocationSource(granted: _device);
      final controller = _controller(gateway: gateway, location: location);

      await controller.locateOnOpen();

      expect(location.requestCalls, 0, reason: 'açılış izin istemez');
      expect(controller.pendingCameraTarget, _device);
      expect(controller.pin, _device);
      expect(controller.locationGranted, isTrue);

      await tester.pump(_debounce);
      await tester.pump();
      expect(gateway.reverseCalls, [_device]);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    testWidgets('açılışta izin yoksa şehir merkezi pin olur, izin istenmez', (
      tester,
    ) async {
      final gateway = FakeAddressSearchGateway();
      final location = FakeDeviceLocationSource();
      final controller = _controller(gateway: gateway, location: location);

      await controller.locateOnOpen();

      expect(location.requestCalls, 0);
      expect(controller.pendingCameraTarget, isNull);
      expect(controller.pin, AppMap.istanbulCenter);
      expect(controller.locationGranted, isFalse);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    testWidgets('düzenlenen adres varken açılış cihaz konumuna bakmaz', (
      tester,
    ) async {
      final location = FakeDeviceLocationSource(granted: _device);
      final controller = _controller(
        location: location,
        initialAddress: ConfirmedAddress(
          country: const ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
          city: const ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
          district: const ReferenceLocation(id: 'district-1', name: 'KADIKÖY'),
          components: const AddressComponents(
            neighborhood: 'Caferağa Mahallesi',
            thoroughfare: 'Moda Caddesi',
            buildingNumber: '12',
            postalCode: '34710',
          ),
          position: const AddressPosition(
            latitude: 40.982512,
            longitude: 29.025411,
            source: AddressPositionSource.userConfirmedPin,
          ),
        ),
      );

      await controller.locateOnOpen();

      expect(location.currentIfGrantedCalls, 0);
      expect(controller.initialCameraTarget, _moda);
      expect(controller.pin, _moda);
      expect(controller.confirmed, isNotNull);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    testWidgets('"Konumumu kullan" izni o anda ister ve haritayı taşır', (
      tester,
    ) async {
      final location = FakeDeviceLocationSource(
        requestResult: const DeviceLocationResult.located(_device),
      );
      final controller = _controller(location: location);

      final message = await controller.useMyLocation();

      expect(location.requestCalls, 1);
      expect(message, isNull);
      expect(controller.pendingCameraTarget, _device);
      expect(controller.pin, _device);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    testWidgets('hizmet alanı dışındaki cihaz konumu haritayı taşımaz', (
      tester,
    ) async {
      final location = FakeDeviceLocationSource(
        requestResult: const DeviceLocationResult.located(
          LatLng(39.925533, 32.866287),
        ),
      );
      final controller = _controller(location: location);

      final message = await controller.useMyLocation();

      expect(message, contains('İstanbul'));
      expect(controller.pendingCameraTarget, isNull);
      expect(controller.pin, isNull);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });

    testWidgets('izin reddedilirse elle seçime devam mesajı döner', (
      tester,
    ) async {
      final controller = _controller(location: FakeDeviceLocationSource());

      final message = await controller.useMyLocation();

      expect(message, 'Konum izni olmadan da pini elle seçebilirsiniz.');
      expect(controller.locating, isFalse);

      // Bekleyen debounce zamanlayıcısı testin sonunda kalmasın.
      controller.dispose();
    });
  });

  group('referans listeleri', () {
    test('il seçenekleri tek ülkeyi kendiliğinden seçer', () async {
      final controller = _controller();
      addTearDown(controller.dispose);

      final cities = await controller.cityOptions();

      expect(controller.country?.id, 'country-1');
      expect(cities.map((city) => city.name), ['İSTANBUL']);
      expect(await controller.districtOptions(), isEmpty);

      controller.selectCity(cities.single);
      final districts = await controller.districtOptions();
      expect(districts.map((district) => district.name), ['KADIKÖY']);
    });

    test('il değişince ilçe sıfırlanır', () {
      final controller = _controller();
      addTearDown(controller.dispose);
      _fillManually(controller);

      controller.selectCity(
        const ReferenceLocation(id: 'city-2', name: 'ANKARA'),
      );

      expect(controller.district, isNull);
    });
  });
}
