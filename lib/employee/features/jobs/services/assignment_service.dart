import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/utils/coordinate_precision.dart';

/// Atama uçları. Mesai, iptal ve uyuşmazlığı iki taraf da kullanıyor; yalnız
/// [checkIn], [checkOut] ve [respond] çalışana özel.
class AssignmentService {
  AssignmentService._(this._apiClient);

  static final AssignmentService _instance = AssignmentService._(ApiClient());

  factory AssignmentService() => _instance;

  @visibleForTesting
  factory AssignmentService.withClient(ApiClient apiClient) {
    return AssignmentService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<AssignmentPage> fetchMyAssignments({int page = 0, int size = 20}) {
    return _apiClient.get<AssignmentPage>(
      ApiPaths.myAssignments,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => AssignmentPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Yalnız taraflara açık (başkası `404`); iki taraf da kullanıyor.
  Future<Assignment> fetchAssignment(String assignmentId) {
    return _apiClient.get<Assignment>(
      ApiPaths.jobAssignment(assignmentId),
      parse: (data) => Assignment.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Mesai başlatır. Konum isteğe bağlı, alınamazsa giriş engellenmez. `409`:
  /// atama açık değil, para emanette değil ya da açık oturum var.
  Future<WorkSession> checkIn({
    required String assignmentId,
    double? latitude,
    double? longitude,
    String? clientEventId,
    DateTime? capturedAt,
  }) {
    return _apiClient.post<WorkSession>(
      ApiPaths.assignmentCheckIn(assignmentId),
      body: _checkPointBody(
        latitude: latitude,
        longitude: longitude,
        clientEventId: clientEventId,
        capturedAt: capturedAt,
      ),
      parse: (data) => WorkSession.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Açık oturumu kapatır; dakikayı sunucu yazar. Açık oturum yoksa `409`.
  Future<WorkSession> checkOut({
    required String assignmentId,
    double? latitude,
    double? longitude,
    String? clientEventId,
    DateTime? capturedAt,
  }) {
    return _apiClient.post<WorkSession>(
      ApiPaths.assignmentCheckOut(assignmentId),
      body: _checkPointBody(
        latitude: latitude,
        longitude: longitude,
        clientEventId: clientEventId,
        capturedAt: capturedAt,
      ),
      parse: (data) => WorkSession.fromJson(data! as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> _checkPointBody({
    required double? latitude,
    required double? longitude,
    required String? clientEventId,
    required DateTime? capturedAt,
  }) {
    if ((clientEventId == null) != (capturedAt == null)) {
      throw ArgumentError('clientEventId ve capturedAt birlikte verilmelidir.');
    }

    // Altı ondalık: sunucu o kesinlikte saklıyor, kuyruk eşleştirmesi de buna
    // bakıyor.
    return {
      'latitude': ?_rounded(latitude),
      'longitude': ?_rounded(longitude),
      'clientEventId': ?clientEventId,
      'capturedAt': ?capturedAt?.toUtc().toIso8601String(),
    };
  }

  static double? _rounded(double? coordinate) =>
      coordinate == null ? null : CoordinatePrecision.round6(coordinate);

  /// İki taraf da okuyor.
  Future<List<WorkSession>> fetchWorkSessions(String assignmentId) {
    return _apiClient.get<List<WorkSession>>(
      ApiPaths.assignmentWorkSessions(assignmentId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(WorkSession.fromJson)
                .toList()
          : const [],
    );
  }

  /// İptal eder. Çalışan iptalinde kesinti yok, işverende süreye göre olabilir;
  /// önceden görmek için [fetchCancellationPreview]. [reason] zorunlu; uygun
  /// olmayan durumda ya da ikinci kez `409`.
  Future<Cancellation> cancel({
    required String assignmentId,
    required String reason,
  }) {
    return _apiClient.post<Cancellation>(
      ApiPaths.cancelAssignment(assignmentId),
      body: {'reason': reason},
      parse: (data) => Cancellation.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İptal etmeden kesintiyi döndürür; çağıranın tarafına göre hesaplanır.
  /// Kapalıysa `cancellableNow: false`.
  Future<CancellationPreview> fetchCancellationPreview(String assignmentId) {
    return _apiClient.get<CancellationPreview>(
      ApiPaths.assignmentCancellationPreview(assignmentId),
      parse: (data) =>
          CancellationPreview.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İptal edilmemişse `null`.
  Future<Cancellation?> fetchCancellation(String assignmentId) {
    return _apiClient.get<Cancellation?>(
      ApiPaths.assignmentCancellation(assignmentId),
      parse: (data) =>
          data is Map<String, dynamic> ? Cancellation.fromJson(data) : null,
    );
  }

  /// Uyuşmazlık açar; yalnız para emanetteyken, parayı dondurur. [reason]
  /// zorunlu (≤2000). Emanet yoksa ya da açık uyuşmazlık varsa `409`.
  Future<Dispute> openDispute({
    required String assignmentId,
    required String reason,
  }) {
    return _apiClient.post<Dispute>(
      ApiPaths.assignmentDisputes(assignmentId),
      body: {'reason': reason},
      parse: (data) => Dispute.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<List<Dispute>> fetchDisputes(String assignmentId) {
    return _apiClient.get<List<Dispute>>(
      ApiPaths.assignmentDisputes(assignmentId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(Dispute.fromJson)
                .toList()
          : const [],
    );
  }

  /// Atamayı kabul/ret eder. Yalnız `PENDING_CONFIRMATION`'da (`409`), taraf
  /// değilse `404`. Yanıt ödeme alanlarını taşımadığı için yalnız durum okunur,
  /// liste yeniden çekilir.
  Future<AssignmentStatus> respond({
    required String assignmentId,
    required bool accepted,
  }) {
    return _apiClient.post<AssignmentStatus>(
      ApiPaths.respondToAssignment(assignmentId),
      body: {'accepted': accepted},
      parse: (data) =>
          AssignmentStatus.fromCode((data as Map<String, dynamic>?)?['status']),
    );
  }
}
