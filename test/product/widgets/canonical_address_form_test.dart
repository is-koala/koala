import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/widgets/canonical_address_form.dart';

void main() {
  test('eksik alanlar sırayla anlaşılır doğrulama mesajı üretir', () {
    final controller = CanonicalAddressFormController();
    addTearDown(controller.dispose);

    expect(controller.validationMessage, 'Ülke seçin');
    controller.selectCountry(
      const ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
    );
    expect(controller.validationMessage, 'İl seçin');
    controller.selectCity(
      const ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
    );
    expect(controller.validationMessage, 'İlçe seçin');
  });

  test(
    'tam form yalnızca sunucunun iç kimliklerini kullanarak adres üretir',
    () {
      final controller = CanonicalAddressFormController();
      addTearDown(controller.dispose);

      controller.selectCountry(
        const ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
      );
      controller.selectCity(
        const ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
      );
      controller.selectDistrict(
        const ReferenceLocation(id: 'district-1', name: 'KADIKÖY'),
      );
      controller.neighborhood.text = 'Caferağa Mahallesi';
      controller.thoroughfare.text = 'Moda Caddesi';
      controller.buildingNumber.text = '12';
      controller.postalCode.text = '34710';
      controller.selectPosition(const LatLng(40.982512, 29.025411));

      expect(controller.validationMessage, isNull);
      expect(controller.value?.countryId, 'country-1');
      expect(controller.value?.districtId, 'district-1');
      expect(controller.value?.position.source.code, 'USER_CONFIRMED_PIN');
    },
  );

  test('arama adayı formu doldurur, kullanıcıya özel ayrıntıları korur', () {
    final controller = CanonicalAddressFormController();
    addTearDown(controller.dispose);
    controller.floor.text = '3';
    controller.unitNumber.text = '7';
    controller.additionalDirections.text = 'Kapıdaki güvenliğe sorun';

    controller.applyCandidate(
      const AddressCandidate(
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
        position: AddressPosition(
          latitude: 40.982512,
          longitude: 29.025411,
          source: AddressPositionSource.autocompleteConfirmed,
        ),
        candidateToken: 'opaque-token',
        needsUserReview: false,
        attribution: 'Google Maps',
      ),
    );

    expect(controller.district?.name, 'KADIKÖY');
    expect(controller.floor.text, '3');
    expect(controller.unitNumber.text, '7');
    expect(controller.additionalDirections.text, 'Kapıdaki güvenliğe sorun');
    expect(controller.value?.candidateToken, 'opaque-token');
  });

  test('pin hareketi sağlayıcı kanıtını bırakıp kullanıcı onayına geçer', () {
    final controller = CanonicalAddressFormController();
    addTearDown(controller.dispose);
    controller.applyCandidate(
      const AddressCandidate(
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
        position: AddressPosition(
          latitude: 40.982512,
          longitude: 29.025411,
          source: AddressPositionSource.autocompleteConfirmed,
        ),
        candidateToken: 'opaque-token',
        needsUserReview: false,
        attribution: 'Google Maps',
      ),
    );

    controller.selectPosition(const LatLng(40.983, 29.026));

    expect(controller.value?.candidateToken, isNull);
    expect(
      controller.value?.position.source,
      AddressPositionSource.userConfirmedPin,
    );
  });
}
