import 'package:koala/product/network/api_exception.dart';

/// Hata sonrası ekranın ne yapacağı; mesaj ne olduğunu, bu davranışı söylüyor.
enum DisputeEvidenceAction {
  pickAnother,

  /// Sunucudaki durum değişti (sonuçlandı, sınır doldu); yeniden okunmalı.
  reload,

  /// Geçici; aynı dosyayla tekrar denenebilir.
  retry,
}

/// Kanıt uçlarının hata kodları (#215). Yönlendirme koda bakıyor: `409` hem
/// "sonuçlandı" hem "sınır doldu" demek olabilir. `backend_error_codes_test`
/// kataloğa karşı sabitliyor.
enum DisputeEvidenceError {
  /// `409`: sonuçlanmış; yeni kanıt eklenemez, mevcutlar okunur.
  disputeClosed(
    code: 'DISPUTE_EVIDENCE_DISPUTE_CLOSED',
    message:
        'Bu uyuşmazlık sonuçlanmış; yeni kanıt eklenemiyor. Güncel durumu '
        'görmek için sayfayı yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  /// `409`: uyuşmazlık başına en çok beş dosya, iki tarafın toplamı.
  limitReached(
    code: 'DISPUTE_EVIDENCE_LIMIT_REACHED',
    message:
        'Bu uyuşmazlığa en fazla 5 kanıt eklenebilir; sınıra ulaşıldı. '
        'Karşı taraf da ekliyor olabilir, listeyi yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  empty(
    code: 'DISPUTE_EVIDENCE_EMPTY',
    message: 'Dosya boş. İçeriği olan bir dosya seçip yeniden deneyin.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  tooLarge(
    code: 'DISPUTE_EVIDENCE_TOO_LARGE',
    message: 'Dosya 10 MB sınırını aşıyor. Daha küçük bir dosya seçin.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `400`: uzantı ya da içerik kabul edilmiyor (HEIC, WEBP dahil).
  unsupportedType(
    code: 'STORAGE_UNSUPPORTED_TYPE',
    message:
        'Bu dosya biçimi kabul edilmiyor. PDF, PNG veya JPG bir dosya '
        'seçin; HEIC kabul edilmiyor.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `400`: 50 megapiksel tavanı aşıldı.
  resolutionTooHigh(
    code: 'STORAGE_IMAGE_TOO_LARGE',
    message:
        'Görselin çözünürlüğü çok yüksek. Daha düşük çözünürlükte çekilmiş '
        'bir kopya seçin.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  requestTooLarge(
    code: 'REQUEST_BODY_TOO_LARGE',
    message:
        'Dosya sunucunun kabul ettiği boyutu aşıyor. Daha küçük bir dosya '
        'seçin.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `404`: uyuşmazlık yok ya da taraf değilsin; sunucu ikisini ayırmıyor.
  disputeNotFound(
    code: 'DISPUTE_NOT_FOUND',
    message:
        'Uyuşmazlık bulunamadı. Kaldırılmış olabilir; sayfayı yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  evidenceNotFound(
    code: 'DISPUTE_EVIDENCE_NOT_FOUND',
    message: 'Kanıt dosyası bulunamadı; liste değişmiş olabilir, yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  /// `500`: yazma başarısız; sunucu yarım nesneyi siliyor, tekrar denemek
  /// güvenli.
  uploadFailed(
    code: 'DISPUTE_EVIDENCE_UPLOAD_FAILED',
    message: 'Kanıt dosyası yüklenemedi. Biraz sonra yeniden deneyin.',
    action: DisputeEvidenceAction.retry,
  );

  const DisputeEvidenceError({
    required this.code,
    required this.message,
    required this.action,
  });

  final String code;

  final String message;

  final DisputeEvidenceAction action;

  static DisputeEvidenceError? fromCode(String? code) {
    if (code == null) return null;
    for (final error in values) {
      if (error.code == code) return error;
    }
    return null;
  }
}

class DisputeEvidenceFailure {
  const DisputeEvidenceFailure({required this.message, required this.action});

  final String message;
  final DisputeEvidenceAction action;

  /// Önce kod, sonra tür ve durum, en son sunucunun mesajı. `429` ve `413`
  /// zarfsız gelebildiği için duruma bakılıyor.
  factory DisputeEvidenceFailure.from(ApiException error) {
    final known = DisputeEvidenceError.fromCode(error.errorCode);
    if (known != null) {
      return DisputeEvidenceFailure(
        message: known.message,
        action: known.action,
      );
    }

    if (error.statusCode == 413) {
      const tooLarge = DisputeEvidenceError.requestTooLarge;
      return DisputeEvidenceFailure(
        message: tooLarge.message,
        action: tooLarge.action,
      );
    }

    if (error.type == ApiErrorType.tooManyRequests) {
      return const DisputeEvidenceFailure(
        message:
            'Kısa sürede çok fazla yükleme yaptınız. Biraz bekleyip yeniden '
            'deneyin.',
        action: DisputeEvidenceAction.retry,
      );
    }

    return DisputeEvidenceFailure(
      message: error.message,
      action: error.type.serverStateMoved
          ? DisputeEvidenceAction.reload
          : DisputeEvidenceAction.retry,
    );
  }
}
