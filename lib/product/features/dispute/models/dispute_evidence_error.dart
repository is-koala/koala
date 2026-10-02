import 'package:koala/product/network/api_exception.dart';

/// Hata sonrası ekranın yapacağı şey.
///
/// Mesaj **ne olduğunu** söylüyor; bu değer ekranın ne yapacağını. Ayrı
/// tutuluyor çünkü aynı kodun hem bir metni hem bir davranışı var: "uyuşmazlık
/// sonuçlanmış" hem yazılıyor hem de ekran kendini yeniden okuyor.
enum DisputeEvidenceAction {
  /// Başka bir dosya seçilmeli; sayfanın durumu doğru.
  pickAnother,

  /// Sunucudaki durum bizim bildiğimizden farklı (sonuçlandı, sınır doldu,
  /// kayıt yok); uyuşmazlıklar ve kanıtlar yeniden okunmalı.
  reload,

  /// Geçici sorun; aynı dosyayla tekrar denenebilir.
  retry,
}

/// Kanıt uçlarının döndürebildiği `errorCode` değerleri
/// (`DisputeEvidenceController`, `UploadValidator`; is-koala/koala#215).
///
/// Kodlar sunucuda mesaj anahtarından türüyor
/// (`{dispute.evidence.dispute.closed}` → `DISPUTE_EVIDENCE_DISPUTE_CLOSED`);
/// `test/support/backend_error_codes_test.dart` bu dosyadaki her büyük harfli
/// dizgeyi `messages_tr.properties` ile karşılaştırıyor. Yönlendirme **koda**
/// bakıyor, mesaj metnine değil: `409` hem "sonuçlandı" hem "sınır doldu"
/// anlamına gelebiliyor ve ikisinin cevabı farklı.
enum DisputeEvidenceError {
  /// `409` — uyuşmazlık sonuçlanmış; yeni kanıt eklenemez ama mevcutlar
  /// okunur.
  disputeClosed(
    code: 'DISPUTE_EVIDENCE_DISPUTE_CLOSED',
    message:
        'Bu uyuşmazlık sonuçlanmış; yeni kanıt eklenemiyor. Güncel durumu '
        'görmek için sayfayı yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  /// `409` — uyuşmazlık başına en çok beş dosya; iki tarafın toplamı.
  limitReached(
    code: 'DISPUTE_EVIDENCE_LIMIT_REACHED',
    message:
        'Bu uyuşmazlığa en fazla 5 kanıt eklenebilir; sınıra ulaşıldı. '
        'Karşı taraf da ekliyor olabilir, listeyi yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  /// `400` — dosya boş.
  empty(
    code: 'DISPUTE_EVIDENCE_EMPTY',
    message: 'Dosya boş. İçeriği olan bir dosya seçip yeniden dene.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `400` — dosya 10 MB sınırını aşıyor.
  tooLarge(
    code: 'DISPUTE_EVIDENCE_TOO_LARGE',
    message: 'Dosya 10 MB sınırını aşıyor. Daha küçük bir dosya seç.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `400` — uzantı listede yok ya da içerik uzantıyla uyuşmuyor / açılamıyor
  /// (HEIC dahil).
  unsupportedType(
    code: 'STORAGE_UNSUPPORTED_TYPE',
    message:
        'Bu dosya biçimi kabul edilmiyor. PDF, PNG, JPG veya WEBP bir dosya '
        'seç; HEIC kabul edilmiyor.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `400` — görselin çözünürlüğü 50 megapiksel tavanını aşıyor.
  resolutionTooHigh(
    code: 'STORAGE_IMAGE_TOO_LARGE',
    message:
        'Görselin çözünürlüğü çok yüksek. Daha düşük çözünürlükte çekilmiş '
        'bir kopya seç.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `413` — gövde sunucunun `MAX_REQUEST_SIZE` sınırını aştı.
  requestTooLarge(
    code: 'REQUEST_BODY_TOO_LARGE',
    message:
        'Dosya sunucunun kabul ettiği boyutu aşıyor. Daha küçük bir dosya seç.',
    action: DisputeEvidenceAction.pickAnother,
  ),

  /// `404` — uyuşmazlık yok ya da kullanıcı atamanın tarafı değil (sunucu
  /// ikisini ayırt ettirmiyor).
  disputeNotFound(
    code: 'DISPUTE_NOT_FOUND',
    message:
        'Uyuşmazlık bulunamadı. Kaldırılmış olabilir; sayfayı yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  /// `404` — kanıt yok (liste bu sırada değişmiş).
  evidenceNotFound(
    code: 'DISPUTE_EVIDENCE_NOT_FOUND',
    message: 'Kanıt dosyası bulunamadı; liste değişmiş olabilir, yeniliyoruz.',
    action: DisputeEvidenceAction.reload,
  ),

  /// `500` — depo yazması ya da satır yazması başarısız oldu; sunucu yarım
  /// kalan nesneyi siliyor, tekrar denemek güvenli.
  uploadFailed(
    code: 'DISPUTE_EVIDENCE_UPLOAD_FAILED',
    message: 'Kanıt dosyası yüklenemedi. Biraz sonra yeniden dene.',
    action: DisputeEvidenceAction.retry,
  );

  const DisputeEvidenceError({
    required this.code,
    required this.message,
    required this.action,
  });

  /// Sunucunun `errorCode`'u.
  final String code;

  /// Kullanıcıya gösterilen cümle: ne oldu ve ne yapılacak.
  final String message;

  final DisputeEvidenceAction action;

  /// `errorCode`'dan hatayı bulur; tanınmayan kod `null`.
  static DisputeEvidenceError? fromCode(String? code) {
    if (code == null) return null;
    for (final error in values) {
      if (error.code == code) return error;
    }
    return null;
  }
}

/// Bir yükleme ya da indirme hatasının kullanıcıya söylenişi.
class DisputeEvidenceFailure {
  const DisputeEvidenceFailure({required this.message, required this.action});

  final String message;
  final DisputeEvidenceAction action;

  /// [error]'ı kodla çözer; kod tanınmıyorsa tür ve durum koduna bakar, o da
  /// yetmezse sunucunun kendi mesajını olduğu gibi gösterir.
  ///
  /// `429` ve `413` zarfsız da gelebiliyor (vekil sunucu): koda değil
  /// duruma bakıyor.
  factory DisputeEvidenceFailure.from(ApiException error) {
    final known = DisputeEvidenceError.fromCode(error.errorCode);
    if (known != null) {
      return DisputeEvidenceFailure(
        message: known.message,
        action: known.action,
      );
    }

    if (error.statusCode == 413) {
      return const DisputeEvidenceFailure(
        message:
            'Dosya sunucunun kabul ettiği boyutu aşıyor. Daha küçük bir dosya seç.',
        action: DisputeEvidenceAction.pickAnother,
      );
    }

    if (error.type == ApiErrorType.tooManyRequests) {
      return const DisputeEvidenceFailure(
        message:
            'Kısa sürede çok fazla yükleme yaptın. Biraz bekleyip yeniden dene.',
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
