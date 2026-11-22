import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Başvuru uçları; kabulden sonrası `AssignmentService`'in.
class JobApplicationService {
  JobApplicationService._(this._apiClient);

  static final JobApplicationService _instance = JobApplicationService._(
    ApiClient(),
  );

  factory JobApplicationService() => _instance;

  @visibleForTesting
  factory JobApplicationService.withClient(ApiClient apiClient) {
    return JobApplicationService._(apiClient);
  }

  final ApiClient _apiClient;

  /// [notes] ≤2000. Aynı ilana ikinci başvuru hata döner.
  Future<JobApplication> apply({required String jobId, String? notes}) {
    return _apiClient.post<JobApplication>(
      ApiPaths.jobApplications(jobId),
      body: {'notes': ?notes},
      parse: (data) => JobApplication.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Geri çeker. Dönen kaydın **durumu** sunucunun son sözü.
  ///
  /// ⚠️ Dönen `job` `ShortJobDto` (yalnız id ve başlık); kayıt listedekinin
  /// yerine konmamalı. Başkasının başvurusu `404`, yanıtlanmış ya da geri
  /// çekilmiş `409`.
  Future<JobApplication> withdraw(String applicationId) {
    return _apiClient.post<JobApplication>(
      ApiPaths.withdrawApplication(applicationId),
      parse: (data) => JobApplication.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// [ApplicationStatus.unknown] istemci sentineli; sunucuya gitse `400`, o
  /// yüzden süzgeçsiz sayılır.
  Future<JobApplicationPage> fetchMyApplications({
    ApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) {
    final filter = status == ApplicationStatus.unknown ? null : status;

    return _apiClient.get<JobApplicationPage>(
      ApiPaths.myApplications,
      queryParameters: {'status': ?filter?.code, 'page': page, 'size': size},
      parse: (data) =>
          JobApplicationPage.fromJson(data! as Map<String, dynamic>),
    );
  }
}
