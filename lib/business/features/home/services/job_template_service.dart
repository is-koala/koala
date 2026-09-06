import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/job_template.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İşverenin ilan şablonlarının gerçek backend kapısı.
///
/// Sunucu yalnızca oluştur / oku / sil sunuyor; şablonu düzenleme ucu yok.
/// Şablonu değiştirmek "sil + yeni ilandan yeniden çıkar" demek.
class JobTemplateService {
  JobTemplateService._(this._apiClient);

  static final JobTemplateService _instance = JobTemplateService._(ApiClient());

  factory JobTemplateService() => _instance;

  @visibleForTesting
  factory JobTemplateService.withClient(ApiClient apiClient) {
    return JobTemplateService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Oturum sahibinin şablonları, en yenisi başta.
  ///
  /// Uç sayfalama yapmıyor: yanıt düz bir dizi.
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

  /// Var olan bir ilandan şablon çıkarır.
  ///
  /// Gövdede yalnızca bu iki alan var; başlık, kategori, ücret gibi alanları
  /// sunucu ilandan kopyalıyor. Adres, tarih ve durum kopyalanmıyor.
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

  /// Şablonu siler. Sahibi olmayana `404` dönüyor.
  Future<void> deleteTemplate(String templateId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserJobTemplate(templateId),
    );
  }
}
