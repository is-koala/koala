import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/models/job_page.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İşverenin ilan uçları.
///
/// Çalışan tarafındaki `JobService` ilan **arıyor**; burası ilan **açıyor,
/// kapatıyor ve başvuruları yanıtlıyor**. İkisi ayrı duruyor çünkü yetki de
/// ayrı: bu sınıfın çağırdığı her uç ilan sahipliğini doğruluyor.
class EmployerJobService {
  EmployerJobService._(this._apiClient);

  static final EmployerJobService _instance = EmployerJobService._(ApiClient());

  factory EmployerJobService() => _instance;

  @visibleForTesting
  factory EmployerJobService.withClient(ApiClient apiClient) {
    return EmployerJobService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Varsayılan sayfa boyutu; bir işverenin ilan sayısı azdır, tek sayfa
  /// çoğu durumda yetiyor.
  static const int defaultPageSize = 50;

  /// İşverenin açtığı ilanlar, yeniden eskiye.
  ///
  /// Bireysel ve kurumsal ilanların ikisi de burada: backend `creatorId`'ye
  /// bakıyor, dolayısıyla şirket kimliği geçmeye gerek yok.
  Future<JobPage> fetchMyJobs({int page = 0, int size = defaultPageSize}) {
    return _apiClient.get<JobPage>(
      ApiPaths.myJobs,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => JobPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Yeni ilan açar.
  ///
  /// [companyId] doluysa ilan şirket adına açılıyor, boşsa bireysel. Kullanıcı
  /// onaylı bir şirkete bağlıysa kurumsal uç kullanılmalı; ilan o zaman şirket
  /// adıyla listeleniyor.
  Future<JobDetail> createJob(CreateJobRequest request, {String? companyId}) {
    final forCompany = companyId != null;

    return _apiClient.post<JobDetail>(
      forCompany
          ? ApiPaths.companyJobs(companyId)
          : ApiPaths.createIndividualJob,
      body: request.toJson(forCompany: forCompany),
      parse: (data) => JobDetail.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İlanı başvuruya kapatır.
  ///
  /// İlan geçerliliğini koruyor, yalnızca yeni başvuru alması duruyor.
  Future<void> closeJob(String jobId) {
    return _apiClient.postWithoutData(ApiPaths.closeJob(jobId));
  }

  /// İlanı iptal eder.
  ///
  /// Kapatmadan farkı ilanı geçersiz kılması ve başvuranlara bildirim
  /// göndermesi. Kayıt silinmiyor, başvuru geçmişi duruyor — backend'de ilan
  /// silen bir uç yok, olması da istenmedi.
  ///
  /// Devam eden bir iş ataması varsa (`PENDING_CONFIRMATION`, `CONFIRMED`,
  /// `IN_PROGRESS`) uç `409` döndürüyor: iptal, emanetteki parayı ve iptal
  /// politikasını arkadan dolanan ikinci bir yol olurdu. O durumda atamanın
  /// kendi iptal akışı kullanılmalı.
  Future<void> cancelJob(String jobId) {
    return _apiClient.postWithoutData(ApiPaths.cancelJob(jobId));
  }

  /// Bir ilana gelen başvurular.
  ///
  /// Yalnızca ilan sahibi çağırabiliyor; sayfalama yok, uç düz liste
  /// döndürüyor.
  Future<List<JobApplicant>> fetchApplicants(String jobId) {
    return _apiClient.get<List<JobApplicant>>(
      ApiPaths.jobApplications(jobId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(JobApplicant.fromJson)
                .toList()
          : const [],
    );
  }

  /// İşverenin atamaları, yeniden eskiye.
  ///
  /// Aynı uç `asEmployer` bayrağıyla iki tarafa da hizmet ediyor: çalışan
  /// tarafı `AssignmentService` üzerinden bayraksız çağırıyor, burası
  /// `true` geçiyor ve sunucu `creatorId`'ye bakıyor.
  ///
  /// İlan başına atama döndüren bir uç yok — `GET /jobs/{id}` atamayı
  /// taşımıyor — o yüzden tek ilanın ataması bu listeden süzülüyor.
  Future<AssignmentPage> fetchMyAssignments({
    int page = 0,
    int size = defaultPageSize,
  }) {
    return _apiClient.get<AssignmentPage>(
      ApiPaths.myAssignments,
      queryParameters: {'asEmployer': true, 'page': page, 'size': size},
      parse: (data) => AssignmentPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İşi tamamlanmış işaretler.
  ///
  /// Yalnızca işveren çağırabiliyor. Tamamlanınca emanetteki para çıkışa
  /// hazır hâle geliyor ve çalışanın rozetleri yeniden değerlendiriliyor;
  /// yani geri alınabilir bir işlem değil. `CONFIRMED` ve `IN_PROGRESS`
  /// dışından çağrılırsa `409`.
  ///
  /// İşveren hiç tamamlamazsa sunucu iş bitiminden belirli gün sonra
  /// kendiliğinden tamamlıyor; bu buton o beklemeyi kısaltıyor.
  Future<Assignment> completeAssignment(String assignmentId) {
    return _apiClient.post<Assignment>(
      ApiPaths.completeAssignment(assignmentId),
      parse: (data) => Assignment.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Başvuruyu kabul eder.
  ///
  /// Kabul edilen başvuru sunucuda bir **atamaya** dönüşüyor ve atama
  /// `PENDING_CONFIRMATION` ile başlıyor: iş, çalışan onaylayana kadar
  /// başlamış sayılmıyor.
  Future<void> acceptApplication(String applicationId) {
    return _respond(applicationId, ApplicationStatus.accepted);
  }

  /// Başvuruyu reddeder. [reason] çalışanın gördüğü gerekçe.
  Future<void> rejectApplication(String applicationId, {String? reason}) {
    return _respond(
      applicationId,
      ApplicationStatus.rejected,
      rejectionReason: reason,
    );
  }

  /// Yanıtlanmış bir başvuru ikinci kez yanıtlanamıyor; uç 400 döndürüyor ve
  /// mesajı doğrudan kullanıcıya gösterilebilir.
  Future<void> _respond(
    String applicationId,
    ApplicationStatus status, {
    String? rejectionReason,
  }) {
    return _apiClient.postWithoutData(
      ApiPaths.respondToApplication(applicationId),
      body: {'status': status.code, 'rejectionReason': ?rejectionReason},
    );
  }
}
