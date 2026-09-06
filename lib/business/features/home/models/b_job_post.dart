import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

/// İşverenin ilan listesindeki tek satır: ilanın özeti + o ilana gelen
/// başvurular.
///
/// İlan `GET /users/me/jobs`'tan ([Job], yani `JobSummaryDto`) geliyor;
/// açıklama/görevler/adres gibi alanlar burada **yok**, onlar için detay
/// ekranı `GET /jobs/{id}` çağırıyor.
///
/// Başvurular ayrı bir uçtan (`GET /jobs/{jobId}/applications`) geldiği için
/// ilan listesi geldikten sonra dolduruluyor — [applicantsLoaded] o ana kadar
/// `false` kalıyor ki "henüz başvuru yok" yazısı yükleme sırasında görünmesin.
class BJobPost {
  const BJobPost({
    required this.job,
    this.applications = const [],
    this.applicantsLoaded = false,
  });

  final Job job;

  /// İlana gelen bütün başvurular; bekleyeni de kabul edileni de reddedileni
  /// de içeriyor.
  final List<JobApplicant> applications;

  final bool applicantsLoaded;

  /// İlan hâlâ yürürlükte mi. "Aktif" ve "Geçmiş" sekmelerini bu ayırıyor;
  /// karar sunucudaki [JobStatus]'a ait, uygulamanın kendi bayrağına değil.
  bool get isActive =>
      job.status == JobStatus.open || job.status == JobStatus.inProgress;

  /// Yanıt bekleyen başvurular — işverenin kabul/ret göstereceği liste.
  ///
  /// Bir eylem çağrısı, o yüzden dar: yalnızca `APPLIED`. Geri çekilen ya da
  /// durumu tanınmayan kayıt burada yok; ilan detayındaki tam liste için
  /// [unansweredApplicants].
  List<JobApplicant> get applicants =>
      applications.where((a) => a.isPending).toList();

  /// İşverenin yanıtlamadığı başvurular — ilan detayındaki "Başvuranlar".
  ///
  /// [applicants]'tan farkı: geri çekilen ve durumu tanınmayan kayıtlar da
  /// burada. Sunucu geri çekilen başvuruyu silmiyor ve işverenin listesinden
  /// düşürmüyor — kart çiziliyor, yalnızca kabul/ret butonları çıkmıyor
  /// ([JobApplicant.isPending]). Kaydı gizlemek işverene başvuranın hiç
  /// olmadığını söylerdi.
  List<JobApplicant> get unansweredApplicants => applications
      .where((application) => !application.status.isAnsweredByEmployer)
      .toList();

  /// Kabul edilmiş başvurular.
  ///
  /// Kabul, ilanı kendiliğinden kapatmıyor — sunucu bir atama açıp çalışanın
  /// onayını bekliyor — ve bir ilana birden çok kişi kabul edilebiliyor. Bu
  /// yüzden tek kişi değil liste: aksi hâlde kabul edilen aday, ilan hâlâ
  /// açıkken hiçbir yerde görünmüyordu.
  List<JobApplicant> get acceptedApplicants => applications
      .where((application) => application.status == ApplicationStatus.accepted)
      .toList();

  /// İşi alan kişi: kabul edilmiş ilk başvuru. Kabul edilen yoksa `null`.
  JobApplicant? get worker {
    final accepted = acceptedApplicants;
    return accepted.isEmpty ? null : accepted.first;
  }

  BJobPost copyWith({
    Job? job,
    List<JobApplicant>? applications,
    bool? applicantsLoaded,
  }) {
    return BJobPost(
      job: job ?? this.job,
      applications: applications ?? this.applications,
      applicantsLoaded: applicantsLoaded ?? this.applicantsLoaded,
    );
  }
}
