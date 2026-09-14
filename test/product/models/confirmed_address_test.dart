import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';

CanonicalAddress _canonical({
  AddressPosition? position,
  bool components = true,
}) {
  return CanonicalAddress(
    id: 'address-1',
    countryId: 'country-1',
    countryName: 'TÜRKİYE',
    countryCode: 'TR',
    cityId: 'city-1',
    cityName: 'İSTANBUL',
    districtId: 'district-1',
    districtName: 'KADIKÖY',
    components: components
        ? const AddressComponents(
            neighborhood: 'Caferağa Mahallesi',
            thoroughfare: 'Moda Caddesi',
            buildingNumber: '12',
            postalCode: '34710',
          )
        : null,
    position: position,
    canonicalVersion: 1,
    needsReview: false,
  );
}

void main() {
  group('ConfirmedAddress.fromCanonical', () {
    test('kayıtlı adresi ön doluma çevirir, kaynağı elle seçime indirir', () {
      final confirmed = ConfirmedAddress.fromCanonical(
        _canonical(
          position: const AddressPosition(
            latitude: 40.982512,
            longitude: 29.025411,
            source: AddressPositionSource.reverseGeocodeConfirmed,
          ),
        ),
      )!;

      expect(
        confirmed.country,
        const ReferenceLocation(id: 'country-1', name: ''),
      );
      expect(confirmed.city.name, 'İSTANBUL');
      expect(confirmed.district.name, 'KADIKÖY');
      expect(confirmed.components.neighborhood, 'Caferağa Mahallesi');
      expect(confirmed.candidateToken, isNull);
      // Kayıttaki kanıt çoktan tüketildi; kanıtsız başka bir kaynak sunucuda
      // 400 olur.
      expect(confirmed.position.source, AddressPositionSource.userConfirmedPin);
      expect(confirmed.toWrite().toJson()['position'], {
        'latitude': 40.982512,
        'longitude': 29.025411,
        'source': 'USER_CONFIRMED_PIN',
      });
    });

    test('pini olmayan kayıt ön dolum vermez', () {
      expect(ConfirmedAddress.fromCanonical(_canonical()), isNull);
      expect(ConfirmedAddress.fromCanonical(null), isNull);
    });

    test('bileşeni olmayan kayıt boş bileşenlerle döner', () {
      final confirmed = ConfirmedAddress.fromCanonical(
        _canonical(
          components: false,
          position: const AddressPosition(
            latitude: 40.982512,
            longitude: 29.025411,
            source: AddressPositionSource.legacyUnverified,
          ),
        ),
      )!;

      expect(confirmed.components.neighborhood, isEmpty);
      expect(confirmed.components.postalCode, isEmpty);
    });
  });

  group('ConfirmedAddress.summary', () {
    test('cadde, numara, mahalle ve ilçe/il tek satırda', () {
      final confirmed = ConfirmedAddress.fromCanonical(
        _canonical(
          position: const AddressPosition(
            latitude: 40.982512,
            longitude: 29.025411,
            source: AddressPositionSource.userConfirmedPin,
          ),
        ),
      )!;

      expect(
        confirmed.summary,
        'Moda Caddesi 12, Caferağa Mahallesi, KADIKÖY/İSTANBUL',
      );
    });

    test('site adı numaranın yerine geçer, boş parçalar atlanır', () {
      const confirmed = ConfirmedAddress(
        country: ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
        city: ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
        district: ReferenceLocation(id: 'district-1', name: 'KADIKÖY'),
        components: AddressComponents(
          neighborhood: 'Caferağa Mahallesi',
          thoroughfare: 'Moda Caddesi',
          siteName: 'Moda Sitesi',
          postalCode: '34710',
        ),
        position: AddressPosition(
          latitude: 40.982512,
          longitude: 29.025411,
          source: AddressPositionSource.userConfirmedPin,
        ),
      );

      expect(
        confirmed.summary,
        'Moda Caddesi, Moda Sitesi, Caferağa Mahallesi, KADIKÖY/İSTANBUL',
      );
    });
  });

  test('toWrite aday kanıtını ve Koala kimliklerini taşır', () {
    const confirmed = ConfirmedAddress(
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
        latitude: 40.98251234567,
        longitude: 29.02541134567,
        source: AddressPositionSource.autocompleteConfirmed,
      ),
      candidateToken: 'search-proof',
    );

    expect(confirmed.toWrite().toJson(), {
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
        'source': 'AUTOCOMPLETE_CONFIRMED',
      },
      'candidateToken': 'search-proof',
    });
  });
}
