import 'package:koala/product/network/api_exception.dart';

/// Hata sonrası ekranın yapacağı şey.
///
/// Mesaj **ne olduğunu** ve **ne yapılacağını** kullanıcıya söylüyor; bu
/// değer aynı şeyi ekrana söylüyor. Ayrı tutulmasının sebebi, aynı kodun
/// hem bir metni hem bir davranışı olması: "bekleyen inceleme var" hem
/// yazılıyor hem de ekran durum görünümüne geçiyor.
enum IdentityDocumentAction {
  /// Fotoğraflardan biri ya da hepsi yeniden seçilmeli; form açık kalıyor.
  reselectPhotos,

  /// Sunucudaki durum bizim bildiğimizden farklı; inceleme yeniden okunup
  /// durum görünümü çizilmeli.
  showStatus,

  /// Kimlik zaten doğrulanmış; `/users/me` tazelenip ekran kapanmalı.
  alreadyVerified,

  /// Kullanıcının tek başına çözemeyeceği durum; destek adresi gösteriliyor.
  contactSupport,

  /// Geçici sorun; aynı fotoğraflarla tekrar denenebilir.
  retry,
}

/// `POST /users/me/identity-documents` ve `GET`'inin döndürebildiği
/// hatalar, [IdentityError] kalıbıyla: koda bakılıyor, metne değil.
///
/// Kodlar sunucuda mesaj anahtarından türüyor
/// (`{identity.documents.already.pending}` →
/// `IDENTITY_DOCUMENTS_ALREADY_PENDING`); depo dışındaki kaynağı
/// `messages_tr.properties`, `test/support/backend_error_codes_test.dart`
/// buradaki dizgeleri o katalogla karşılaştırıyor.
enum IdentityDocumentError {
  /// Dört parçadan biri boş ya da hiç gelmemiş.
  documentsRequired(
    code: 'IDENTITY_DOCUMENTS_REQUIRED',
    message:
        'Dört fotoğraftan biri sunucuya ulaşmadı. Kareleri kontrol edip '
        'yeniden gönder.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Personel henüz önceki gönderime bakmadı; ikinci yükleme kabul edilmiyor.
  alreadyPending(
    code: 'IDENTITY_DOCUMENTS_ALREADY_PENDING',
    message:
        'Daha önce gönderdiğin fotoğraflar hâlâ incelemede. Sonuç gelmeden '
        'yeni bir yükleme yapılamıyor.',
    action: IdentityDocumentAction.showStatus,
  ),

  /// `GET` için: hiç yükleme yok. Servis bunu `null` olarak döndürüyor;
  /// buradaki karşılık başka bir uçtan aynı kod gelirse diye.
  documentsNotFound(
    code: 'IDENTITY_DOCUMENTS_NOT_FOUND',
    message:
        'Henüz kimlik fotoğrafı göndermedin. Dört fotoğrafı yükleyerek '
        'incelemeye gönderebilirsin.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Çip/beyan ucuna gidilmiş ama sunucu fotoğraflı incelemeyi şart
  /// koşuyor. Çıkış yolu fotoğraf akışı.
  documentReviewRequired(
    code: 'IDENTITY_DOCUMENT_REVIEW_REQUIRED',
    message:
        'Bu doğrulama yolu kapalı. Kimliğini dört fotoğrafla incelemeye '
        'göndererek doğrulayabilirsin.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// İnceleme personel tarafında çoktan sonuçlanmış; elimizdeki durum bayat.
  reviewAlreadyDecided(
    code: 'IDENTITY_REVIEW_ALREADY_DECIDED',
    message:
        'Bu inceleme sonuçlanmış. Güncel durumu görmek için ekranı yenile.',
    action: IdentityDocumentAction.showStatus,
  ),

  /// İnceleme kaydı yok; durum yeniden okunmalı.
  reviewNotFound(
    code: 'IDENTITY_REVIEW_NOT_FOUND',
    message: 'İnceleme kaydı bulunamadı. Durumu yenileyip tekrar dene.',
    action: IdentityDocumentAction.showStatus,
  ),

  /// Kimlik zaten doğrulanmış; yapılacak bir şey kalmadı.
  alreadyVerified(
    code: 'USER_ALREADY_IDENTITY_VERIFIED',
    message: 'Kimliğin zaten doğrulanmış; yeniden belge göndermene gerek yok.',
    action: IdentityDocumentAction.alreadyVerified,
  ),

  /// Bu TCKN başka bir hesapta; personel onayında da aynı engel çıkar.
  numberAlreadyInUse(
    code: 'TC_IDENTITY_NUMBER_ALREADY_IN_USE',
    message:
        'Bu kimlik numarası başka bir hesapta kayıtlı. Kendi hesabın olduğunu '
        'düşünüyorsan destek ekibimizle iletişime geç.',
    action: IdentityDocumentAction.contactSupport,
  ),

  /// Toplam gövde sunucunun `MAX_REQUEST_SIZE` sınırını aştı (`413`).
  requestTooLarge(
    code: 'REQUEST_BODY_TOO_LARGE',
    message:
        'Dört fotoğrafın toplam boyutu sunucunun kabul ettiği sınırı aşıyor. '
        'Büyük kareleri daha düşük çözünürlükte yeniden çekip gönder.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Tek dosya 10 MB sınırını aştı.
  photoTooLarge(
    code: 'IMAGE_SIZE_ERROR',
    message:
        'Fotoğraflardan biri 10 MB sınırını aşıyor. O kareyi daha düşük '
        'çözünürlükte yeniden çek.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Uzantı listede yok ya da dosya görsel olarak açılamadı (HEIC dahil).
  unsupportedType(
    code: 'STORAGE_UNSUPPORTED_TYPE',
    message:
        'Fotoğraflardan biri kabul edilen biçimde değil. PNG, JPG, JPEG veya '
        'WEBP bir kare seç; HEIC kabul edilmiyor.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Çözünürlük 50 megapiksel tavanını aştı.
  resolutionTooHigh(
    code: 'STORAGE_IMAGE_TOO_LARGE',
    message:
        'Fotoğraflardan birinin çözünürlüğü çok yüksek. Kamerayı daha düşük '
        'çözünürlüğe alıp o kareyi yeniden çek.',
    action: IdentityDocumentAction.reselectPhotos,
  ),

  /// Dosya deposu yazamadı; geçici sorun.
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

  /// Sunucunun `errorCode` alanındaki makine okunur kod.
  final String code;

  /// Kullanıcıya gösterilen, **ne yapacağını** söyleyen metin.
  final String message;

  /// Ekranın bu hatadan sonra yapacağı şey.
  final IdentityDocumentAction action;

  /// Hatanın karşılığını bulur; tanımıyorsa `null` ve sunucunun kendi metni
  /// gösterilir.
  ///
  /// Önce kod, sonra durum kodu: büyük gövdeyi uygulama sunucusundan önce
  /// bir ara katman kesebilir ve o `413`'ü zarfsız döndürür. Zarf yokken
  /// `errorCode` da yok; ama `413` bu uçta tek bir anlama geliyor.
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
