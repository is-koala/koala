import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İş kategorilerinin kaynağı; iki arayüz de kullanıyor.
class JobCategoryService {
  JobCategoryService._(this._apiClient);

  static final JobCategoryService _instance = JobCategoryService._(ApiClient());

  factory JobCategoryService() => _instance;

  @visibleForTesting
  factory JobCategoryService.withClient(ApiClient apiClient) {
    return JobCategoryService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Token istemiyor. Boş liste hata değil; çağıran "kategori yok"u ayrıca ele
  /// almalı.
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
