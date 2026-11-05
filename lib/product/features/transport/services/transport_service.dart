import 'package:flutter/foundation.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/models/transport_plan_write.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/utils/coordinate_precision.dart';

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

  // ── Biniş teyidi (is-koala/koala#217, koala-backend#298) ────────────────
  //
  // Token'lar sunucunun imzalı HMAC'leri: istemci onları üretmiyor, yalnız
  // sunucudan aldığını QR'a basıyor ya da okuttuğunu aynen geri yolluyor.

  /// Servisin QR'ı (işveren). [isStatic] kâğıda basılabilen süresiz QR.
  Future<BoardingQr> fetchShuttleQr(String shuttleId, {bool isStatic = false}) {
    return _apiClient.get<BoardingQr>(
      ApiPaths.shuttleQr(shuttleId),
      queryParameters: {'static': isStatic},
      parse: (data) => BoardingQr.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Servis QR anahtarını yeniler; basılı QR dahil eskilerin hepsi
  /// geçersizleşir. Yeni dönen QR döner.
  Future<BoardingQr> rotateShuttleQr(String shuttleId) {
    return _apiClient.post<BoardingQr>(
      ApiPaths.shuttleQrRotate(shuttleId),
      parse: (data) => BoardingQr.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İşçinin o yöndeki koltuğunun QR'ı (işçi).
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

  /// İşçi servisin QR'ını okuttu. [capturedAt] okutma anı (UTC); konum
  /// yalnız izin zaten verilmişse ve ikisi birlikte gider. Aynı
  /// [clientEventId] ile yeniden deneme güvenli: sunucu kayıtlı olayı
  /// `replayed=true` ile döndürür.
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

  /// İşveren koltuğa biniş yazar: [token] verilirse işçinin QR'ı okutuldu
  /// (yalnız BOARDED, [capturedAt] zorunlu), verilmezse listeden [kind]
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

  /// Servisin biniş listesi (işveren).
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

  /// İki POST'un ortak gövdesi. Konum yarımsa hiç gönderilmiyor: sunucu
  /// ikisini birlikte istiyor (`TRANSPORT_BOARDING_POSITION_PAIR`).
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
