import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

/// İşverenin gelen kutusundaki başvuru. İlanlar arası satır olduğu için ilanı
/// ve şirketi de taşıyor.
class ReceivedApplication {
  const ReceivedApplication({
    required this.id,
    required this.status,
    required this.applicant,
    required this.jobId,
    required this.postingTitle,
    required this.jobStatus,
    this.applicationDateTime,
    this.answeredDateTime,
    this.notes,
    this.companyId,
    this.companyName,
    this.assignmentId,
  });

  final String id;

  final ApplicationStatus status;

  /// `SafeUserDto`; e-posta ve telefon bilerek yok.
  final JobCreator applicant;

  final String jobId;

  /// `jobTitle` değil: kardeş DTO'da o ad başvuranın mesleği.
  final String postingTitle;

  /// Kapalı ya da iptal ilanın başvurusu listede kalır; satır bunu söyler.
  final JobStatus jobStatus;

  final DateTime? applicationDateTime;

  final DateTime? answeredDateTime;

  final String? notes;

  /// Bireysel ilanda `null`.
  final String? companyId;
  final String? companyName;

  final String? assignmentId;

  String get fullName {
    final name = applicant.fullName;
    if (name.isNotEmpty) return name;
    return applicant.username ?? '';
  }

  bool get isJobClosed => jobStatus != JobStatus.open;

  /// Profil ekranı için başvuran kaydı; meslek ve özgeçmiş gelmiyor (`null`),
  /// ekran onları profilden dolduruyor.
  JobApplicant toJobApplicant() {
    return JobApplicant(
      id: id,
      status: status,
      user: applicant,
      applicationDateTime: applicationDateTime,
      notes: notes,
      answeredDateTime: answeredDateTime,
      assignmentId: assignmentId,
    );
  }

  factory ReceivedApplication.fromJson(Map<String, dynamic> json) {
    final applicant = json['applicant'];
    final title = json['postingTitle'];

    return ReceivedApplication(
      id: '${json['id']}',
      status: ApplicationStatus.fromCode(json['status']),
      applicant: applicant is Map<String, dynamic>
          ? JobCreator.fromJson(applicant)
          : const JobCreator(id: '', firstName: '', lastName: ''),
      jobId: '${json['jobId']}',
      postingTitle: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'İlan',
      jobStatus: JobStatus.fromCode(json['jobStatus']),
      applicationDateTime: _parseDate(json['applicationDateTime']),
      answeredDateTime: _parseDate(json['answeredDateTime']),
      notes: _nonBlank(json['notes']),
      companyId: _nonBlank(json['companyId']),
      companyName: _nonBlank(json['companyName']),
      assignmentId: _nonBlank(json['assignmentId']),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _nonBlank(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
}

class ReceivedApplicationPage {
  const ReceivedApplicationPage({
    this.applications = const [],
    this.page = 0,
    this.size = 0,
    this.totalElements = 0,
    this.totalPages = 0,
    this.first = true,
    this.last = true,
  });

  final List<ReceivedApplication> applications;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  factory ReceivedApplicationPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return ReceivedApplicationPage(
      applications: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(ReceivedApplication.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }
}
