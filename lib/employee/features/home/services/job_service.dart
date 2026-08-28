import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/models/job_page.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İş ilanlarının kaynağı.
///
/// Liste ve detay bilerek ayrı: `GET /jobs` kart ve pin çizmeye yetecek kadarını
/// döndürüyor, açıklama/görevler/adres yalnızca `GET /jobs/{id}`'de var.
class JobService {
  JobService._(this._apiClient);

  static final JobService _instance = JobService._(ApiClient());

  factory JobService() => _instance;

  @visibleForTesting
  factory JobService.withClient(ApiClient apiClient) {
    return JobService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Varsayılan sayfa boyutu; backend'in kendi varsayılanıyla aynı.
  static const int defaultPageSize = 20;

  /// İlan arar.
  ///
  /// [minLatitude] ve arkadaşları haritanın görünen alanını sınırlıyor: harita
  /// sekmesi kamerayı hareket ettirdikçe bu kutuyu güncelliyor. Liste
  /// görünümü kutu göndermiyor, tüm ilanlar üzerinden arıyor.
  ///
  /// Kategori süzgeci kategorinin **id**'siyle çalışıyor, koduyla değil.
  Future<JobPage> search({
    String? query,
    String? categoryId,
    JobType? type,
    double? minLatitude,
    double? maxLatitude,
    double? minLongitude,
    double? maxLongitude,
    int page = 0,
    int size = defaultPageSize,
  }) {
    return _apiClient.get<JobPage>(
      ApiPaths.jobs,
      queryParameters: {
        'query': ?query,
        'categoryId': ?categoryId,
        'type': ?type?.code,
        'minLatitude': ?minLatitude,
        'maxLatitude': ?maxLatitude,
        'minLongitude': ?minLongitude,
        'maxLongitude': ?maxLongitude,
        'page': page,
        'size': size,
      },
      parse: (data) => JobPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Tek bir ilanın tam hâli.
  Future<JobDetail> getById(String jobId) {
    return _apiClient.get<JobDetail>(
      ApiPaths.job(jobId),
      parse: (data) => JobDetail.fromJson(data! as Map<String, dynamic>),
    );
  }
}
