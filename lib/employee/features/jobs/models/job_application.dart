import 'package:koala/employee/features/home/models/job.dart';

/// Başvurunun sunucudaki durumu. Backend `ApplicationStatus` karşılığı.
enum ApplicationStatus {
  applied('APPLIED', 'Başvuru Bekliyor'),
  accepted('ACCEPTED', 'Kabul Edildi'),
  rejected('REJECTED', 'Reddedildi');

  const ApplicationStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  static ApplicationStatus fromCode(Object? value) {
    return ApplicationStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => ApplicationStatus.applied,
    );
  }
}

/// Kullanıcının bir ilana yaptığı başvuru.
///
/// `GET /users/me/applications` yanıtındaki `MyApplicationDto` karşılığı.
/// Başvuru kabul edildiğinde iş bir **atamaya** dönüşüyor ve o noktadan
/// sonrası `GET /users/me/assignments`'ta izleniyor — [assignmentId] o kaydın
/// kimliği.
class JobApplication {
  const JobApplication({
    required this.id,
    required this.job,
    required this.status,
    this.notes,
    this.rejectionReason,
    this.applicationDateTime,
    this.answeredDateTime,
    this.assignmentId,
  });

  final String id;

  /// Başvurulan ilanın özeti; liste bunu ayrıca çekmeden çizebiliyor.
  final Job job;

  final ApplicationStatus status;

  /// Başvuru sırasında yazılan ön yazı.
  final String? notes;

  /// Reddedildiyse işverenin gerekçesi.
  final String? rejectionReason;

  final DateTime? applicationDateTime;
  final DateTime? answeredDateTime;

  /// Kabul edilmiş başvurunun atama kimliği; henüz yanıtlanmamışsa `null`.
  final String? assignmentId;

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: '${json['id']}',
      job: Job.fromJson((json['job'] as Map<String, dynamic>?) ?? const {}),
      status: ApplicationStatus.fromCode(json['status']),
      notes: json['notes'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      applicationDateTime: _parseDate(json['applicationDateTime']),
      answeredDateTime: _parseDate(json['answeredDateTime']),
      assignmentId: json['assignmentId'] == null
          ? null
          : '${json['assignmentId']}',
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Sayfalı başvuru yanıtı.
class JobApplicationPage {
  const JobApplicationPage({
    this.applications = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<JobApplication> applications;
  final int page;
  final int totalElements;
  final bool last;

  factory JobApplicationPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return JobApplicationPage(
      applications: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(JobApplication.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
