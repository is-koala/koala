/// Üniversite / fakülte / bölüm kayıtlarının ortak modeli.
///
/// Backend üçü için ayrı DTO döndürüyor (`UniversityDto`, `FacultyDto`,
/// `DepartmentDto`) ama üçü de yalnızca `id` ve `name` taşıyor. Tek model
/// tutuluyor çünkü seçiciler de aynı listeyi çiziyor.
///
/// [ReferenceLocation] ile alanları aynı ama ayrı duruyor: o ülke/il/ilçe
/// için ve ülkede bir ISO kodu taşıyor. Tek bir "referans kaydı" modeline
/// katlamak isimleri yanlış yerlere taşırdı.
class AcademicReference {
  const AcademicReference({required this.id, required this.name});

  final String id;

  /// Görünen ad: `Boğaziçi Üniversitesi`, `Mühendislik Fakültesi`.
  final String name;

  factory AcademicReference.fromJson(Map<String, dynamic> json) {
    return AcademicReference(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
    );
  }

  /// Eşitlik [id] üzerinden: açılır listedeki seçili değer farklı bir
  /// istekten gelmiş olsa da karşılaştırma tutmalı.
  @override
  bool operator ==(Object other) =>
      other is AcademicReference && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
