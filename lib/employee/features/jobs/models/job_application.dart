import 'package:koala/employee/features/home/models/job.dart';

enum ApplicationStatus {
  applied('APPLIED', 'Başvuru Bekliyor'),
  accepted('ACCEPTED', 'Kabul Edildi'),
  rejected('REJECTED', 'Reddedildi'),

  /// Kayıt silinmiyor; iki taraf da geçersiz olduğunu görüyor.
  withdrawn('WITHDRAWN', 'Geri Çekildi'),

  /// Bu sürümün tanımadığı durum. Var olan bir duruma benzetmek çökmekten
  /// tehlikeli: `applied`'a düşen kayıt reddedilecek bir işleme davet eder.
  /// Kendi adıyla durur, eylem almaz ([isPending]).
  unknown('UNKNOWN', 'Bilinmiyor');

  const ApplicationStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  /// **"Bu başvuruya bir şey yapılabilir" kararının tek yeri.** Geri çekme ve
  /// kabul/ret buna bakıyor; sunucu ikisini de yalnız `APPLIED`'da kabul
  /// ediyor. `unknown` dahil diğerleri `false`.
  bool get isPending => this == ApplicationStatus.applied;

  /// Aynı ilana yeniden başvurmayı engelliyor mu: sunucuda geri çekilmemiş her
  /// kayıt engelliyor. `unknown` da engelliyor, `409` yemektense kapalı.
  bool get blocksReapplication => this != ApplicationStatus.withdrawn;

  /// Kabul ve ret işverenin cevabı; geri çekme başvurana ait.
  bool get isAnsweredByEmployer =>
      this == ApplicationStatus.accepted || this == ApplicationStatus.rejected;

  /// Tanınmayan kod [unknown].
  static ApplicationStatus fromCode(Object? value) {
    return ApplicationStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => ApplicationStatus.unknown,
    );
  }
}

/// Kullanıcının başvurusu (`MyApplicationDto`). Kabul edilince atamaya dönüşür;
/// [assignmentId] o kaydın kimliği.
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

  final Job job;

  final ApplicationStatus status;

  final String? notes;

  final String? rejectionReason;

  final DateTime? applicationDateTime;
  final DateTime? answeredDateTime;

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

  /// Yalnız durumu değişmiş kopya: geri çekme yanıtındaki `job` eksik
  /// (`ShortJobDto`), kayıt yanıtla değiştirilmez.
  JobApplication copyWith({ApplicationStatus? status}) {
    return JobApplication(
      id: id,
      job: job,
      status: status ?? this.status,
      notes: notes,
      rejectionReason: rejectionReason,
      applicationDateTime: applicationDateTime,
      answeredDateTime: answeredDateTime,
      assignmentId: assignmentId,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

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
