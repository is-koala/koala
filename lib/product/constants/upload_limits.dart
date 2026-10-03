/// Sunucunun görsel yüklemede uyguladığı sınırlar.
///
/// Değerler backend'in `UploadProperties` sınıfından birebir kopyalandı.
/// İstemcide de bakılıyor ki kullanıcı yüklemenin bitmesini bekleyip
/// reddedilmesin; sunucu aynı kuralları kendi tarafında da uyguluyor.
abstract final class UploadLimits {
  /// Tek bir görselin en büyük boyutu (`upload.max-image-size-mb`, 10 MB).
  static const int maxImageBytes = 10 * 1024 * 1024;

  /// Kabul edilen uzantılar (`upload.image-extensions`).
  ///
  /// **WEBP bilerek yok.** Sunucu listesinde duruyor ama yüklenen görsel
  /// ImageIO ile açılabilmek zorunda ve backend'de WebP okuyan bir eklenti
  /// yok: gerçek bir WebP hep `STORAGE_UNSUPPORTED_TYPE` ile düşüyor
  /// (koala-backend#348). Kullanıcıya vaat edilmiyor.
  static const Set<String> imageExtensions = {'png', 'jpg', 'jpeg'};

  /// Bir şirket ya da ilan galerisindeki en fazla görsel.
  ///
  /// Backend'in `upload.max-company-images` ve `upload.max-job-images`
  /// değerleri aynı ürün sınırını taşır.
  /// Aşılırsa sunucu `409` döndürüyor.
  static const int maxGalleryImages = 10;

  /// Yükleme kurallarını kullanıcıya anlatan tek satır; ekleme düğmesinin
  /// altında ve logo alanında aynı cümle görünsün diye burada.
  static const String imageRuleLabel = 'PNG veya JPG · en fazla 10 MB';

  /// [filePath] kabul edilen bir uzantı taşıyor mu.
  static bool hasAllowedImageExtension(String filePath) {
    return imageExtensions.contains(filePath.split('.').last.toLowerCase());
  }
}
