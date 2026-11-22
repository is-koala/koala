import 'package:koala/product/extensions/date_extensions.dart';

enum EmploymentType {
  fullTime('FULL_TIME', 'Tam zamanlı'),
  partTime('PART_TIME', 'Yarı zamanlı'),
  freelance('FREELANCE', 'Serbest'),
  internship('INTERNSHIP', 'Staj'),
  seasonal('SEASONAL', 'Dönemlik');

  const EmploymentType(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan değerde [EmploymentType.fullTime].
  static EmploymentType fromCode(Object? value) {
    return EmploymentType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => EmploymentType.fullTime,
    );
  }
}

/// İş deneyimi; `/users/me`'de gelir, yazma ayrı uçlardan.
class Experience {
  const Experience({
    required this.id,
    required this.title,
    this.companyName,
    this.employmentType = EmploymentType.fullTime,
    this.cityName,
    this.startDate,
    this.endDate,
    this.description,
  });

  final String id;
  final String title;
  final String? companyName;
  final EmploymentType employmentType;
  final String? cityName;
  final DateTime? startDate;

  /// `null` ise sürüyor.
  final DateTime? endDate;

  final String? description;

  String get subtitle {
    final parts = [
      if (companyName != null && companyName!.isNotEmpty) companyName!,
      if (cityName != null && cityName!.isNotEmpty) cityName!,
    ];
    return parts.join(' · ');
  }

  /// `Ocak 2023 - Halen`.
  String get durationLabel => formatDateRange(startDate, endDate);

  factory Experience.fromJson(Map<String, dynamic> json) {
    return Experience(
      id: '${json['id']}',
      title: json['title'] as String? ?? '',
      companyName: json['companyName'] as String?,
      employmentType: EmploymentType.fromCode(json['employmentType']),
      cityName: json['cityName'] as String?,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'companyName': companyName,
      'employmentType': employmentType.code,
      'cityName': cityName,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'description': description,
    };
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
