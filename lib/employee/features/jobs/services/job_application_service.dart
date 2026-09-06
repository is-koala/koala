import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Başvuru uçları.
///
/// Gönderme ilan üzerinden (`POST /jobs/{jobId}/applications`), listeleme
/// kullanıcı üzerinden (`GET /users/me/applications`) yapılıyor — backend'in
/// böldüğü yer burası.
///
/// Başvuru kabul edildiğinde iş bir atamaya dönüşüyor; oradan sonrası
/// `AssignmentService`'in işi. "İşlerim" ekranı iki servisi birden okuyor.
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

  /// Başvuruyu geri çeker.
  ///
  /// Uç `JobApplicationDetailDto` döndürüyor, o yüzden `postWithoutData` değil
  /// `post` + `parse`: dönen kaydın **durumu** sunucunun son sözü ve liste
  /// yeniden çekilmeden kullanılabiliyor.
  ///
  /// ⚠️ Dönen kaydın `job` alanı `ShortJobDto` — yalnızca id ve başlık.
  /// `MyApplicationDto`'nun taşıdığı ücret, şirket ve kategori burada **yok**,
  /// bu yüzden çağıran taraf kaydı olduğu gibi listedekinin yerine koymamalı;
  /// bkz. [ApplyProvider.withdraw].
  ///
  /// Sunucu yalnızca `APPLIED` durumundan geçiriyor: başkasının başvurusu
  /// `404` (`JOB_APPLICATION_NOT_FOUND`), yanıtlanmış ya da zaten geri
  /// çekilmiş başvuru `409` (`JOB_APPLICATION_NOT_WITHDRAWABLE`).
  Future<JobApplication> withdraw(String applicationId) {
    return _apiClient.post<JobApplication>(
      ApiPaths.withdrawApplication(applicationId),
      parse: (data) => JobApplication.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Kullanıcının başvuruları, yeniden eskiye.
  ///
  /// [ApplicationStatus.unknown] bir süzgeç değeri değil, istemcinin
  /// sentineli: sunucunun enum'unda karşılığı yok ve gönderilseydi `400`
  /// gelirdi. O yüzden süzgeçsiz çağrı sayılıyor.
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
