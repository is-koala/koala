import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/canonical_address.dart';

void main() {
  group('AddressWrite', () {
    test('backend V2 sözleşmesini yapılandırılmış olarak üretir', () {
      const address = AddressWrite(
        countryId: 'country-1',
        cityId: 'city-1',
        districtId: 'district-1',
        components: AddressComponents(
          neighborhood: 'Caferağa Mahallesi',
          thoroughfare: 'Moda Caddesi',
          buildingNumber: '12',
          floor: '3',
          unitNumber: '7',
          postalCode: '34710',
          additionalDirections: 'İskeleye yakın',
        ),
        position: AddressPosition(
          latitude: 40.982512,
          longitude: 29.025411,
          source: AddressPositionSource.userConfirmedPin,
        ),
      );

      expect(address.toJson(), {
        'countryId': 'country-1',
        'cityId': 'city-1',
        'districtId': 'district-1',
        'components': {
          'neighborhood': 'Caferağa Mahallesi',
          'thoroughfare': 'Moda Caddesi',
          'buildingNumber': '12',
          'floor': '3',
          'unitNumber': '7',
          'postalCode': '34710',
          'additionalDirections': 'İskeleye yakın',
        },
        'position': {
          'latitude': 40.982512,
          'longitude': 29.025411,
          'source': 'USER_CONFIRMED_PIN',
        },
      });
    });

    test('boş isteğe bağlı bileşenleri gövdeye koymaz', () {
      const address = AddressWrite(
        countryId: 'country-1',
        cityId: 'city-1',
        districtId: 'district-1',
        components: AddressComponents(
          neighborhood: 'Caferağa Mahallesi',
          thoroughfare: 'Moda Caddesi',
          siteName: '   ',
          buildingNumber: '12',
          postalCode: '34710',
        ),
        position: AddressPosition(
          latitude: 40.982512,
          longitude: 29.025411,
          source: AddressPositionSource.userConfirmedPin,
        ),
      );

      final components = address.toJson()['components'] as Map;
      expect(components.containsKey('siteName'), isFalse);
      expect(components.containsKey('floor'), isFalse);
      expect(address.toJson().containsKey('candidateToken'), isFalse);
    });

    test('sağlayıcı adayının tek kullanımlık kanıtını gönderir', () {
      const address = AddressWrite(
        countryId: 'country-1',
        cityId: 'city-1',
        districtId: 'district-1',
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
        candidateToken: 'opaque-candidate-token',
      );

      expect(address.toJson()['candidateToken'], 'opaque-candidate-token');
    });
  });

  test('adres adayı iç referansları ve yapılandırılmış bileşenleri okur', () {
    final candidate = AddressCandidate.fromJson({
      'countryId': 'country-1',
      'countryName': 'TÜRKİYE',
      'countryCode': 'TR',
      'cityId': 'city-1',
      'cityName': 'İSTANBUL',
      'districtId': 'district-1',
      'districtName': 'KADIKÖY',
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
      'candidateToken': 'opaque-token',
      'needsUserReview': false,
      'attribution': 'Google Maps',
    });

    expect(candidate.districtName, 'KADIKÖY');
    expect(candidate.toWrite().candidateToken, 'opaque-token');
    expect(
      candidate.toWrite().position.source,
      AddressPositionSource.autocompleteConfirmed,
    );
  });

  group('CanonicalAddress', () {
    test('sunucu yanıtını ve gösterim etiketlerini okur', () {
      final address = CanonicalAddress.fromJson({
        'id': 'address-1',
        'countryId': 'country-1',
        'countryName': 'TÜRKİYE',
        'countryCode': 'TR',
        'cityId': 'city-1',
        'cityName': 'İSTANBUL',
        'districtId': 'district-1',
        'districtName': 'KADIKÖY',
        'components': {
          'neighborhood': 'Caferağa Mahallesi',
          'thoroughfare': 'Moda Caddesi',
          'buildingNumber': '12',
          'postalCode': '34710',
        },
        'position': {
          'latitude': 40.982512,
          'longitude': 29.025411,
          'source': 'USER_CONFIRMED_PIN',
        },
        'displayAddress':
            'Caferağa Mahallesi, Moda Caddesi No:12, KADIKÖY/İSTANBUL',
        'confirmedAt': '2026-09-05T12:30:00Z',
        'canonicalVersion': 1,
        'needsReview': false,
      });

      expect(address.shortLabel, 'KADIKÖY/İSTANBUL');
      expect(address.displayAddress, contains('Moda Caddesi'));
      expect(address.position?.source, AddressPositionSource.userConfirmedPin);
      expect(address.confirmedAt, DateTime.utc(2026, 9, 5, 12, 30));
      expect(address.needsReview, isFalse);
    });
  });
}
