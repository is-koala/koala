import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

/// İşverenin gelen kutusundaki tek başvuru. Backend `ReceivedApplicationDto`
/// karşılığı: `GET /users/me/received-applications`.
///
/// [JobApplicant]'tan farkı: o bir ilanın altında, ilan zaten biliniyorken
/// çiziliyor; bu **ilanlar arası** bir satır olduğu için hangi ilana, hangi
/// şirket adına geldiğini de taşıyor ([jobId], [postingTitle], [companyName]).
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

  /// Başvurunun kimliği. Kabul/ret bu kimlikle gidiyor; satırın anahtarı da
  /// bu.
  final String id;

  final ApplicationStatus status;

  /// Başvuran kişi. `SafeUserDto`; e-posta ve telefon bilerek yok.
  final JobCreator applicant;

  /// Başvurunun geldiği ilan. Karar ekranı (`/business/job-detail`) bununla
  /// açılıyor.
  final String jobId;

  /// İlanın başlığı. Alan adı `jobTitle` değil: aynı ekranın kardeş DTO'sunda
  /// `jobTitle` başvuranın **mesleği** (`JobApplicantDto.jobTitle`).
  final String postingTitle;

  /// İlanın şu anki durumu. Kapanmış ya da iptal edilmiş ilanın başvurusu
  /// listede kalıyor; satır bunu söylüyor.
  final JobStatus jobStatus;

  final DateTime? applicationDateTime;

  /// Başvurunun kabul ya da reddedildiği an; bekleyen başvuruda `null`.
  final DateTime? answeredDateTime;

  /// Başvuru sırasında yazılan ön yazı.
  final String? notes;

  /// İlan şirket adına açıldıysa şirketin kimliği ve adı; bireysel ilanda
  /// ikisi de `null`.
  final String? companyId;
  final String? companyName;

  /// Kabulle doğan atamanın kimliği; kabul edilmediyse `null`.
  final String? assignmentId;

  String get fullName {
    final name = applicant.fullName;
    if (name.isNotEmpty) return name;
    return applicant.username ?? '';
  }

  /// İlan artık başvuru almıyor mu (kapalı ya da iptal).
  bool get isJobClosed => jobStatus != JobStatus.open;

  /// Adayın profil ekranı için başvuran kaydı.
  ///
  /// `BUserProfilePage` başvuruyu `JobApplicant` olarak alıyor; kapağı bununla
  /// hemen çiziyor, mesleği ve özgeçmişi `GET /users/{id}`'den dolduruyor.
  /// Gelen kutusu satırı ikisini taşımıyor — `null`.
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

/// Sayfalı gelen kutusu yanıtı. Backend `PageDto<ReceivedApplicationDto>`
/// karşılığı; anahtarlar `JobPage` ve `TalentPoolPage` ile aynı.
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
