import 'package:koala/product/network/api_exception.dart';

/// Hata sonrası ekranın yapacağı şey; mesaj ne olduğunu, bu davranışı söylüyor
/// (ör. "bekleyen inceleme" hem yazılır hem durum görünümüne geçilir).
enum IdentityDocumentAction {
  reselectPhotos,

  /// Sunucudaki durum farklı; inceleme yeniden okunur.
  showStatus,

  /// `/users/me` tazelenip ekran kapanır.
  alreadyVerified,

  contactSupport,

  retry,
}

/// Fotoğraflı inceleme uçlarının hataları; koda bakılıyor.
/// `backend_error_codes_test` kataloğa karşı sabitliyor.
enum IdentityDocumentError {
  documentsRequired(
    code: 'IDENTITY_DOCUMENTS_REQUIRED',
    message:
        'Dört fotoğraftan biri sunucuya ulaşmadı. Kareleri kontrol edip '
        'yeniden gönder.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Önceki gönderim incelenmeden ikinci yükleme yok.
  alreadyPending(
    code: 'IDENTITY_DOCUMENTS_ALREADY_PENDING',
    message:
        'Daha önce gönderdiğin fotoğraflar hâlâ incelemede. Sonuç gelmeden '
        'yeni bir yükleme yapılamıyor.',
    action: IdentityDocumentAction.showStatus,
  ),

  /// Servis `GET`'te bunu `null` döndürüyor; burası başka uçtan gelirse diye.
  documentsNotFound(
    code: 'IDENTITY_DOCUMENTS_NOT_FOUND',
    message:
        'Henüz kimlik fotoğrafı göndermedin. Dört fotoğrafı yükleyerek '
        'incelemeye gönderebilirsin.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Çıkış yolu fotoğraf akışı.
  documentReviewRequired(
    code: 'IDENTITY_DOCUMENT_REVIEW_REQUIRED',
    message:
        'Bu doğrulama yolu kapalı. Kimliğini dört fotoğrafla incelemeye '
        'göndererek doğrulayabilirsin.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  reviewAlreadyDecided(
    code: 'IDENTITY_REVIEW_ALREADY_DECIDED',
    message:
        'Bu inceleme sonuçlanmış. Güncel durumu görmek için ekranı yenile.',
    action: IdentityDocumentAction.showStatus,
  ),

  reviewNotFound(
    code: 'IDENTITY_REVIEW_NOT_FOUND',
    message: 'İnceleme kaydı bulunamadı. Durumu yenileyip tekrar dene.',
    action: IdentityDocumentAction.showStatus,
  ),

  alreadyVerified(
    code: 'USER_ALREADY_IDENTITY_VERIFIED',
    message: 'Kimliğin zaten doğrulanmış; yeniden belge göndermene gerek yok.',
    action: IdentityDocumentAction.alreadyVerified,
  ),

  /// Personel onayında da aynı engel çıkar.
  numberAlreadyInUse(
    code: 'TC_IDENTITY_NUMBER_ALREADY_IN_USE',
    message:
        'Bu kimlik numarası başka bir hesapta kayıtlı. Kendi hesabın olduğunu '
        'düşünüyorsan destek ekibimizle iletişime geç.',
    action: IdentityDocumentAction.contactSupport,
  ),

  requestTooLarge(
    code: 'REQUEST_BODY_TOO_LARGE',
    message:
        'Dört fotoğrafın toplam boyutu sunucunun kabul ettiği sınırı aşıyor. '
        'Büyük kareleri daha düşük çözünürlükte yeniden çekip gönder.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  photoTooLarge(
    code: 'IMAGE_SIZE_ERROR',
    message:
        'Fotoğraflardan biri 10 MB sınırını aşıyor. O kareyi daha düşük '
        'çözünürlükte yeniden çek.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// HEIC dahil.
  unsupportedType(
    code: 'STORAGE_UNSUPPORTED_TYPE',
    message:
        'Fotoğraflardan biri kabul edilen biçimde değil. PNG, JPG, JPEG veya '
        'bir kare seç; HEIC kabul edilmiyor.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  resolutionTooHigh(
    code: 'STORAGE_IMAGE_TOO_LARGE',
    message:
        'Fotoğraflardan birinin çözünürlüğü çok yüksek. Kamerayı daha düşük '
        'çözünürlüğe alıp o kareyi yeniden çek.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  uploadFailed(
    code: 'IMAGE_UPLOAD_ERROR',
    message:
        'Fotoğraflar sunucuya kaydedilemedi. Birazdan aynı karelerle tekrar '
        'dene.',
    action: IdentityDocumentAction.retry,
  );

  const IdentityDocumentError({
    required this.code,
    required this.message,
    required this.action,
  });

  final String code;

  final String message;

  final IdentityDocumentAction action;

  /// Önce kod, sonra durum kodu: ara katman büyük gövdeyi zarfsız `413` ile
  /// kesebilir; bu uçta `413` tek anlamlı.
  static IdentityDocumentError? of(ApiException error) {
    final byCode = fromErrorCode(error.errorCode);
    if (byCode != null) return byCode;
    if (error.statusCode == 413) return IdentityDocumentError.requestTooLarge;
    return null;
  }

  static IdentityDocumentError? fromErrorCode(String? errorCode) {
    if (errorCode == null) return null;
    for (final error in IdentityDocumentError.values) {
      if (error.code == errorCode) return error;
    }
    return null;
  }
}
