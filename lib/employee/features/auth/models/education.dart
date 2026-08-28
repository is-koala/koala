import 'package:koala/product/extensions/date_extensions.dart';

/// Öğrenim kademesi. Backend `GradeType` enum'ının karşılığı.
enum GradeType {
  preparatory('PREPARATORY', 'Hazırlık'),
  firstGrade('FIRST_GRADE', '1. sınıf'),
  secondGrade('SECOND_GRADE', '2. sınıf'),
  thirdGrade('THIRD_GRADE', '3. sınıf'),
  fourthGrade('FOURTH_GRADE', '4. sınıf'),
  fifthGrade('FIFTH_GRADE', '5. sınıf'),
  sixthGrade('SIXTH_GRADE', '6. sınıf'),
  graduate('GRADUATE', 'Mezun');

  const GradeType(this.code, this.displayName);

  final String code;
  final String displayName;

  static GradeType fromCode(Object? value) {
    return GradeType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => GradeType.graduate,
    );
  }
}

/// Kullanıcının bir öğrenim kaydı.
///
/// Üniversite, fakülte ve bölüm backend'de referans veri; istemci yalnızca
/// adlarını gösteriyor, kimlikleri düzenleme akışı için taşınıyor.
class Education {
  const Education({
    required this.id,
    this.universityId,
    this.universityName,
    this.facultyId,
    this.facultyName,
    this.departmentId,
    this.departmentName,
    this.type = GradeType.graduate,
    this.gpa,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String? universityId;
  final String? universityName;
  final String? facultyId;
  final String? facultyName;
  final String? departmentId;
  final String? departmentName;
  final GradeType type;

  /// Not ortalaması. Backend `double` döndürüyor; 0 "girilmemiş" demek.
  final double? gpa;

  final DateTime? startDate;
  final DateTime? endDate;

  /// Kartın alt satırı: bölüm ve fakülte.
  String get subtitle {
    final parts = [
      if (departmentName != null && departmentName!.isNotEmpty) departmentName!,
      if (facultyName != null && facultyName!.isNotEmpty) facultyName!,
    ];
    return parts.join(' · ');
  }

  String get durationLabel => formatDateRange(startDate, endDate);

  factory Education.fromJson(Map<String, dynamic> json) {
    final gpa = json['gpa'];

    return Education(
      id: '${json['id']}',
      universityId: json['universityId'] as String?,
      universityName: json['universityName'] as String?,
      facultyId: json['facultyId'] as String?,
      facultyName: json['facultyName'] as String?,
      departmentId: json['departmentId'] as String?,
      departmentName: json['departmentName'] as String?,
      type: GradeType.fromCode(json['type']),
      gpa: gpa is num && gpa > 0 ? gpa.toDouble() : null,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'universityId': universityId,
      'universityName': universityName,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'type': type.code,
      'gpa': gpa,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
