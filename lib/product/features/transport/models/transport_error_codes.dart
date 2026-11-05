/// Ulaşım planı uçlarının döndürdüğü `errorCode` değerleri
/// (koala-backend#297, 0.9.28).
///
/// Ayrı dosyada duruyor çünkü `test/support/backend_error_codes_test.dart`
/// bu dosyadaki her büyük harfli dizgeyi backend kataloğuyla karşılaştırıyor;
/// yönlendirme mesaj metnine değil bu dizgelere bakıyor.
abstract final class TransportErrorCodes {
  /// `409` — seçilen servisin kapasitesi dolu.
  static const String shuttleFull = 'TRANSPORT_SHUTTLE_FULL';

  /// `409` — atama koltuk seçilebilir durumda değil (iptal, ret, tamamlandı).
  static const String assignmentNotActive = 'TRANSPORT_ASSIGNMENT_NOT_ACTIVE';

  /// `409` — aynı yön için koltuk aynı anda başka istekle yazıldı; görünüm
  /// yeniden yüklenmeli.
  static const String seatAlreadyTaken = 'TRANSPORT_SEAT_ALREADY_TAKEN';

  /// `409` — servis kapasitesi seçilmiş koltuk sayısının altına indirilemez.
  static const String capacityBelowSeats =
      'TRANSPORT_SHUTTLE_CAPACITY_BELOW_SEATS';

  /// `409` — var olan servisin yönü değiştirilemez.
  static const String directionLocked = 'TRANSPORT_SHUTTLE_DIRECTION_LOCKED';

  /// `404` — `id` verilen servis bu planda yok (silinmiş ya da başka ilan).
  static const String shuttleNotFound = 'TRANSPORT_SHUTTLE_NOT_FOUND';

  /// `404` — `id` verilen durak bu serviste yok.
  static const String stopNotFound = 'TRANSPORT_STOP_NOT_FOUND';

  /// `404` — ilanın ulaşım planı yok; işveren ekranında "plan ekle" hâli.
  static const String planNotFound = 'TRANSPORT_PLAN_NOT_FOUND';

  // ── Biniş teyidi (is-koala/koala#217, koala-backend#298) ──────────────

  /// `404` — işçinin koltuk QR'ı okutuldu ama koltuk yok, yetki yok, token
  /// başka koltuğun ya da anahtar yenilenmiş. Hepsi aynı zarf.
  static const String seatAssignmentNotFound =
      'TRANSPORT_SEAT_ASSIGNMENT_NOT_FOUND';

  /// `404` — işçi kendi QR'ını isterken atama yok ya da işçisi değil.
  static const String jobAssignmentNotFound = 'JOB_ASSIGNMENT_NOT_FOUND';

  /// `400` — token'ın penceresi geçmiş ve geç senkron koşulu tutmuyor.
  static const String tokenExpired = 'TRANSPORT_TOKEN_EXPIRED';

  /// `409` — işçi aynı ilanın başka servisinin QR'ını okuttu.
  static const String wrongShuttle = 'TRANSPORT_WRONG_SHUTTLE';

  /// `409` — o yönde koltuk seçilmemiş.
  static const String seatNotSelected = 'TRANSPORT_SEAT_NOT_SELECTED';

  /// `409` — binmiş koltuğa NO_SHOW işareti.
  static const String alreadyBoarded = 'TRANSPORT_ALREADY_BOARDED';

  /// `409` — biniş aynı anda başka bir istekle yazıldı; liste yenilenir.
  static const String boardingConcurrent = 'TRANSPORT_BOARDING_CONCURRENT';

  /// `409` — aynı `clientEventId` farklı gövdeyle gönderildi.
  static const String boardingIdempotencyConflict =
      'TRANSPORT_BOARDING_IDEMPOTENCY_CONFLICT';

  /// Koltuk seçimini geçersiz kılan çakışmalar: sunucu mesajı gösterilip
  /// görünüm yeniden yüklenir.
  static const Set<String> seatConflicts = {
    shuttleFull,
    assignmentNotActive,
    seatAlreadyTaken,
  };

  /// Plan yazımında "listeyi yeniden yükle" gerektiren kodlar: elde tutulan
  /// servis/durak kimliği sunucuda artık yok.
  static const Set<String> staleReferences = {shuttleNotFound, stopNotFound};
}
