import 'package:koala/employee/features/home/models/job.dart';

/// İş arayanın yeni ilanlar için kaydettiği arama ölçütleri.
class JobAlert {
  const JobAlert({
    required this.id,
    required this.name,
    required this.isActive,
    this.category,
    this.cityName,
    this.districtName,
    this.minimumSalary,
    this.type,
    this.lastNotifiedAt,
  });

  final String id;
  final String name;
  final JobCategory? category;
  final String? cityName;
  final String? districtName;
  final double? minimumSalary;
  final JobType? type;
  final bool isActive;
  final DateTime? lastNotifiedAt;

  factory JobAlert.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final salary = json['minSalary'];

    return JobAlert(
      id: '${json['id']}',
      name: json['alertName'] as String? ?? '',
      category: category is Map<String, dynamic>
          ? JobCategory.fromJson(category)
          : null,
      cityName: json['cityName'] as String?,
      districtName: json['districtName'] as String?,
      minimumSalary: salary is num ? salary.toDouble() : null,
      type: json['type'] == null ? null : JobType.fromCode(json['type']),
      isActive: json['active'] as bool? ?? true,
      lastNotifiedAt: json['lastNotifiedAt'] is String
          ? DateTime.tryParse(json['lastNotifiedAt'] as String)
          : null,
    );
  }
}

/// Oluşturma ve güncellemenin ortak, doğrulanabilir alarm girdisi.
class JobAlertDraft {
  const JobAlertDraft({
    required this.name,
    this.category,
    this.cityName,
    this.districtName,
    this.minimumSalary,
    this.type,
    this.isActive = true,
  });

  final String name;
  final JobCategory? category;
  final String? cityName;
  final String? districtName;
  final double? minimumSalary;
  final JobType? type;
  final bool isActive;

  void validate() {
    final normalizedCity = _trimmed(cityName);
    final normalizedDistrict = _trimmed(districtName);

    if (name.trim().isEmpty) {
      throw const JobAlertValidationException('Alarm adı zorunludur.');
    }
    if (name.trim().length > 255) {
      throw const JobAlertValidationException(
        'Alarm adı en fazla 255 karakter olabilir.',
      );
    }
    if (minimumSalary != null && minimumSalary! < 0) {
      throw const JobAlertValidationException(
        'Asgari ücret sıfırdan küçük olamaz.',
      );
    }

    final hasPrimaryCriterion =
        category != null ||
        normalizedCity != null ||
        minimumSalary != null ||
        type != null;
    if (!hasPrimaryCriterion && normalizedDistrict != null) {
      throw const JobAlertValidationException(
        'İlçe tek başına yeterli değil; kategori, il, tür ya da asgari '
        'ücretten birini de seçin.',
      );
    }
    if (!hasPrimaryCriterion) {
      throw const JobAlertValidationException('En az bir alarm ölçütü seçin.');
    }
  }

  Map<String, dynamic> toRequestBody() {
    validate();
    return {
      'alertName': name.trim(),
      'categoryId': category?.id,
      'cityName': _trimmed(cityName),
      'districtName': _trimmed(districtName),
      'minSalary': minimumSalary,
      'type': type?.code,
      'active': isActive,
    };
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class JobAlertValidationException implements Exception {
  const JobAlertValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
