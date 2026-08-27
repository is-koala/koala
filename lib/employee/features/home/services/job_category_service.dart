import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İş kategorilerinin kaynağı.
///
/// Kategoriler artık uygulamada sabit değil; ilan oluşturma ekranındaki seçici
/// de keşfetteki filtre de bu listeden çiziliyor. İş veren tarafı da aynı
/// listeyi kullandığı için servis `employee/features/home` altında duruyor ama
/// iki arayüzü birden besliyor — sohbet widget'larındaki paylaşımın aynısı.
class JobCategoryService {
  JobCategoryService._(this._apiClient);

  static final JobCategoryService _instance = JobCategoryService._(ApiClient());

  factory JobCategoryService() => _instance;

  @visibleForTesting
  factory JobCategoryService.withClient(ApiClient apiClient) {
    return JobCategoryService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Yürürlükteki kategoriler. Token istemiyor.
  ///
  /// Backend bugün boş liste döndürüyor — `job_categories` tablosunda henüz
  /// seed verisi yok. Boş liste hata değil, o yüzden çağıranın "kategori yok"
  /// durumunu ayrıca ele alması gerekiyor.
  Future<List<JobCategory>> fetchCategories() {
    return _apiClient.get<List<JobCategory>>(
      ApiPaths.jobCategories,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(JobCategory.fromJson)
                .toList()
          : const [],
    );
  }
}
