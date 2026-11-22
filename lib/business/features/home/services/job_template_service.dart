import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/job_template.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İlan şablonu uçları; düzenleme yok, değiştirmek "sil + yeniden çıkar".
class JobTemplateService {
  JobTemplateService._(this._apiClient);

  static final JobTemplateService _instance = JobTemplateService._(ApiClient());

  factory JobTemplateService() => _instance;

  @visibleForTesting
  factory JobTemplateService.withClient(ApiClient apiClient) {
    return JobTemplateService._(apiClient);
  }

  final ApiClient _apiClient;

  /// En yeni başta; sayfasız.
  Future<List<JobTemplate>> fetchTemplates() {
    return _apiClient.get<List<JobTemplate>>(
      ApiPaths.currentUserJobTemplates,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(JobTemplate.fromJson)
                .toList()
          : const [],
    );
  }

  /// Var olan ilandan şablon çıkarır; alanları sunucu kopyalar.
  Future<JobTemplate> createFromJob({
    required String jobId,
    required String templateName,
  }) {
    return _apiClient.post<JobTemplate>(
      ApiPaths.currentUserJobTemplates,
      body: {'templateName': templateName, 'jobId': jobId},
      parse: (data) => JobTemplate.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Sahibi olmayana `404`.
  Future<void> deleteTemplate(String templateId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserJobTemplate(templateId),
    );
  }
}
