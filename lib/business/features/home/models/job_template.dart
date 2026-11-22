import 'package:koala/employee/features/home/models/job.dart';

/// İşverenin ilan şablonu. Formdan değil **yayınlanmış ilandan** çıkarılıyor;
/// adres, tarih ve durum kopyalanmıyor, forma uygularken de o alanlara
/// dokunulmuyor.
class JobTemplate {
  const JobTemplate({
    required this.id,
    required this.templateName,
    this.companyId,
    this.category,
    this.title,
    this.description,
    this.sector,
    this.position,
    this.duties,
    this.dressCode,
    this.type = JobType.oneTime,
    this.salaryType = SalaryType.daily,
    this.salary,
    this.minAge,
    this.maxAge,
    this.experienceRequired = false,
    this.insuranceRequired = false,
    this.createdAt,
  });

  final String id;

  /// `Cumartesi garson`; sunucuda `@NotBlank`.
  final String templateName;

  /// Bireysel ilandan çıkarıldıysa `null`.
  final String? companyId;

  final JobCategory? category;
  final String? title;
  final String? description;
  final String? sector;
  final String? position;
  final String? duties;
  final String? dressCode;
  final JobType type;
  final SalaryType salaryType;
  final double? salary;
  final int? minAge;
  final int? maxAge;
  final bool experienceRequired;
  final bool insuranceRequired;
  final DateTime? createdAt;

  factory JobTemplate.fromJson(Map<String, dynamic> json) {
    final category = json['category'];

    return JobTemplate(
      id: '${json['id']}',
      templateName: json['templateName'] as String? ?? '',
      companyId: json['companyId'] as String?,
      category: category is Map<String, dynamic>
          ? JobCategory.fromJson(category)
          : null,
      title: json['title'] as String?,
      description: json['description'] as String?,
      sector: json['sector'] as String?,
      position: json['position'] as String?,
      duties: json['duties'] as String?,
      dressCode: json['dressCode'] as String?,
      type: JobType.fromCode(json['type']),
      salaryType: SalaryType.fromCode(json['salaryType']),
      salary: (json['salary'] as num?)?.toDouble(),
      minAge: (json['minAge'] as num?)?.toInt(),
      maxAge: (json['maxAge'] as num?)?.toInt(),
      experienceRequired: json['experienceRequired'] as bool? ?? false,
      insuranceRequired: json['insuranceRequired'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateName': templateName,
      'companyId': companyId,
      'category': category?.toJson(),
      'title': title,
      'description': description,
      'sector': sector,
      'position': position,
      'duties': duties,
      'dressCode': dressCode,
      'type': type.code,
      'salaryType': salaryType.code,
      'salary': salary,
      'minAge': minAge,
      'maxAge': maxAge,
      'experienceRequired': experienceRequired,
      'insuranceRequired': insuranceRequired,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Kategori ve sigortanın bu işverende ne olacağı. Sigorta zorunlu kategori
  /// bireysel ilana kapalı; kategori sessizce değiştirilmez, boş bırakılıp
  /// nedeni söylenir ki kullanıcı en sonda `400` almasın.
  JobTemplateApplication applyFor({required bool isCompanyJob}) {
    if (isCompanyJob) {
      return JobTemplateApplication(
        category: category,
        insuranceRequired: insuranceRequired,
      );
    }

    final blockedCategory = category;
    if (blockedCategory != null && blockedCategory.requiresInsurance) {
      return JobTemplateApplication(
        category: null,
        insuranceRequired: false,
        warning:
            'Şablondaki "${blockedCategory.displayName}" kategorisi sigortalı '
            'çalışma gerektiriyor ve bireysel ilanda seçilemiyor. Lütfen '
            'kategoriyi kendiniz seçin.',
      );
    }

    return JobTemplateApplication(
      category: blockedCategory,
      insuranceRequired: false,
      warning: insuranceRequired
          ? 'Sigortalı çalışma yalnızca şirket ilanlarında sunulabildiği için '
                'şablondaki sigorta tercihi uygulanmadı.'
          : null,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class JobTemplateApplication {
  const JobTemplateApplication({
    required this.category,
    required this.insuranceRequired,
    this.warning,
  });

  /// Bireysel işverene kapalıysa `null`; kullanıcı kendisi seçer.
  final JobCategory? category;

  final bool insuranceRequired;

  final String? warning;
}
