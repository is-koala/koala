import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/reference_location.dart';

/// Kullanıcının harita ekranında onayladığı adres (ADR-0007); sunucuya
/// [toWrite] ile gider. [CanonicalAddress]'ten farkı: sunucunun sakladığı kayıt
/// değil, **yazılmak üzere** onaylanan hâl.
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

  /// Aday kanıtı; pin elle seçildiyse `null`. O zaman kaynak
  /// `USER_CONFIRMED_PIN` olmalı, sunucu başkasını `400` ile reddediyor.
  final String? candidateToken;

  /// Sunucudaki kayıttan ön dolum. Pinsiz kayıt `null` döner: harita pinsiz
  /// açılamaz. Aday kanıtı çoktan tüketildiği için kaynak `USER_CONFIRMED_PIN`.
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
