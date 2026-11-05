import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/network/api_exception.dart';

/// Biniş isteğini kimin attığı: cümleler iki tarafa farklı şey söylüyor.
enum BoardingActor {
  /// İşçi servisin QR'ını okutuyor ya da kendi QR'ını istiyor.
  worker,

  /// İşveren işçinin QR'ını okutuyor, listeden işaretliyor ya da servis
  /// QR'ını yönetiyor.
  employer,
}

/// Biniş uçlarının hatasının ekrandaki hâli (is-koala/koala#217).
///
/// Karar `errorCode`'dan veriliyor, kategoriden değil: aynı `404` ya da
/// `409` birkaç farklı durumu taşıyor ve ekran her birine ayrı bir sonraki
/// adım söylüyor. Bilinmeyen kod sunucunun kendi mesajıyla gösterilir.
enum BoardingFailure {
  /// `404` — token geçersiz, başka servisin/koltuğun, anahtarı yenilenmiş ya
  /// da çağıran taraf değil. Sunucu bunları bilerek ayırmıyor.
  invalidQr,

  /// `400 TRANSPORT_TOKEN_EXPIRED`.
  tokenExpired,

  /// `409 TRANSPORT_WRONG_SHUTTLE`.
  wrongShuttle,

  /// `409 TRANSPORT_SEAT_NOT_SELECTED`.
  seatNotSelected,

  /// `409 TRANSPORT_ASSIGNMENT_NOT_ACTIVE`.
  assignmentNotActive,

  /// `409 TRANSPORT_ALREADY_BOARDED` — binmiş koltuğa NO_SHOW.
  alreadyBoarded,

  /// `409 TRANSPORT_BOARDING_CONCURRENT` — aynı anda yazıldı; liste bayat.
  concurrent,

  /// `409 TRANSPORT_BOARDING_IDEMPOTENCY_CONFLICT`.
  retryConflict,

  /// `429` — biniş kovası (120/dk/IP).
  tooManyRequests,

  /// `400 VALIDATION_FAILED` ya da benzeri doğrulama hatası.
  validation,

  /// Sunucuya ulaşılamadı ya da zaman aşımı. Çevrimdışı kuyruk bunu
  /// "sonra yeniden dene" diye okur.
  offline,

  /// Sunucu tarafı hata (`5xx`); yeniden denenebilir.
  server,

  /// Tanınmayan hata; sunucunun mesajı gösterilir.
  unknown;

  /// [error]'u ekran durumuna çevirir.
  static BoardingFailure classify(ApiException error) {
    switch (error.errorCode) {
      case TransportErrorCodes.tokenExpired:
        return tokenExpired;
      case TransportErrorCodes.wrongShuttle:
        return wrongShuttle;
      case TransportErrorCodes.seatNotSelected:
        return seatNotSelected;
      case TransportErrorCodes.assignmentNotActive:
        return assignmentNotActive;
      case TransportErrorCodes.alreadyBoarded:
        return alreadyBoarded;
      case TransportErrorCodes.boardingConcurrent:
        return concurrent;
      case TransportErrorCodes.boardingIdempotencyConflict:
        return retryConflict;
      case TransportErrorCodes.shuttleNotFound:
      case TransportErrorCodes.seatAssignmentNotFound:
      case TransportErrorCodes.jobAssignmentNotFound:
        return invalidQr;
    }
    return switch (error.type) {
      ApiErrorType.network || ApiErrorType.timeout => offline,
      ApiErrorType.tooManyRequests => tooManyRequests,
      ApiErrorType.server => server,
      ApiErrorType.validation => validation,
      ApiErrorType.notFound => invalidQr,
      _ => unknown,
    };
  }

  /// Aynı istek daha sonra aynen yeniden denenirse geçebilir mi: bağlantı,
  /// sunucu hatası ve hız sınırı. Çevrimdışı kuyruk bunlarda olayı tutar,
  /// diğerlerinde bırakır.
  bool get isRetryable => switch (this) {
    offline || server || tooManyRequests => true,
    _ => false,
  };

  /// Ekranın elindeki bilgi (liste, koltuk) bayat mı: işveren listeyi
  /// yeniden okur.
  bool get staleView => switch (this) {
    concurrent || alreadyBoarded || assignmentNotActive => true,
    _ => false,
  };

  /// Kullanıcıya gösterilen cümle; "siz".
  ///
  /// [queued] işçinin çevrimdışı kuyruğundan sonradan gönderilen bir okutma
  /// için: QR artık önünde değil, "yeniden okutun" demek boşa; işverenden
  /// işaretleme istemesi söylenir.
  String message(
    BoardingActor actor, {
    String? serverMessage,
    bool queued = false,
  }) {
    const askEmployer = 'İşverenden binişinizi işaretlemesini isteyin.';
    switch (this) {
      case invalidQr:
        return actor == BoardingActor.worker
            ? 'Bu QR kodu tanınmadı. Bindiğiniz servisteki güncel QR\'ı '
                  'okutun; sorun sürerse $askEmployer'
            : 'Bu QR kodu bu ilandaki bir koltuğa ait değil ya da yenilenmiş. '
                  'Çalışandan uygulamadaki güncel QR\'ı göstermesini isteyin.';
      case tokenExpired:
        if (actor == BoardingActor.employer) {
          return 'QR\'ın süresi dolmuş. Çalışandan uygulamadaki güncel '
              'QR\'ı göstermesini isteyin.';
        }
        return queued
            ? 'Biniş kaydınız gönderilemedi: okuttuğunuz QR\'ın süresi '
                  'dolmuş. $askEmployer'
            : 'QR\'ın süresi dolmuş; ekrandaki güncel QR\'ı yeniden okutun.';
      case wrongShuttle:
        return 'Bu servis size ayrılan servis değil; koltuğunuzun olduğu '
            'servisin QR kodunu okutun.';
      case seatNotSelected:
        return actor == BoardingActor.worker
            ? 'Bu yön için henüz koltuk seçmediniz. Önce iş detayındaki '
                  'Ulaşım kartından koltuk seçin.'
            : 'Bu çalışanın bu yönde koltuğu yok.';
      case assignmentNotActive:
        return actor == BoardingActor.worker
            ? 'Bu iş için biniş kaydedilemiyor; atama aktif değil.'
            : 'Bu çalışanın ataması aktif değil; biniş kaydedilemiyor.';
      case alreadyBoarded:
        return 'Bu kalkış için biniş zaten teyit edildi; binmedi olarak '
            'işaretlenemez.';
      case concurrent:
        return 'Biniş aynı anda başka bir kayıtla işlendi; liste '
            'yenileniyor.';
      case retryConflict:
        return actor == BoardingActor.worker
            ? 'Biniş kaydı daha önce farklı bilgilerle gönderilmiş. '
                  '$askEmployer'
            : 'Bu işaret daha önce farklı bilgilerle gönderilmiş; listeyi '
                  'yenileyip yeniden deneyin.';
      case tooManyRequests:
        return 'Çok sık deneme yapıldı; birkaç saniye sonra yeniden deneyin.';
      case validation:
        return serverMessage ?? 'Biniş bilgisi eksik ya da hatalı gönderildi.';
      case offline:
        return 'İnternet bağlantısı yok. Bağlantı gelince yeniden deneyin.';
      case server:
        return 'Sunucuya şu an ulaşılamıyor; biraz sonra yeniden deneyin.';
      case unknown:
        return serverMessage ?? 'Biniş kaydedilemedi.';
    }
  }
}
