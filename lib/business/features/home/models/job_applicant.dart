import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

/// Bir ilana gelen başvuru, işverenin gördüğü hâliyle.
///
/// `GET /jobs/{jobId}/applications` yanıtındaki `JobApplicantDto` karşılığı.
/// Çalışan tarafındaki [JobApplication] ile karıştırılmamalı: o başvuranın
/// gördüğü kayıt ve içinde ilan var; bu işverenin gördüğü kayıt ve içinde
/// başvuran var.
class JobApplicant {
  const JobApplicant({
    required this.id,
    required this.status,
    required this.user,
    this.applicationDateTime,
    this.notes,
  });

  /// Başvurunun kimliği. Kabul/ret bu kimlikle gönderiliyor
  /// (`POST /job-applications/{id}/respond`), kullanıcı kimliğiyle değil.
  final String id;

  final ApplicationStatus status;

  /// Başvuran kişi. Backend `SafeUserDto` döndürüyor; onun Dart karşılığı
  /// [JobCreator] olarak zaten var, ikinci bir kopya çıkarılmadı.
  final JobCreator user;

  final DateTime? applicationDateTime;

  /// Başvuru sırasında yazılan ön yazı; boş bırakılmış olabilir.
  final String? notes;

  /// Başvuranın mesleği.
  ///
  /// TODO(backend): `JobApplicantDto` bu alanı taşımıyor — `SafeUserDto`
  /// yalnızca ad, kullanıcı adı ve fotoğraf döndürüyor. İşverenin aday
  /// listesinde mesleği görmesi için `jobTitle`'ın da dönmesi gerekiyor;
  /// gelene kadar satır çizilmiyor. Aday başına ayrı bir profil isteği
  /// atmak N+1 olurdu, o yüzden burada doldurulmuyor.
  String? get jobTitle => user.jobTitle;

  String get fullName => user.fullName;

  String? get profilePictureUrl => user.profilePictureUrl;

  /// Başvurunun hâlâ yanıt bekleyip beklemediği.
  bool get isPending => status == ApplicationStatus.applied;

  factory JobApplicant.fromJson(Map<String, dynamic> json) {
    final applicant = json['applicant'];

    return JobApplicant(
      id: '${json['id']}',
      status: ApplicationStatus.fromCode(json['status']),
      user: applicant is Map<String, dynamic>
          ? JobCreator.fromJson(applicant)
          : const JobCreator(id: '', firstName: '', lastName: ''),
      applicationDateTime: _parseDate(json['applicationDateTime']),
      notes: json['notes'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
