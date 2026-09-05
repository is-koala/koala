import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/services/address_search_service.dart';

import '../../support/fake_api.dart';

void main() {
  test(
    'arama oturumu, öneri ve resolve aynı opaque kimliklerle ilerler',
    () async {
      final api = FakeApi(
        handler: (request) {
          if (request.path == '/locations/address-search-sessions') {
            return const FakeApiResponse(
              statusCode: 201,
              body: {
                'success': true,
                'data': {
                  'id': 'session-1',
                  'expiresAt': '2027-09-05T12:00:00Z',
                },
              },
            );
          }
          if (request.path.endsWith('/suggestions')) {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [
                  {
                    'id': 'candidate-1',
                    'mainText': 'Moda Caddesi 12',
                    'secondaryText': 'Kadıköy/İstanbul',
                  },
                ],
              },
            );
          }
          if (request.path == '/locations/address-candidates/reverse' ||
              request.path.endsWith('/resolve')) {
            final reverse =
                request.path == '/locations/address-candidates/reverse';
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
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
                    'source': reverse
                        ? 'REVERSE_GEOCODE_CONFIRMED'
                        : 'AUTOCOMPLETE_CONFIRMED',
                  },
                  'candidateToken': 'opaque-token',
                  'needsUserReview': false,
                  'attribution': 'Google Maps',
                },
              },
            );
          }
          throw StateError('Beklenmeyen istek: ${request.path}');
        },
      );
      final service = AddressSearchService.withClient(api.client);

      final session = await service.startSession();
      final suggestions = await service.search(session.id, 'Moda Caddesi');
      final candidate = await service.resolve(session.id, suggestions.first.id);
      final reverseCandidate = await service.reverse(40.982512, 29.025411);

      expect(api.requests.map((request) => request.path), [
        '/locations/address-search-sessions',
        '/locations/address-search-sessions/session-1/suggestions',
        '/locations/address-search-sessions/session-1/candidates/candidate-1/resolve',
        '/locations/address-candidates/reverse',
      ]);
      expect(api.requests[1].queryParameters, {'query': 'Moda Caddesi'});
      expect(candidate.candidateToken, 'opaque-token');
      expect(api.requests.last.data, {
        'latitude': 40.982512,
        'longitude': 29.025411,
      });
      expect(
        reverseCandidate.position.source,
        AddressPositionSource.reverseGeocodeConfirmed,
      );
    },
  );
}
