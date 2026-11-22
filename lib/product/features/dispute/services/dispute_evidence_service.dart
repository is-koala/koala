import 'package:flutter/foundation.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

typedef EvidenceUploadProgress = void Function(int sent, int total);

/// `/disputes/{id}/evidence` uçları (#215); taraf olmayana `404`.
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

  /// Kanıtlar, eskiden yeniye; yalnız metadata, sayfasız (en çok 5).
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

  /// Tek dosya yükler; parça adı **`file`**, ad ve tip içerikten
  /// ([EvidenceFile]).
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

  /// İndirme adresi. Yönlendirme izlenmiyor ([ApiClient.getRedirectLocation]);
  /// imzalı adres **üç dakika** geçerli. Sunucu baytları akıtıyorsa `null`.
  Future<Uri?> resolveDownload(String disputeId, String evidenceId) {
    return _apiClient.getRedirectLocation(
      ApiPaths.disputeEvidenceDownload(disputeId, evidenceId),
    );
  }
}
