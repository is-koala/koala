import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Kaydedilen ilanlar.
///
/// Liste sayfalı değil: backend `List<JobSummaryDto>` döndürüyor.
class SavedJobsService {
  SavedJobsService._(this._apiClient);

  static final SavedJobsService _instance = SavedJobsService._(ApiClient());

  factory SavedJobsService() => _instance;

  @visibleForTesting
  factory SavedJobsService.withClient(ApiClient apiClient) {
    return SavedJobsService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<List<Job>> fetchSavedJobs() {
    return _apiClient.get<List<Job>>(
      ApiPaths.savedJobs,
      parse: (data) => data is List
          ? data.whereType<Map<String, dynamic>>().map(Job.fromJson).toList()
          : const [],
    );
  }

  /// İlanı kaydeder. Zaten kayıtlıysa backend yine başarı dönüyor.
  Future<void> save(String jobId) {
    return _apiClient.postWithoutData(ApiPaths.savedJob(jobId));
  }

  Future<void> remove(String jobId) {
    return _apiClient.deleteWithoutData(ApiPaths.savedJob(jobId));
  }
}
