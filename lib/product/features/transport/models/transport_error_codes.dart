/// Ulaşım uçlarının hata kodları; `backend_error_codes_test` kataloğa karşı
/// sabitliyor.
abstract final class TransportErrorCodes {
  static const String shuttleFull = 'TRANSPORT_SHUTTLE_FULL';

  /// `409`: koltuk seçilebilir değil (iptal, ret, tamamlandı).
  static const String assignmentNotActive = 'TRANSPORT_ASSIGNMENT_NOT_ACTIVE';

  /// `409`: aynı anda başka istekle yazıldı; görünüm yeniden yüklenmeli.
  static const String seatAlreadyTaken = 'TRANSPORT_SEAT_ALREADY_TAKEN';

  static const String capacityBelowSeats =
      'TRANSPORT_SHUTTLE_CAPACITY_BELOW_SEATS';

  static const String directionLocked = 'TRANSPORT_SHUTTLE_DIRECTION_LOCKED';

  static const String shuttleNotFound = 'TRANSPORT_SHUTTLE_NOT_FOUND';

  static const String stopNotFound = 'TRANSPORT_STOP_NOT_FOUND';

  /// `404`: plan yok; işverende "plan ekle".
  static const String planNotFound = 'TRANSPORT_PLAN_NOT_FOUND';

  // ── Biniş teyidi (#217) ──────────────────────────────────────────────

  /// `404`: koltuk yok, yetki yok, token başkasının ya da anahtar yenilenmiş;
  /// hepsi aynı zarf.
  static const String seatAssignmentNotFound =
      'TRANSPORT_SEAT_ASSIGNMENT_NOT_FOUND';

  static const String jobAssignmentNotFound = 'JOB_ASSIGNMENT_NOT_FOUND';

  /// `400`: pencere geçmiş ve geç senkron koşulu tutmuyor.
  static const String tokenExpired = 'TRANSPORT_TOKEN_EXPIRED';

  static const String wrongShuttle = 'TRANSPORT_WRONG_SHUTTLE';

  static const String seatNotSelected = 'TRANSPORT_SEAT_NOT_SELECTED';

  static const String alreadyBoarded = 'TRANSPORT_ALREADY_BOARDED';

  static const String boardingConcurrent = 'TRANSPORT_BOARDING_CONCURRENT';

  /// `409`: aynı `clientEventId` farklı gövdeyle.
  static const String boardingIdempotencyConflict =
      'TRANSPORT_BOARDING_IDEMPOTENCY_CONFLICT';

  /// Sunucu mesajı gösterilip görünüm yeniden yüklenir.
  static const Set<String> seatConflicts = {
    shuttleFull,
    assignmentNotActive,
    seatAlreadyTaken,
  };

  /// Elde tutulan servis/durak sunucuda yok; liste yeniden yüklenmeli.
  static const Set<String> staleReferences = {shuttleNotFound, stopNotFound};
}
