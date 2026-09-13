import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/address_search_service.dart';

/// Kadıköy / Moda'da bir aday; ters geokod ve arama testlerinin ortak
/// sunucu yanıtı. [source] ve [position] adayın hangi yoldan geldiğini
/// söyler: sunucu ters geokodda istenen pinin kendisini, aramada
/// sağlayıcının konumunu döndürüyor.
AddressCandidate modaCandidate({
  AddressPositionSource source = AddressPositionSource.reverseGeocodeConfirmed,
  AddressPosition? position,
  String candidateToken = 'reverse-proof',
  bool needsUserReview = false,
}) {
  return AddressCandidate(
    countryId: 'country-1',
    countryName: 'TÜRKİYE',
    countryCode: 'TR',
    cityId: 'city-1',
    cityName: 'İSTANBUL',
    districtId: 'district-1',
    districtName: 'KADIKÖY',
    components: const AddressComponents(
      neighborhood: 'Caferağa Mahallesi',
      thoroughfare: 'Moda Caddesi',
      buildingNumber: '12',
      postalCode: '34710',
    ),
    position:
        position ??
        AddressPosition(
          latitude: 40.982512,
          longitude: 29.025411,
          source: source,
        ),
    candidateToken: candidateToken,
    needsUserReview: needsUserReview,
    attribution: 'Google Maps',
  );
}

/// Adres arama kapısının sahtesi.
///
/// Ters geokod, istenen pini adayın konumu yapar (sunucu da öyle yapıyor:
/// kanıt pinle birebir eşleşmek zorunda). [reverseFailure] verilirse her
/// ters geokod o hatayla düşer — `400` (sonuç yok) ve `502` (sağlayıcı
/// düştü) yolları buradan sürülür. Arama yolu tek bir öneri döndürür ve
/// çözümü [searchCandidate] adayına gider.
class FakeAddressSearchGateway implements AddressSearchGateway {
  FakeAddressSearchGateway({
    this.reverseFailure,
    AddressCandidate? searchCandidate,
  }) : searchCandidate =
           searchCandidate ??
           modaCandidate(
             source: AddressPositionSource.autocompleteConfirmed,
             position: const AddressPosition(
               latitude: 40.987654,
               longitude: 29.031111,
               source: AddressPositionSource.autocompleteConfirmed,
             ),
             candidateToken: 'search-proof',
           );

  ApiException? reverseFailure;
  AddressCandidate searchCandidate;

  final List<LatLng> reverseCalls = [];
  final List<String> queries = [];
  int sessionCalls = 0;
  int resolveCalls = 0;

  static ApiException failure(int statusCode) => ApiException(
    message: statusCode == 400
        ? 'Bu konum için adres bulunamadı.'
        : 'Adres sağlayıcısına ulaşılamadı.',
    type: statusCode == 400 ? ApiErrorType.validation : ApiErrorType.server,
    statusCode: statusCode,
    errorCode: statusCode == 400 ? 'REVERSE_NO_RESULT' : 'PROVIDER_UNAVAILABLE',
  );

  @override
  Future<AddressCandidate> reverse(double latitude, double longitude) async {
    reverseCalls.add(LatLng(latitude, longitude));
    final error = reverseFailure;
    if (error != null) throw error;
    return modaCandidate(
      position: AddressPosition(
        latitude: latitude,
        longitude: longitude,
        source: AddressPositionSource.reverseGeocodeConfirmed,
      ),
    );
  }

  @override
  Future<AddressSearchSession> startSession() async {
    sessionCalls++;
    return AddressSearchSession(
      id: 'session-$sessionCalls',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<List<AddressSuggestion>> search(String sessionId, String query) async {
    queries.add(query);
    return const [
      AddressSuggestion(
        id: 'suggestion-1',
        mainText: 'Moda Caddesi 12',
        secondaryText: 'Caferağa, Kadıköy/İstanbul',
      ),
    ];
  }

  @override
  Future<AddressCandidate> resolve(String sessionId, String candidateId) async {
    resolveCalls++;
    return searchCandidate;
  }
}
