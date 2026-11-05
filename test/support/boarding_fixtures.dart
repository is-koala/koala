// Biniş teyidi gövdeleri (koala-backend#298); model, servis, kuyruk ve
// ekran testleri aynı sözlükleri kullanıyor ki bir alan adı değiştiğinde
// hepsi birlikte kırılsın.

import 'package:koala/product/network/api_exception.dart';

/// Token'ların taşıdığı kimlikler gerçek UUID: istemci biçimi denetliyor.
const String shuttleUuid = '1b4e28ba-2fa1-11d2-883f-0016d3cca427';
const String seatUuid = '6f1c2d3e-4a5b-4c6d-8e7f-0a1b2c3d4e5f';

/// `s1.{shuttleId}.{pencere}.{mac}`.
const String shuttleTokenValue = 's1.$shuttleUuid.2934001.abcDEF_12-3';

/// `w1.{seatAssignmentId}.{pencere}.{mac}`.
const String workerTokenValue = 'w1.$seatUuid.2934001.xyzXYZ_98-7';

/// `BoardingQrDto`.
Map<String, Object?> boardingQrJson({
  String token = shuttleTokenValue,
  bool isStatic = false,
  String issuedAt = '2026-09-20T03:30:00Z',
  String? refreshAt = '2026-09-20T03:40:00Z',
  String? expiresAt = '2026-09-20T03:50:00Z',
  String scheme = 'koala-staging',
}) => {
  'token': token,
  'static': isStatic,
  'issuedAt': issuedAt,
  'expiresAt': expiresAt,
  'refreshAt': refreshAt,
  'uri': '$scheme://board?t=$token',
};

/// `BoardingEventDto`.
Map<String, Object?> boardingEventJson({
  String id = 'event-1',
  String seatAssignmentId = seatUuid,
  String kind = 'BOARDED',
  String source = 'WORKER_SCANNED_SHUTTLE_QR',
  String occurredAt = '2026-09-20T03:41:00Z',
  List<String> flags = const [],
  bool replayed = false,
}) => {
  'id': id,
  'seatAssignmentId': seatAssignmentId,
  'jobAssignmentId': 'assignment-1',
  'shuttleId': shuttleUuid,
  'stopId': 'stop-1',
  'kind': kind,
  'source': source,
  'occurredAt': occurredAt,
  'capturedAt': occurredAt,
  'latitude': null,
  'longitude': null,
  'flags': flags,
  'recordedById': 'worker-1',
  'replayed': replayed,
};

/// `ShuttleBoardingRowDto`.
Map<String, Object?> boardingRowJson({
  String seatAssignmentId = seatUuid,
  String? firstName = 'Ayşe',
  String? lastName = 'Yılmaz',
  String stopId = 'stop-1',
  String? stopLabel = 'Kadıköy İskele',
  String scheduledAt = '2026-09-20T03:40:00Z',
  bool boarded = false,
  Map<String, Object?>? event,
}) => {
  'seatAssignmentId': seatAssignmentId,
  'jobAssignmentId': 'assignment-1',
  'workerId': 'worker-1',
  'firstName': firstName,
  'lastName': lastName,
  'stopId': stopId,
  'stopLabel': stopLabel,
  'scheduledAt': scheduledAt,
  'boarded': boarded,
  'event': event,
};

/// Ağa ulaşılamadı.
const ApiException offlineError = ApiException(
  message: 'Bağlantı yok',
  type: ApiErrorType.network,
);

/// Sunucunun koda bağlı reddi.
ApiException boardingError(
  String errorCode, {
  ApiErrorType type = ApiErrorType.dataConflict,
  int statusCode = 409,
}) => ApiException(
  message: 'Sunucu mesajı',
  type: type,
  statusCode: statusCode,
  errorCode: errorCode,
);
