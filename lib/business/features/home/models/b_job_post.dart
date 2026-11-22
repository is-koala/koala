import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

/// İşverenin ilan listesindeki satır: ilan özeti + başvurular. Başvurular ayrı
/// uçtan sonra geldiği için [applicantsLoaded] o ana kadar `false`, ki "henüz
/// başvuru yok" yüklenirken görünmesin.
class BJobPost {
  const BJobPost({
    required this.job,
    this.applications = const [],
    this.applicantsLoaded = false,
    this.applicantsLoading = false,
    this.applicantsError,
  });

  final Job job;

  final List<JobApplicant> applications;

  final bool applicantsLoaded;

  /// Yenilemede eski liste korunabildiği için [applicantsLoaded]'dan bağımsız.
  final bool applicantsLoading;

  /// İlan listesinin hatasıyla karışmaz, mevcut listeyi silmez.
  final String? applicantsError;

  /// Aktif/Geçmiş ayrımı sunucudaki [JobStatus]'a ait.
  bool get isActive => job.status == JobStatus.open;

  /// Kabul/ret gösterilecek başvurular: yalnız `APPLIED`. Tam liste
  /// [unansweredApplicants].
  List<JobApplicant> get applicants =>
      applications.where((a) => a.isPending).toList();

  /// Yanıtlanmamış başvurular; geri çekilenler de burada. Kart çiziliyor ama
  /// kabul/ret yok: kaydı gizlemek başvuranın hiç olmadığını söylerdi.
  List<JobApplicant> get unansweredApplicants => applications
      .where((application) => !application.status.isAnsweredByEmployer)
      .toList();

  /// Kabul edilenler. Kabul ilanı kapatmıyor ve birden çok kişi kabul
  /// edilebiliyor; bu yüzden liste.
  List<JobApplicant> get acceptedApplicants => applications
      .where((application) => application.status == ApplicationStatus.accepted)
      .toList();

  /// İlk kabul edilen; yoksa `null`.
  JobApplicant? get worker {
    final accepted = acceptedApplicants;
    return accepted.isEmpty ? null : accepted.first;
  }

  BJobPost withJob(Job value) {
    return BJobPost(
      job: value,
      applications: applications,
      applicantsLoaded: applicantsLoaded,
      applicantsLoading: applicantsLoading,
      applicantsError: applicantsError,
    );
  }

  BJobPost startApplicantLoad() {
    return BJobPost(
      job: job,
      applications: applications,
      applicantsLoaded: applicantsLoaded,
      applicantsLoading: true,
    );
  }

  BJobPost completeApplicantLoad(List<JobApplicant> value) {
    return BJobPost(job: job, applications: value, applicantsLoaded: true);
  }

  BJobPost failApplicantLoad(String message) {
    return BJobPost(
      job: job,
      applications: applications,
      applicantsLoaded: applicantsLoaded,
      applicantsError: message,
    );
  }
}
