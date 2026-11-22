/// Ülke / il / ilçe kaydı; tek fark ülkedeki [code].
class ReferenceLocation {
  const ReferenceLocation({required this.id, required this.name, this.code});

  final String id;

  final String name;

  /// ISO ülke kodu; il ve ilçede `null`.
  final String? code;

  factory ReferenceLocation.fromJson(Map<String, dynamic> json) {
    return ReferenceLocation(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
    );
  }

  /// Eşitlik [id] üzerinden: seçili değer başka bir istekten gelse de tutsun.
  @override
  bool operator ==(Object other) =>
      other is ReferenceLocation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
