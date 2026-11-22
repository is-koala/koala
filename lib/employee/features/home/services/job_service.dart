import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/models/job_page.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İlanlar. Liste kart ve pin için yeterli; açıklama, görevler ve adres yalnız
/// `GET /jobs/{id}`'de.
class JobService {
  JobService._(this._apiClient);

  static final JobService _instance = JobService._(ApiClient());

  factory JobService() => _instance;

  @visibleForTesting
  factory JobService.withClient(ApiClient apiClient) {
    return JobService._(apiClient);
  }

  final ApiClient _apiClient;

  static const int defaultPageSize = 20;

  /// İlan arar; liste ve harita aynı [JobSearchQuery]'yi kuruyor. Sunucu boyutu
  /// 100 ile sınırlıyor; üstü kırpılmaz, 20'ye çekilir.
  Future<JobPage> search(
    JobSearchQuery query, {
    int page = 0,
    int size = defaultPageSize,
  }) {
    return _apiClient.get<JobPage>(
      ApiPaths.jobs,
      queryParameters: {
        ...query.toQueryParameters(),
        'page': page,
        'size': size,
      },
      parse: (data) => JobPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Şirketin açık ilanlarını bütün sayfalardan toplar; süzme şirket kimliğiyle
  /// sunucuda.
  Future<List<Job>> fetchByCompany(String companyId) async {
    const pageSize = 100;
    final jobs = <Job>[];
    var pageNumber = 0;

    while (true) {
      final page = await search(
        JobSearchQuery(companyId: companyId),
        page: pageNumber,
        size: pageSize,
      );
      jobs.addAll(page.jobs);
      if (page.last) return jobs;
      pageNumber++;
    }
  }

  Future<JobDetail> getById(String jobId) {
    return _apiClient.get<JobDetail>(
      ApiPaths.job(jobId),
      parse: (data) => JobDetail.fromJson(data! as Map<String, dynamic>),
    );
  }
}
