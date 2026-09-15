import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/models/b_payment_session.dart';
import 'package:koala/business/features/home/models/worker_identity.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/models/job_page.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';

/// İşveren ilan ve atama akışlarının uçları.
///
/// Çalışan tarafındaki `JobService` ilan **arıyor**; burası ilan **açıyor,
/// kapatıyor ve başvuruları yanıtlıyor**. Ödeme sonucu gibi işveren
/// ekranlarının ihtiyaç duyduğu katılımcıya açık atama okumaları da burada
/// tutuluyor; her uç kendi sahiplik veya katılımcı yetkisini doğruluyor.
class EmployerJobService {
  EmployerJobService._(this._apiClient);

  static final EmployerJobService _instance = EmployerJobService._(ApiClient());

  factory EmployerJobService() => _instance;

  @visibleForTesting
  factory EmployerJobService.withClient(ApiClient apiClient) {
    return EmployerJobService._(apiClient);
  }

  final ApiClient _apiClient;

  /// CONFIRMED atama için Iyzico Checkout Form oturumu başlatır.
  Future<BPaymentSession> createPaymentSession(String assignmentId) {
    return _apiClient.post<BPaymentSession>(
      ApiPaths.assignmentPaymentSession(assignmentId),
      parse: (data) => BPaymentSession.fromJson(data! as Map<String, dynamic>),
    );
  }

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
  /// Tek ilanın ataması için asıl yol [fetchJobAssignments]; burası o ucu
  /// tanımayan eski sunucuda [fetchAssignmentsForJob]'un düştüğü tarama.
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

  /// Bir ilanın atamaları, `GET /jobs/{jobId}/assignments` (koala-
  /// backend#282). Varsayılan sıralama `assignmentDateTime` azalan.
  ///
  /// Yalnızca ilan sahibi ya da şirket ilanının güncel yetkilisi okuyabiliyor;
  /// başkası ve olmayan ilan aynı `404 JOB_NOT_FOUND` yanıtını alıyor.
  Future<AssignmentPage> fetchJobAssignments(
    String jobId, {
    int page = 0,
    int size = defaultPageSize,
  }) {
    return _apiClient.get<AssignmentPage>(
      ApiPaths.assignmentsOfJob(jobId),
      queryParameters: {'page': page, 'size': size},
      parse: (data) => AssignmentPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Bu ucu tanımayan sunucunun yanıtı. `ErrorResult` kodu boşken kategori
  /// adına düşüyor, `endpoint.not.found` anahtarı da aynı koda türüyor; iki
  /// yoldan da aynı dize geliyor.
  static const String _endpointNotFoundCode = 'ENDPOINT_NOT_FOUND';

  /// [jobId] için tüm atamaları sayfa sınırından bağımsız döndürür.
  ///
  /// Bir ilanda birden fazla çalışan olabilir; ödeme gibi atama-kimliğine
  /// bağlı işlemlerde ilk sayfadaki rastgele bir kaydı seçmek güvenli değildir.
  ///
  /// Önce ilan başına uç deneniyor. Sunucu o ucu tanımıyorsa
  /// (`404 ENDPOINT_NOT_FOUND`) işverenin bütün atamaları taranıp ilana göre
  /// süzülüyor — bu ucun gelmesinden önceki yol. `JOB_NOT_FOUND` dâhil diğer
  /// hatalar olduğu gibi yükseliyor: ilan gerçekten yoksa ya da yetki yoksa
  /// tarama da bir şey bulmaz, hatayı gizlemenin anlamı yok.
  Future<List<Assignment>> fetchAssignmentsForJob(String jobId) async {
    try {
      return await _collectPages(
        (pageNumber) => fetchJobAssignments(jobId, page: pageNumber),
        (_) => true,
      );
    } on ApiException catch (error) {
      if (error.errorCode != _endpointNotFoundCode) rethrow;
    }

    return _collectPages(
      (pageNumber) => fetchMyAssignments(page: pageNumber),
      (assignment) => assignment.job.id == jobId,
    );
  }

  Future<List<Assignment>> _collectPages(
    Future<AssignmentPage> Function(int pageNumber) fetchPage,
    bool Function(Assignment assignment) matches,
  ) async {
    final collected = <Assignment>[];
    var pageNumber = 0;

    while (true) {
      final page = await fetchPage(pageNumber);
      collected.addAll(page.assignments.where(matches));
      if (page.last) return collected;
      pageNumber++;
    }
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

  /// İşe alınan çalışanın kimlik bilgilerini sigorta bildirimi için açar
  /// (`GET /job-assignments/{id}/worker-identity`, koala-backend#312).
  ///
  /// Yalnızca işveren çağırabiliyor; işçi tarafında karşılığı yok. Sunucu
  /// yalnız `CONFIRMED`, `IN_PROGRESS` ve `COMPLETED` atamada yanıt veriyor,
  /// başka durumda ve yetkisiz çağrıda `404`. Çalışan kimliğini
  /// doğrulamadıysa `409 WORKER_IDENTITY_NOT_VERIFIED`, saatlik bütçe
  /// dolduysa `429`. Her başarılı okuma sunucuda kayda geçiyor ve çalışana
  /// bildirim gidiyor — bu yüzden çağıran önce açık onay alıyor.
  ///
  /// Yanıt önbelleğe alınmıyor ve günlüğe yazılmıyor; çağıran bellekte
  /// süreli tutup siliyor.
  Future<WorkerIdentity> fetchWorkerIdentity(String assignmentId) {
    return _apiClient.get<WorkerIdentity>(
      ApiPaths.assignmentWorkerIdentity(assignmentId),
      parse: (data) => WorkerIdentity.fromJson(data! as Map<String, dynamic>),
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
