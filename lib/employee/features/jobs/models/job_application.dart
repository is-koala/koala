import 'package:koala/employee/features/home/models/job.dart';

/// Başvurunun sunucudaki durumu. Backend `ApplicationStatus` karşılığı.
enum ApplicationStatus {
  applied('APPLIED', 'Başvuru Bekliyor'),
  accepted('ACCEPTED', 'Kabul Edildi'),
  rejected('REJECTED', 'Reddedildi'),

  /// Başvuran kendi başvurusunu geri çekti (`POST .../withdraw`).
  ///
  /// Kayıt silinmiyor, durumu değişiyor: iki taraf da başvurunun olduğunu
  /// ama artık geçerli olmadığını görüyor.
  withdrawn('WITHDRAWN', 'Geri Çekildi'),

  /// Sunucudan gelen ama bu sürümün tanımadığı durum.
  ///
  /// Backend enum'una yeni bir değer eklemek sürüm atlatmıyor; eski
  /// uygulamalar o değeri görmeye devam ediyor. Bilinmeyen kodu var olan bir
  /// duruma benzetmek çökmekten **daha** tehlikeli: `applied`'a düşen bir
  /// kayıt "yanıt bekliyor" gibi görünür, kullanıcı ya da işveren sunucunun
  /// reddedeceği bir işlemi dener. Bu yüzden bilinmeyen kod kendi adıyla
  /// duruyor ve hiçbir eylemi hak etmiyor — bkz. [isPending].
  unknown('UNKNOWN', 'Bilinmiyor');

  const ApplicationStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Başvuru hâlâ işverenin yanıtını bekliyor mu.
  ///
  /// **Uygulamadaki tek "bu başvuruya bir şey yapılabilir" kararı burası.**
  /// Geri çekme düğmesi de, işverenin kabul/ret butonları da buna bakıyor;
  /// sunucu ikisini de yalnızca `APPLIED` durumunda kabul ediyor
  /// (`JobApplicationManager`: geri çekmede `409`, yanıtlamada `409`).
  /// `unknown` dahil kalan her durum `false`: ne olduğunu bilmediğimiz bir
  /// kayıt üzerinde eylem önermek, sunucunun geri çevireceği bir işi
  /// kullanıcıya vaat etmek olurdu.
  bool get isPending => this == ApplicationStatus.applied;

  /// Bu kayıt aynı ilana yeniden başvurmayı engelliyor mu.
  ///
  /// Sunucunun kuralı: geri çekilmiş **olmayan** her kayıt engelliyor
  /// (`existsByJobIdAndUserIdAndStatusNot(jobId, userId, WITHDRAWN)`). Geri
  /// çeken kullanıcı, ilan hâlâ açıkken yeniden başvurabiliyor.
  ///
  /// `unknown` engelliyor: tanımadığımız bir durumda düğmeyi açıp sunucudan
  /// `409` yemektense kapalı tutmak doğru taraf — [isPending] ile aynı
  /// gerekçe, ters yönde.
  bool get blocksReapplication => this != ApplicationStatus.withdrawn;

  /// Bu durumu **işveren** mi yazdı.
  ///
  /// Kabul ve ret işverenin kendi cevabı; geri çekme başvurana ait, `applied`
  /// ise henüz kimsenin cevabı değil. İşverenin "Başvuranlar" listesi
  /// yanıtlamadıklarını gösteriyor: geri çekilen kayıt orada kalıyor, çünkü
  /// sunucu onu silmiyor ve listesinden düşürmüyor — sadece yanıtlanamıyor.
  bool get isAnsweredByEmployer =>
      this == ApplicationStatus.accepted || this == ApplicationStatus.rejected;

  /// Sunucudan gelen kodu enum'a çevirir; tanınmayan kod [unknown] olur.
  static ApplicationStatus fromCode(Object? value) {
    return ApplicationStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => ApplicationStatus.unknown,
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

  /// Yalnızca durumu değişmiş bir kopya.
  ///
  /// Geri çekme ucu `JobApplicationDetailDto` döndürüyor ve onun `job` alanı
  /// `ShortJobDto` — ücret, şirket ve kategori taşımıyor. Bu yüzden listedeki
  /// kayıt yanıtla **değiştirilmiyor**, yalnızca sunucunun söylediği durum
  /// alınıyor; [job] ve geri kalanı yerinde kalıyor.
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
