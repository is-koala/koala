/// Galerideki tek görsel; [id] galeri ilişkisinin değil medyanın kimliği.
class GalleryImage {
  const GalleryImage({
    required this.id,
    required this.url,
    this.sortOrder = 0,
    this.isCover = false,
    this.caption,
  });

  final String id;
  final String url;
  final int sortOrder;
  final bool isCover;
  final String? caption;

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      id: '${json['id']}',
      url: json['url'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isCover: json['cover'] as bool? ?? false,
      caption: json['caption'] as String?,
    );
  }

  static List<GalleryImage> listFromJson(Object? data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(GalleryImage.fromJson)
        .toList();
  }

  GalleryImage copyWith({int? sortOrder, bool? isCover}) {
    return GalleryImage(
      id: id,
      url: url,
      sortOrder: sortOrder ?? this.sortOrder,
      isCover: isCover ?? this.isCover,
      caption: caption,
    );
  }

  /// Toptan `PUT` satırı. Başlık düzenlenmese de gönderilir, yoksa sunucu
  /// siler; [sortOrder] güncel konumdan.
  Map<String, dynamic> toEntryJson({int? sortOrder}) {
    return {
      'imageId': id,
      'sortOrder': sortOrder ?? this.sortOrder,
      'cover': isCover,
      'caption': caption,
    };
  }
}
