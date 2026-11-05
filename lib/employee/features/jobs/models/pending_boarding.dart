import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';

/// Kuyruktaki okutmanın durumu.
enum PendingBoardingStatus {
  /// Gönderilmeyi bekliyor; bağlantı gelince yeniden denenir.
  pending('PENDING'),

  /// Sunucu kabul etmedi; işçiye "işverenden işaretlemesini iste" denir ve
  /// kullanıcı kapatana kadar kartta kalır. Yeniden denenmez.
  failed('FAILED');

  const PendingBoardingStatus(this.code);

  final String code;

  static PendingBoardingStatus fromCode(Object? value) =>
      values.where((status) => status.code == value).firstOrNull ?? pending;
}

/// İşçinin servis QR'ını okuttuğu ama sunucuya henüz ulaşmamış biniş
/// (is-koala/koala#217).
///
/// Sunucu sözleşmesi: token **okutma anında** geçerliyse yükleme 12 saate
/// kadar `LATE_SYNC` bayrağıyla kabul ediliyor; aynı [clientEventId] ile
/// yeniden deneme token süresi dolmuş olsa da kayıtlı olayı döndürüyor.
/// Bu yüzden gövde bir kez kurulup aynen saklanıyor: [capturedAt] ve konum
/// her denemede aynı gider, yoksa sunucu `IDEMPOTENCY_CONFLICT` der.
///
/// [token] imzalı biniş token'ı; cihazda yalnız gönderilene kadar durur ve
/// hiçbir yere yazdırılmaz ([toString] onu içermez).
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

  /// Token'ın taşıdığı servis; okutma ucu bu servisin yoluna gider.
  final String shuttleId;
  final String token;

  /// Okutma anı, UTC.
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;

  /// İş detayından okutulduysa atama ve yön; kart kendi bekleyen
  /// okutmasını bunlarla buluyor. Telefon kamerasıyla açılan bağlantıda
  /// bilinmiyor.
  final String? assignmentId;
  final ShuttleDirection? direction;

  final PendingBoardingStatus status;

  /// [PendingBoardingStatus.failed] iken sunucunun reddi.
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

  /// Okunamayan kayıtta `null`: bozuk bir satır kuyruğun geri kalanını
  /// kilitlememeli.
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
