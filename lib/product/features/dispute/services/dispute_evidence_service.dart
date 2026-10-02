import 'package:flutter/foundation.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Gönderim ilerlemesi: kaç bayt gitti, toplam kaç bayt.
typedef EvidenceUploadProgress = void Function(int sent, int total);

/// `/disputes/{id}/evidence` uçlarının sarmalayıcısı (is-koala/koala#215).
///
/// Çalışan da işveren de aynı ucu kullanıyor: sunucu kimin atamanın tarafı
/// olduğuna bakıyor, taraf olmayana `404`. İki uygulamanın da kullandığı için
/// `product/` altında.
class DisputeEvidenceService {
  DisputeEvidenceService._(this._apiClient);

  static final DisputeEvidenceService _instance = DisputeEvidenceService._(
    ApiClient(),
  );

  factory DisputeEvidenceService() => _instance;

  @visibleForTesting
  factory DisputeEvidenceService.withClient(ApiClient apiClient) {
    return DisputeEvidenceService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Bir uyuşmazlığın kanıtları, eskiden yeniye.
  ///
  /// Yalnız metadata; dizi sayfalanmıyor (üst sınır 5). Çözülmüş
  /// uyuşmazlığın kanıtları da okunuyor — karar sonrası dosyayı görmek
  /// meşru.
  Future<List<DisputeEvidence>> fetchEvidence(String disputeId) {
    return _apiClient.get<List<DisputeEvidence>>(
      ApiPaths.disputeEvidence(disputeId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(DisputeEvidence.fromJson)
                .toList()
          : const [],
    );
  }

  /// Tek dosya yükler, kaydı döner.
  ///
  /// `multipart/form-data`, parça adı **`file`**; istek başına bir dosya.
  /// Parçanın adı ve içerik tipi dosyanın **içeriğinden** ([EvidenceFile]):
  /// sunucu uzantıya bakıyor, seçicinin verdiği ad ise gerçeği
  /// yansıtmayabiliyor. [onProgress] gönderilen bayt sayısını veriyor.
  Future<DisputeEvidence> upload(
    String disputeId,
    EvidenceFile file, {
    EvidenceUploadProgress? onProgress,
  }) {
    return _apiClient.postUploadFile<DisputeEvidence>(
      ApiPaths.disputeEvidence(disputeId),
      fieldName: 'file',
      file: UploadFile(
        file.path,
        filename: file.uploadName,
        contentType: file.format.mimeType,
      ),
      onSendProgress: onProgress,
      parse: (data) => DisputeEvidence.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Kanıtın indirileceği kısa ömürlü adres.
  ///
  /// İndirme ucu `Bearer` ister ve depoya `302` verir; yönlendirme izlenmiyor
  /// ([ApiClient.getRedirectLocation]), imzalı adres olduğu gibi dönüyor ve
  /// **üç dakika** geçerli — hemen açılmalı, saklanmamalı. Sunucu imza
  /// yapamayıp baytları akıtıyorsa `null`.
  Future<Uri?> resolveDownload(String disputeId, String evidenceId) {
    return _apiClient.getRedirectLocation(
      ApiPaths.disputeEvidenceDownload(disputeId, evidenceId),
    );
  }
}
