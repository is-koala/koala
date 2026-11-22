/// Üniversite / fakülte / bölüm kaydı; üç DTO da yalnız `id` ve `name` taşıyor.
/// [ReferenceLocation]'dan ayrı, çünkü ülkede ISO kodu var ve isimler
/// karışırdı.
class AcademicReference {
  const AcademicReference({required this.id, required this.name});

  final String id;

  final String name;

  factory AcademicReference.fromJson(Map<String, dynamic> json) {
    return AcademicReference(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
    );
  }

  /// Eşitlik [id] üzerinden: seçili değer başka bir istekten gelse de tutsun.
  @override
  bool operator ==(Object other) =>
      other is AcademicReference && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
