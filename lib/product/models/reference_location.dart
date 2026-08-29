/// Ülke / il / ilçe kayıtlarının ortak modeli.
///
/// Backend üç ayrı DTO döndürüyor (`CountryDto`, `CityDto`, `DistrictDto`)
/// ama alanları aynı; tek fark ülkedeki [code]. Üç sınıf yerine tek model
/// tutuluyor çünkü seçiciler de aynı listeyi çiziyor.
class ReferenceLocation {
  const ReferenceLocation({required this.id, required this.name, this.code});

  final String id;

  /// Görünen ad: `Türkiye`, `Ankara`, `Çankaya`.
  final String name;

  /// ISO ülke kodu (`TR`). İl ve ilçede `null`.
  final String? code;

  factory ReferenceLocation.fromJson(Map<String, dynamic> json) {
    return ReferenceLocation(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
    );
  }

  /// Eşitlik [id] üzerinden: açılır listedeki seçili değer farklı bir
  /// istekten gelmiş olsa da karşılaştırma tutmalı.
  @override
  bool operator ==(Object other) =>
      other is ReferenceLocation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
