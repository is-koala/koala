/// Sunucunun görsel yükleme sınırları (`UploadProperties`); istemcide de
/// bakılıyor ki kullanıcı yüklemeyi bekleyip reddedilmesin.
abstract final class UploadLimits {
  static const int maxImageBytes = 10 * 1024 * 1024;

  /// **WEBP bilerek yok:** sunucu listesinde var ama backend WebP okuyamıyor ve
  /// `STORAGE_UNSUPPORTED_TYPE` ile düşüyor.
  static const Set<String> imageExtensions = {'png', 'jpg', 'jpeg'};

  /// Şirket ve ilan galerisi sınırı; aşılırsa `409`.
  static const int maxGalleryImages = 10;

  /// Ekleme düğmesi ve logo alanında aynı cümle.
  static const String imageRuleLabel = 'PNG veya JPG · en fazla 10 MB';

  static bool hasAllowedImageExtension(String filePath) {
    return imageExtensions.contains(filePath.split('.').last.toLowerCase());
  }
}
