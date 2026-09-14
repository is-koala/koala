import 'package:koala/business/features/home/models/b_job_staffing.dart';
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
    this.staffing = BJobStaffing.unknown,
    this.applications = const [],
    this.applicantsLoaded = false,
    this.applicantsLoading = false,
    this.applicantsError,
  });

  final Job job;

  /// Kontenjan: aranan ve işe alınan kişi sayısı. Liste yanıtıyla birlikte
  /// geliyor ([BJobListEntry]); alanı göndermeyen sunucuda bilinmiyor.
  final BJobStaffing staffing;

  /// İlana gelen bütün başvurular; bekleyeni de kabul edileni de reddedileni
  /// de içeriyor.
  final List<JobApplicant> applications;

  final bool applicantsLoaded;

  /// Başvuranlar için uçuşta istek var mı.
  ///
  /// Yenilemede daha önceki [applications] korunabildiği için bu değer,
  /// [applicantsLoaded]'dan bağımsızdır.
  final bool applicantsLoading;

  /// Yalnızca bu ilanın başvuranlarını yükleme/yenileme hatası.
  /// İlan listesinin hatasıyla karışmaz ve mevcut [applications]'ı silmez.
  final String? applicantsError;

  /// İlan hâlâ yürürlükte mi. "Aktif" ve "Geçmiş" sekmelerini bu ayırıyor;
  /// karar sunucudaki [JobStatus]'a ait, uygulamanın kendi bayrağına değil.
  bool get isActive => job.status == JobStatus.open;

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

  /// Liste yenilemesindeki yeni ilan özetini alırken başvuran durumunu korur.
  BJobPost withEntry(BJobListEntry entry) {
    return BJobPost(
      job: entry.job,
      staffing: entry.staffing,
      applications: applications,
      applicantsLoaded: applicantsLoaded,
      applicantsLoading: applicantsLoading,
      applicantsError: applicantsError,
    );
  }

  BJobPost startApplicantLoad() {
    return BJobPost(
      job: job,
      staffing: staffing,
      applications: applications,
      applicantsLoaded: applicantsLoaded,
      applicantsLoading: true,
    );
  }

  BJobPost completeApplicantLoad(List<JobApplicant> value) {
    return BJobPost(
      job: job,
      staffing: staffing,
      applications: value,
      applicantsLoaded: true,
    );
  }

  BJobPost failApplicantLoad(String message) {
    return BJobPost(
      job: job,
      staffing: staffing,
      applications: applications,
      applicantsLoaded: applicantsLoaded,
      applicantsError: message,
    );
  }
}
