import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/reference_location.dart';

/// Kullanıcının harita ekranında görüp onayladığı adres.
///
/// `MapFirstAddressPage`'in geri döndürdüğü değer: Koala referansındaki
/// ülke/il/ilçe (UUID + görünen ad), yapılandırılmış bileşenler, onaylanan
/// pin ve varsa aday kanıtı. Sunucuya [toWrite] ile `AddressWriteV2` olarak
/// gider; çağıran ekran [summary] ile gösterir ve haritayı yeniden açarken
/// aynı değeri ön dolum olarak verir.
///
/// [CanonicalAddress]'ten farkı: sunucunun verdiği kimlik, sürüm ve inceleme
/// bayrağı burada yok — bu, kullanıcının **yazmak üzere** onayladığı hâl,
/// sunucunun sakladığı kayıt değil (ADR-0007).
class ConfirmedAddress {
  const ConfirmedAddress({
    required this.country,
    required this.city,
    required this.district,
    required this.components,
    required this.position,
    this.candidateToken,
  });

  final ReferenceLocation country;
  final ReferenceLocation city;
  final ReferenceLocation district;
  final AddressComponents components;
  final AddressPosition position;

  /// Aday sınırından gelen kanıt; pin elle seçildiyse `null`.
  ///
  /// Kanıt yoksa [position]'ın kaynağı `USER_CONFIRMED_PIN` olmalı: sunucu
  /// kanıtsız başka bir kaynağı `400` ile geri çeviriyor. Bunu
  /// `MapFirstAddressController` ve [fromCanonical] birlikte koruyor.
  final String? candidateToken;

  /// Sunucudaki kayıttan ön dolum.
  ///
  /// Pini olmayan kayıt `null` döner: harita ekranı pin olmadan açılamaz ve
  /// pinsiz bir adres zaten yeniden onaylanması gereken eski veridir.
  /// Bileşenleri eksik kayıt boş bileşenlerle döner; kullanıcı ekranda
  /// tamamlar.
  ///
  /// Konum kaynağı `USER_CONFIRMED_PIN` olur: kayıttaki aday kanıtı çoktan
  /// tüketildi, kullanıcı pini bu ekranda yeniden onaylıyor.
  static ConfirmedAddress? fromCanonical(CanonicalAddress? address) {
    final position = address?.position;
    if (address == null || position == null) return null;

    return ConfirmedAddress(
      country: ReferenceLocation(
        id: address.countryId,
        name: address.countryName,
        code: address.countryCode,
      ),
      city: ReferenceLocation(id: address.cityId, name: address.cityName),
      district: ReferenceLocation(
        id: address.districtId,
        name: address.districtName,
      ),
      components:
          address.components ??
          const AddressComponents(
            neighborhood: '',
            thoroughfare: '',
            postalCode: '',
          ),
      position: AddressPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        source: AddressPositionSource.userConfirmedPin,
      ),
    );
  }

  AddressWrite toWrite() => AddressWrite(
    countryId: country.id,
    cityId: city.id,
    districtId: district.id,
    components: components,
    position: position,
    candidateToken: candidateToken,
  );

  /// Tek satırlık özet: `Moda Caddesi 12, Caferağa Mahallesi, Kadıköy/İstanbul`.
  String get summary {
    final street = [
      components.thoroughfare,
      components.buildingNumber,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    return [
      street,
      components.siteName ?? '',
      components.neighborhood,
      '${district.name}/${city.name}',
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }
}
