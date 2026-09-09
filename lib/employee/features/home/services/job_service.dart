import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/models/job_page.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
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
  /// Bütün ölçütler tek bir [JobSearchQuery] içinde geliyor: liste ve harita
  /// sekmeleri aynı tipi kurduğu için ikisi zamanla ayrışamıyor. Sınırlayıcı
  /// kutu da sorgunun bir alanı — haritanın görünen alanı oraya yazılıyor.
  ///
  /// [page] ve [size] sorgunun değil sayfalamanın parçası, o yüzden ayrı
  /// duruyor. Sunucu boyutu **100** ile sınırlıyor; üstü sessizce kırpılmıyor,
  /// 20'ye çekiliyor.
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

  /// Bir şirketin açık ilanlarını bütün sayfalardan toplar.
  ///
  /// Sunucu şirket kimliğini arama sorgusunda süzer; istemci şirket adına
  /// bakmaz. En büyük izinli sayfa boyutuyla başlanır, yine de yüzü aşan
  /// şirketlerde sonraki sayfalar okunur.
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

  /// Tek bir ilanın tam hâli.
  Future<JobDetail> getById(String jobId) {
    return _apiClient.get<JobDetail>(
      ApiPaths.job(jobId),
      parse: (data) => JobDetail.fromJson(data! as Map<String, dynamic>),
    );
  }
}
