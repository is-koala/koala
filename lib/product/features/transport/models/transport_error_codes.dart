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
