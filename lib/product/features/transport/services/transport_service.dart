import 'package:flutter/foundation.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/models/transport_plan_write.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Ulaşım planı uçları (koala-backend#297, 0.9.28).
///
/// İki kabuk da kullanıyor: işveren planı yazıp okuyor, işçi atamasının
/// görünümünü okuyup koltuk seçiyor. İşveren de işçi adına koltuk
/// seçebiliyor; ucun yetkisini sunucu ayırt ediyor.
class TransportService {
  TransportService._(this._apiClient);

  static final TransportService _instance = TransportService._(ApiClient());

  factory TransportService() => _instance;

  @visibleForTesting
  factory TransportService.withClient(ApiClient apiClient) {
    return TransportService._(apiClient);
  }

  final ApiClient _apiClient;

  /// İlanın planı, işveren görünümü. Plan yoksa `404`
  /// `TRANSPORT_PLAN_NOT_FOUND`; çağıran onu "henüz plan yok" okur.
  Future<TransportPlan> fetchPlan(String jobId) {
    return _apiClient.get<TransportPlan>(
      ApiPaths.jobTransportPlan(jobId),
      parse: (data) => TransportPlan.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Planı bütünüyle yazar ve sunucudaki yeni hâlini döndürür.
  Future<TransportPlan> savePlan(String jobId, TransportPlanWrite plan) {
    return _apiClient.put<TransportPlan>(
      ApiPaths.jobTransportPlan(jobId),
      body: plan.toJson(),
      parse: (data) => TransportPlan.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Atamanın ulaşım görünümü: plan + servisler + bu atamanın koltukları.
  Future<AssignmentTransport> fetchAssignmentTransport(String assignmentId) {
    return _apiClient.get<AssignmentTransport>(
      ApiPaths.assignmentTransport(assignmentId),
      parse: (data) =>
          AssignmentTransport.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Koltuk seçer; yön servisten türüyor ve o yöndeki önceki seçimin yerine
  /// geçiyor. Güncel görünüm dönüyor.
  Future<AssignmentTransport> selectSeat(
    String assignmentId, {
    required String shuttleId,
    required String stopId,
  }) {
    return _apiClient.put<AssignmentTransport>(
      ApiPaths.assignmentTransportSeat(assignmentId),
      body: {'shuttleId': shuttleId, 'stopId': stopId},
      parse: (data) =>
          AssignmentTransport.fromJson(data! as Map<String, dynamic>),
    );
  }
}
