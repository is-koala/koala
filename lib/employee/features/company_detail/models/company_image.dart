/// Şirket galerisindeki bir görsel.
///
/// Backend `GalleryImageDto` karşılığı. Adı `Image` değil çünkü Flutter'ın
/// `Image` widget'ıyla çakışırdı.
class CompanyImage {
  const CompanyImage({
    required this.id,
    required this.url,
    this.sortOrder = 0,
    this.isCover = false,
    this.caption,
  });

  final String id;

  final String url;

  /// Galerideki sırası; sunucu zaten sıralı döndürüyor.
  final int sortOrder;

  /// Kapak görseli mi. İlk yüklenen görsel kendiliğinden kapak oluyor.
  final bool isCover;

  final String? caption;

  factory CompanyImage.fromJson(Map<String, dynamic> json) {
    return CompanyImage(
      id: '${json['id']}',
      url: json['url'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isCover: json['cover'] as bool? ?? false,
      caption: json['caption'] as String?,
    );
  }
}
