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

  CompanyImage copyWith({int? sortOrder, bool? isCover}) {
    return CompanyImage(
      id: id,
      url: url,
      sortOrder: sortOrder ?? this.sortOrder,
      isCover: isCover ?? this.isCover,
      caption: caption,
    );
  }

  /// `PUT /companies/{id}/images` gövdesindeki bir satır
  /// (`GalleryImageEntryDto`).
  ///
  /// [id] galeri satırının değil **görselin** kimliği — sunucu `GalleryMapper`
  /// içinde `id`yi `image.id`den eşliyor ve `imageId` olarak onu geri
  /// bekliyor. Bayrağın adı da `isCover` değil `cover`.
  ///
  /// [sortOrder] verilirse modeldeki eski değerin yerine yazılır: toptan
  /// güncellemede sıra listedeki konumdan geliyor.
  ///
  /// `caption` düzenlenmiyor ama gövdede taşınmak zorunda: gönderilmeyen
  /// alan sunucuda `null`a düşer, yani başlığı sessizce silerdi.
  Map<String, dynamic> toEntryJson({int? sortOrder}) {
    return {
      'imageId': id,
      'sortOrder': sortOrder ?? this.sortOrder,
      'cover': isCover,
      'caption': caption,
    };
  }
}
