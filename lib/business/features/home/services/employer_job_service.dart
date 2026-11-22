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

/// İşveren ilan ve atama uçları: ilan açar, kapatır, başvuruları yanıtlar.
class EmployerJobService {
  EmployerJobService._(this._apiClient);

  static final EmployerJobService _instance = EmployerJobService._(ApiClient());

  factory EmployerJobService() => _instance;

  @visibleForTesting
  factory EmployerJobService.withClient(ApiClient apiClient) {
    return EmployerJobService._(apiClient);
  }

  final ApiClient _apiClient;

  /// CONFIRMED atama için Iyzico ödeme oturumu başlatır.
  Future<BPaymentSession> createPaymentSession(String assignmentId) {
    return _apiClient.post<BPaymentSession>(
      ApiPaths.assignmentPaymentSession(assignmentId),
      parse: (data) => BPaymentSession.fromJson(data! as Map<String, dynamic>),
    );
  }

  static const int defaultPageSize = 50;

  /// Bireysel ve şirket ilanları birlikte; backend `creatorId`'ye bakıyor.
  Future<JobPage> fetchMyJobs({int page = 0, int size = defaultPageSize}) {
    return _apiClient.get<JobPage>(
      ApiPaths.myJobs,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => JobPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// [companyId] doluysa şirket adına, boşsa bireysel ilan.
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

  /// İlan geçerli kalır, yeni başvuru durur.
  Future<void> closeJob(String jobId) {
    return _apiClient.postWithoutData(ApiPaths.closeJob(jobId));
  }

  /// İptal: ilan geçersiz olur ve başvuranlara bildirim gider; kayıt silinmez.
  /// Devam eden atama varsa `409`: iptal emanetteki parayı dolanan ikinci yol
  /// olurdu, atamanın kendi iptal akışı kullanılmalı.
  Future<void> cancelJob(String jobId) {
    return _apiClient.postWithoutData(ApiPaths.cancelJob(jobId));
  }

  /// Yalnız ilan sahibi; sayfasız.
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

  /// İşverenin atamaları (`asEmployer`). Tek ilan için asıl yol
  /// [fetchJobAssignments]; bu, o ucu tanımayan eski sunucudaki tarama.
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

  /// İlanın atamaları; yalnız sahibi ya da yetkilisi, başkası `404`.
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

  static const String _endpointNotFoundCode = 'ENDPOINT_NOT_FOUND';

  /// İlanın bütün atamaları, sayfa sınırından bağımsız: ödeme gibi işlemlerde
  /// ilk sayfadan rastgele kayıt seçmek güvenli değil. Uç tanınmıyorsa
  /// (`ENDPOINT_NOT_FOUND`) işverenin atamaları taranır; diğer hatalar
  /// yükselir.
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

  /// İşi tamamlar; emanetteki para çıkışa hazırlanır, geri alınamaz.
  /// `CONFIRMED`/`IN_PROGRESS` dışında `409`. İşveren yapmazsa sunucu belirli
  /// gün sonra kendisi tamamlar.
  Future<Assignment> completeAssignment(String assignmentId) {
    return _apiClient.post<Assignment>(
      ApiPaths.completeAssignment(assignmentId),
      parse: (data) => Assignment.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Sigorta bildirimi için çalışanın kimliğini açar. Yalnız işveren ve
  /// `CONFIRMED|IN_PROGRESS|COMPLETED`; doğrulanmamışsa `409`, bütçe dolduysa
  /// `429`. Her okuma kayda geçer ve çalışana bildirilir; çağıran önce onay
  /// alır, yanıtı önbelleğe ya da günlüğe yazmaz.
  Future<WorkerIdentity> fetchWorkerIdentity(String assignmentId) {
    return _apiClient.get<WorkerIdentity>(
      ApiPaths.assignmentWorkerIdentity(assignmentId),
      parse: (data) => WorkerIdentity.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Kabul, `PENDING_CONFIRMATION` bir atama açar; iş çalışan onaylayınca
  /// başlar.
  Future<void> acceptApplication(String applicationId) {
    return _respond(applicationId, ApplicationStatus.accepted);
  }

  /// [reason] çalışanın gördüğü gerekçe.
  Future<void> rejectApplication(String applicationId, {String? reason}) {
    return _respond(
      applicationId,
      ApplicationStatus.rejected,
      rejectionReason: reason,
    );
  }

  /// Yanıtlanmış başvuru ikinci kez yanıtlanamaz (`400`).
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
