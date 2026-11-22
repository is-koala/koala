import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/network/api_exception.dart';

/// Cümleler iki tarafa farklı şey söylüyor.
enum BoardingActor { worker, employer }

/// Biniş hatasının ekrandaki hâli (#217). Karar `errorCode`'dan: aynı `404` ya
/// da `409` birkaç durumu taşıyor ve her birinin sonraki adımı farklı.
enum BoardingFailure {
  /// `404`: token geçersiz, başkasının ya da anahtar yenilenmiş; sunucu bilerek
  /// ayırmıyor.
  invalidQr,

  tokenExpired,

  wrongShuttle,

  seatNotSelected,

  assignmentNotActive,

  /// Binmiş koltuğa NO_SHOW.
  alreadyBoarded,

  /// Aynı anda yazıldı; liste bayat.
  concurrent,

  retryConflict,

  /// Biniş kovası (120/dk/IP).
  tooManyRequests,

  validation,

  /// Ulaşılamadı; çevrimdışı kuyruk "sonra dene" diye okur.
  offline,

  server,

  unknown;

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

  /// Aynı istek sonra geçebilir mi; çevrimdışı kuyruk bunlarda olayı tutar.
  bool get isRetryable => switch (this) {
    offline || server || tooManyRequests => true,
    _ => false,
  };

  /// Ekrandaki liste bayat; işveren yeniden okur.
  bool get staleView => switch (this) {
    concurrent || alreadyBoarded || assignmentNotActive => true,
    _ => false,
  };

  /// Kullanıcıya gösterilen cümle. [queued] kuyruktan sonradan gönderilen
  /// okutma: QR artık önünde değil, işverenden işaretleme istemesi söylenir.
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
