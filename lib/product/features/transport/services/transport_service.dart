import 'package:flutter/foundation.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/models/transport_plan_write.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/utils/coordinate_precision.dart';

/// Ulaşım uçları; iki kabuk kullanıyor, yetkiyi sunucu ayırıyor.
class TransportService {
  TransportService._(this._apiClient);

  static final TransportService _instance = TransportService._(ApiClient());

  factory TransportService() => _instance;

  @visibleForTesting
  factory TransportService.withClient(ApiClient apiClient) {
    return TransportService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Plan yoksa `404 TRANSPORT_PLAN_NOT_FOUND`: "henüz plan yok".
  Future<TransportPlan> fetchPlan(String jobId) {
    return _apiClient.get<TransportPlan>(
      ApiPaths.jobTransportPlan(jobId),
      parse: (data) => TransportPlan.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<TransportPlan> savePlan(String jobId, TransportPlanWrite plan) {
    return _apiClient.put<TransportPlan>(
      ApiPaths.jobTransportPlan(jobId),
      body: plan.toJson(),
      parse: (data) => TransportPlan.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<AssignmentTransport> fetchAssignmentTransport(String assignmentId) {
    return _apiClient.get<AssignmentTransport>(
      ApiPaths.assignmentTransport(assignmentId),
      parse: (data) =>
          AssignmentTransport.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Koltuk seçer; o yöndeki önceki seçimin yerine geçer.
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

  // ── Biniş teyidi (#217) ── Token'ları istemci üretmiyor; sunucudan aldığını
  // basıyor ya da okuttuğunu geri yolluyor.

  /// [isStatic] basılabilen süresiz QR.
  Future<BoardingQr> fetchShuttleQr(String shuttleId, {bool isStatic = false}) {
    return _apiClient.get<BoardingQr>(
      ApiPaths.shuttleQr(shuttleId),
      queryParameters: {'static': isStatic},
      parse: (data) => BoardingQr.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Basılı QR dahil eskilerin hepsi geçersizleşir.
  Future<BoardingQr> rotateShuttleQr(String shuttleId) {
    return _apiClient.post<BoardingQr>(
      ApiPaths.shuttleQrRotate(shuttleId),
      parse: (data) => BoardingQr.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<BoardingQr> fetchWorkerQr(
    String assignmentId, {
    required ShuttleDirection direction,
  }) {
    return _apiClient.get<BoardingQr>(
      ApiPaths.assignmentTransportQr(assignmentId),
      queryParameters: {'direction': direction.code},
      parse: (data) => BoardingQr.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İşçi servisin QR'ını okuttu. Konum yalnız izin zaten varsa gider. Aynı
  /// [clientEventId] ile yeniden deneme güvenli.
  Future<BoardingEvent> boardOnShuttle(
    String shuttleId, {
    required String token,
    required DateTime capturedAt,
    required String clientEventId,
    double? latitude,
    double? longitude,
  }) {
    return _apiClient.post<BoardingEvent>(
      ApiPaths.shuttleBoardings(shuttleId),
      body: _boardingBody(
        token: token,
        capturedAt: capturedAt,
        clientEventId: clientEventId,
        latitude: latitude,
        longitude: longitude,
      ),
      parse: (data) => BoardingEvent.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// [token] varsa işçi QR'ı okutuldu (yalnız BOARDED), yoksa listeden [kind]
  /// işareti.
  Future<BoardingEvent> markSeatBoarding(
    String seatAssignmentId, {
    required String clientEventId,
    String? token,
    DateTime? capturedAt,
    BoardingKind? kind,
    double? latitude,
    double? longitude,
  }) {
    assert(
      token == null || (capturedAt != null && kind != BoardingKind.noShow),
      'QR okutmada capturedAt zorunlu ve tür yalnız BOARDED olabilir.',
    );
    return _apiClient.post<BoardingEvent>(
      ApiPaths.seatBoardings(seatAssignmentId),
      body: {
        ..._boardingBody(
          token: token,
          capturedAt: capturedAt,
          clientEventId: clientEventId,
          latitude: latitude,
          longitude: longitude,
        ),
        'kind': ?kind?.code,
      },
      parse: (data) => BoardingEvent.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<List<ShuttleBoardingRow>> fetchShuttleBoardings(String shuttleId) {
    return _apiClient.get<List<ShuttleBoardingRow>>(
      ApiPaths.shuttleBoardings(shuttleId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(ShuttleBoardingRow.fromJson)
                .toList()
          : const [],
    );
  }

  /// Konum yarımsa hiç gönderilmez: sunucu ikisini birlikte istiyor.
  static Map<String, Object?> _boardingBody({
    required String clientEventId,
    String? token,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
  }) {
    return {
      'token': ?token,
      if (capturedAt != null)
        'capturedAt': capturedAt.toUtc().toIso8601String(),
      if (latitude != null && longitude != null) ...{
        'latitude': CoordinatePrecision.round6(latitude),
        'longitude': CoordinatePrecision.round6(longitude),
      },
      'clientEventId': clientEventId,
    };
  }
}
