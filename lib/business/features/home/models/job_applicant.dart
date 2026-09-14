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
    this.jobTitle,
    this.cvUrl,
    this.answeredDateTime,
    this.assignmentId,
    this.rejectionReason,
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
  /// Alan `SafeUserDto`'da değil `JobApplicantDto`'nun kendisinde: o DTO on
  /// ayrı yanıtta kullanılıyor ve mesleği hepsine yaymanın gereği yok.
  final String? jobTitle;

  /// Başvuranın özgeçmişinin bağlantısı; yüklememişse `null`.
  ///
  /// Sunucu bu adresi yalnızca ilanın işverenine döndürüyor, indirme yolu da
  /// ayrıca sahiplik kontrolü yapıyor — başkasının dosyası `404`.
  final String? cvUrl;

  /// Başvurunun kabul ya da reddedildiği an; henüz yanıtlanmadıysa `null`.
  ///
  /// koala-backend#282 ile geldi; eski sunucuda alan yok ve kart o satırı
  /// çizmiyor.
  final DateTime? answeredDateTime;

  /// Kabulle doğan atamanın kimliği; kabul edilmediyse ya da sunucu alanı
  /// göndermiyorsa `null`. Atama panelinden bağımsız bir eşleşme anahtarı:
  /// çalışan kimliğiyle eşlemek iptal sonrası yeniden kabulde en yeni atamayı
  /// seçmeyi gerektiriyor, bu alan doğrudan doğru kaydı söylüyor.
  final String? assignmentId;

  /// İşverenin yazdığı ret gerekçesi; reddedilmediyse ya da gerekçe
  /// yazılmadıysa `null`.
  final String? rejectionReason;

  String get fullName => user.fullName;

  /// Özgeçmiş bağlantısı var mı. Sunucu adresi yalnızca ilanın işverenine
  /// dolduruyor; boş dize de "yok" sayılıyor.
  bool get hasCv => cvUrl != null && cvUrl!.isNotEmpty;

  String? get profilePictureUrl => user.profilePictureUrl;

  /// Başvurunun hâlâ yanıt bekleyip beklemediği.
  ///
  /// Kararı [ApplicationStatus.isPending] veriyor: geri çekilen, yanıtlanan ve
  /// durumu tanınmayan başvuru bekleyen sayılmıyor, o yüzden kabul/ret
  /// butonları çizilmiyor. Sunucu da yalnızca `APPLIED` başvuruyu
  /// yanıtlatıyor; geri çekilmişe basmak `409` demekti.
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
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
