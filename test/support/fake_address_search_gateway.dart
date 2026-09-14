import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/models/address_reverse_error_codes.dart';
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
  AddressCandidatePrecision? precision,
  String? buildingNumber = '12',
}) {
  return AddressCandidate(
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
      buildingNumber: buildingNumber,
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
    precision: precision,
  );
}

/// Adres arama kapısının sahtesi.
///
/// Ters geokod, istenen pini adayın konumu yapar (sunucu da öyle yapıyor:
/// kanıt pinle birebir eşleşmek zorunda). [reverseFailure] verilirse her
/// ters geokod o hatayla düşer — sunucunun üç `errorCode`'u
/// ([outsideServiceAreaFailure], [noResultFailure], [providerFailure])
/// buradan sürülür; hata metinleri `messages_tr.properties`'teki
/// karşılıkları. [reversePrecision] sunucunun opsiyonel `precision`
/// alanını taklit eder; sokak/mahalle düzeyinde bina numarası boş gelir.
/// Arama yolu tek bir öneri döndürür ve çözümü [searchCandidate] adayına
/// gider.
class FakeAddressSearchGateway implements AddressSearchGateway {
  FakeAddressSearchGateway({
    this.reverseFailure,
    this.reversePrecision,
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
  AddressCandidatePrecision? reversePrecision;
  AddressCandidate searchCandidate;

  final List<LatLng> reverseCalls = [];
  final List<String> queries = [];
  int sessionCalls = 0;
  int resolveCalls = 0;

  /// Durum koduna göre sunucunun o kodla döndürdüğü hata: `400` sonuç yok,
  /// diğerleri sağlayıcı düştü.
  static ApiException failure(int statusCode) =>
      statusCode == 400 ? noResultFailure() : providerFailure();

  /// `400` `address.searchCandidate.outsideServiceArea`.
  static ApiException outsideServiceAreaFailure({
    String message = 'Adres İstanbul hizmet alanı içinde olmalıdır.',
  }) => ApiException(
    message: message,
    type: ApiErrorType.validation,
    statusCode: 400,
    errorCode: AddressReverseErrorCodes.outsideServiceArea,
  );

  /// `400` `address.reverse.noResult`.
  static ApiException noResultFailure({
    String message =
        'Bu konum için bir adres bulunamadı. Adresi elle tamamlayın.',
  }) => ApiException(
    message: message,
    type: ApiErrorType.validation,
    statusCode: 400,
    errorCode: AddressReverseErrorCodes.noResult,
  );

  /// `502` `address.searchProvider.unavailable`.
  static ApiException providerFailure({
    String message = 'Adres arama servisine şu anda ulaşılamıyor.',
  }) => ApiException(
    message: message,
    type: ApiErrorType.server,
    statusCode: 502,
    errorCode: AddressReverseErrorCodes.providerUnavailable,
  );

  @override
  Future<AddressCandidate> reverse(double latitude, double longitude) async {
    reverseCalls.add(LatLng(latitude, longitude));
    final error = reverseFailure;
    if (error != null) throw error;
    final precision = reversePrecision;
    return modaCandidate(
      position: AddressPosition(
        latitude: latitude,
        longitude: longitude,
        source: AddressPositionSource.reverseGeocodeConfirmed,
      ),
      precision: precision,
      buildingNumber: (precision?.lacksBuildingNumber ?? false) ? null : '12',
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
