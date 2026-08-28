import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Başvuru uçları.
///
/// Gönderme ilan üzerinden (`POST /jobs/{jobId}/applications`), listeleme
/// kullanıcı üzerinden (`GET /users/me/applications`) yapılıyor — backend'in
/// böldüğü yer burası.
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

  /// Bir ilana başvurur.
  ///
  /// [notes] başvuru ekranındaki ön yazı; backend en fazla 2000 karakter
  /// kabul ediyor. Aynı ilana ikinci kez başvurulursa uç hata döndürüyor,
  /// çağıran tarafın onu kullanıcıya göstermesi gerekiyor.
  Future<JobApplication> apply({required String jobId, String? notes}) {
    return _apiClient.post<JobApplication>(
      ApiPaths.jobApplications(jobId),
      body: {'notes': ?notes},
      parse: (data) => JobApplication.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Kullanıcının başvuruları, yeniden eskiye.
  Future<JobApplicationPage> fetchMyApplications({
    ApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<JobApplicationPage>(
      ApiPaths.myApplications,
      queryParameters: {'status': ?status?.code, 'page': page, 'size': size},
      parse: (data) =>
          JobApplicationPage.fromJson(data! as Map<String, dynamic>),
    );
  }
}
