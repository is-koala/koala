import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

/// İlana gelen başvuru, işverenin gördüğü hâliyle (`JobApplicantDto`).
/// Çalışanın gördüğü kayıt [JobApplication].
class JobApplicant {
  const JobApplicant({
    required this.id,
    required this.status,
    required this.user,
    this.applicationDateTime,
    this.notes,
    this.jobTitle,
    this.cvUrl,
    this.answeredDateTime,
    this.assignmentId,
  });

  /// Kabul/ret bu kimlikle gönderilir, kullanıcı kimliğiyle değil.
  final String id;

  final ApplicationStatus status;

  final JobCreator user;

  final DateTime? applicationDateTime;

  final String? notes;

  /// Meslek `SafeUserDto`'da değil `JobApplicantDto`'da.
  final String? jobTitle;

  /// Yalnız ilanın işverenine dolu; yoksa `null`.
  final String? cvUrl;

  /// Yanıtlanmadıysa ya da eski sunucuda `null`.
  final DateTime? answeredDateTime;

  /// Kabulle doğan atama; aday kartı atamasını bununla buluyor. İptal sonrası
  /// yeniden kabulde doğru kaydı tahmine gerek kalmadan söylüyor.
  final String? assignmentId;

  String get fullName => user.fullName;

  /// Boş dize de "yok".
  bool get hasCv => cvUrl != null && cvUrl!.isNotEmpty;

  String? get profilePictureUrl => user.profilePictureUrl;

  /// Geri çekilen, yanıtlanan ve tanınmayan başvuru bekleyen sayılmaz;
  /// kabul/ret çizilmez.
  bool get isPending => status.isPending;

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
      jobTitle: json['jobTitle'] as String?,
      cvUrl: json['cvUrl'] as String?,
      answeredDateTime: _parseDate(json['answeredDateTime']),
      assignmentId: switch (json['assignmentId']) {
        final String value when value.isNotEmpty => value,
        _ => null,
      },
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
