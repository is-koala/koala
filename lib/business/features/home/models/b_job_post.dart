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

  /// Henüz yanıtlanmamış başvurular — işverenin kabul/ret göstereceği liste.
  List<JobApplicant> get applicants =>
      applications.where((a) => a.isPending).toList();

  /// İşi alan kişi: kabul edilmiş başvuru. Kabul edilen yoksa `null`.
  JobApplicant? get worker {
    for (final application in applications) {
      if (application.status == ApplicationStatus.accepted) return application;
    }
    return null;
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
