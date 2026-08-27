/// `/users/me` ve adres uçlarının döndürdüğü `AddressDto`.
///
/// `company_detail/models/address.dart` ile karıştırılmamalı: o, sahte şirket
/// verisinin modeli ve alan adları backend'inkiyle uyuşmuyor (`city` ↔
/// `cityName`). Gerçek uca bağlanan her yer bu modeli kullanmalı.
///
/// Şimdilik `auth/models` altında duruyor çünkü tek gerçek kaynağı
/// `/users/me`. `GET /jobs` bağlandığında ilan adresleri de aynı DTO'yu
/// döndüreceği için model o zaman ortak bir yere taşınacak.
class UserAddress {
  const UserAddress({
    required this.id,
    this.countryName,
    this.countryCode,
    this.cityName,
    this.districtName,
    this.addressLine,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? countryName;
  final String? countryCode;
  final String? cityName;
  final String? districtName;
  final String? addressLine;
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  /// Profil başlığında gösterilen kısa konum: `Küçükçekmece/İstanbul`.
  ///
  /// İkisinden biri boşsa dolu olan tek başına dönüyor; ikisi de boşsa `null`
  /// dönüp çağıran tarafın satırı hiç çizmemesini sağlıyor.
  String? get shortLabel {
    final parts = [
      if (districtName != null && districtName!.isNotEmpty) districtName!,
      if (cityName != null && cityName!.isNotEmpty) cityName!,
    ];
    return parts.isEmpty ? null : parts.join('/');
  }

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: '${json['id']}',
      countryName: json['countryName'] as String?,
      countryCode: json['countryCode'] as String?,
      cityName: json['cityName'] as String?,
      districtName: json['districtName'] as String?,
      addressLine: json['addressLine'] as String?,
      postalCode: json['postalCode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'countryName': countryName,
      'countryCode': countryCode,
      'cityName': cityName,
      'districtName': districtName,
      'addressLine': addressLine,
      'postalCode': postalCode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
