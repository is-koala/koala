/// `POST /locations/address-candidates/reverse` uç noktasının döndürdüğü
/// `errorCode` değerleri.
///
/// Kodlar mesaj anahtarından türüyor
/// (`{address.reverse.noResult}` → `ADDRESS_REVERSE_NORESULT`,
/// `KoalaException.deriveErrorCode`: nokta alt çizgi olur, büyük harfe
/// çevrilir, deve harfleri **birleşik** kalır). Metne değil koda bakılıyor;
/// `test/support/backend_error_codes_test.dart` bu dosyadaki her dizgeyi
/// backend kataloğuyla karşılaştırıyor (is-koala/koala#173).
abstract final class AddressReverseErrorCodes {
  /// `400` — pin İstanbul hizmet alanı kutusunun dışında
  /// (`AddressSearchManager.reverse` → `ValidationException`). Aynı pinle
  /// tekrar denemek sonucu değiştirmez; kullanıcının pini taşıması gerekir.
  static const String outsideServiceArea =
      'ADDRESS_SEARCHCANDIDATE_OUTSIDESERVICEAREA';

  /// `400` — sağlayıcı bu nokta için adres bulamadı. Pin geçerli; adres
  /// elle tamamlanır.
  static const String noResult = 'ADDRESS_REVERSE_NORESULT';

  /// `502` — Google Geocoding'e ulaşılamadı ya da beklenmedik durum döndü
  /// (`ExternalServiceException`). Geçici; yenilemek anlamlı.
  static const String providerUnavailable =
      'ADDRESS_SEARCHPROVIDER_UNAVAILABLE';
}
