/// `POST /locations/address-candidates/reverse` hata kodları. Metne değil koda
/// bakılıyor; `backend_error_codes_test.dart` bunları backend kataloğuyla
/// karşılaştırıyor (#173).
abstract final class AddressReverseErrorCodes {
  /// `400`: pin hizmet alanı dışında; aynı pinle tekrar denemek boşuna.
  static const String outsideServiceArea =
      'ADDRESS_SEARCHCANDIDATE_OUTSIDESERVICEAREA';

  /// `400`: sağlayıcı adres bulamadı; pin geçerli, adres elle tamamlanır.
  static const String noResult = 'ADDRESS_REVERSE_NORESULT';

  /// `502`: Google Geocoding'e ulaşılamadı; geçici.
  static const String providerUnavailable =
      'ADDRESS_SEARCHPROVIDER_UNAVAILABLE';
}
