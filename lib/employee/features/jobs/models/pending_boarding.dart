import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';

enum PendingBoardingStatus {
  /// Bağlantı gelince yeniden denenir.
  pending('PENDING'),

  /// Sunucu reddetti; işçiye "işverenden işaretlemesini iste" denir. Yeniden
  /// denenmez.
  failed('FAILED');

  const PendingBoardingStatus(this.code);

  final String code;

  static PendingBoardingStatus fromCode(Object? value) =>
      values.where((status) => status.code == value).firstOrNull ?? pending;
}

/// Sunucuya henüz ulaşmamış biniş okutması (#217).
///
/// Token okutma anında geçerliyse sunucu 12 saate kadar `LATE_SYNC` ile kabul
/// ediyor; aynı [clientEventId] ile deneme kayıtlı olayı döndürüyor. Gövde bir
/// kez kurulup aynen saklanıyor, yoksa `IDEMPOTENCY_CONFLICT`. [toString]
/// token'ı içermez.
class PendingBoarding {
  const PendingBoarding({
    required this.clientEventId,
    required this.userId,
    required this.shuttleId,
    required this.token,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.assignmentId,
    this.direction,
    this.status = PendingBoardingStatus.pending,
    this.failure,
  });

  final String clientEventId;
  final String userId;

  final String shuttleId;
  final String token;

  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;

  /// İş detayından okutulduysa; telefon kamerasıyla açılan bağlantıda yok.
  final String? assignmentId;
  final ShuttleDirection? direction;

  final PendingBoardingStatus status;

  final BoardingFailure? failure;

  bool get isFailed => status == PendingBoardingStatus.failed;

  PendingBoarding asFailed(BoardingFailure failure) => PendingBoarding(
    clientEventId: clientEventId,
    userId: userId,
    shuttleId: shuttleId,
    token: token,
    capturedAt: capturedAt,
    latitude: latitude,
    longitude: longitude,
    assignmentId: assignmentId,
    direction: direction,
    status: PendingBoardingStatus.failed,
    failure: failure,
  );

  Map<String, Object?> toJson() => {
    'clientEventId': clientEventId,
    'userId': userId,
    'shuttleId': shuttleId,
    'token': token,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'assignmentId': assignmentId,
    'direction': direction?.code,
    'status': status.code,
    'failure': failure?.name,
  };

  /// Bozuk satır kuyruğun geri kalanını kilitlemesin.
  static PendingBoarding? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final clientEventId = value['clientEventId'];
    final userId = value['userId'];
    final shuttleId = value['shuttleId'];
    final token = value['token'];
    final capturedAt = value['capturedAt'] is String
        ? DateTime.tryParse(value['capturedAt'] as String)
        : null;
    if (clientEventId is! String ||
        userId is! String ||
        shuttleId is! String ||
        token is! String ||
        capturedAt == null) {
      return null;
    }
    final failureName = value['failure'];
    return PendingBoarding(
      clientEventId: clientEventId,
      userId: userId,
      shuttleId: shuttleId,
      token: token,
      capturedAt: capturedAt.toUtc(),
      latitude: (value['latitude'] as num?)?.toDouble(),
      longitude: (value['longitude'] as num?)?.toDouble(),
      assignmentId: value['assignmentId'] as String?,
      direction: ShuttleDirection.fromCode(value['direction']),
      status: PendingBoardingStatus.fromCode(value['status']),
      failure: BoardingFailure.values
          .where((failure) => failure.name == failureName)
          .firstOrNull,
    );
  }

  @override
  String toString() =>
      'PendingBoarding($clientEventId, ${status.code}, '
      'capturedAt: $capturedAt)';
}
