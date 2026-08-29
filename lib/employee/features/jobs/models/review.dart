import 'package:koala/employee/features/home/models/job_detail.dart';

/// Bir iş üzerine bırakılan değerlendirme.
///
/// Backend `ReviewDto` karşılığı. Değerlendirme **atamaya** bırakılıyor
/// (`POST /job-assignments/{assignmentId}/reviews`) ama karşı **kişiye**
/// yazılıyor; listeleme bu yüzden kişi üzerinden gidiyor
/// (`GET /users/{userId}/reviews`).
///
/// Anonim değerlendirmede `author` **gelmiyor**: sunucu yazarı yalnızca
/// yanıt katmanında gizliyor, veritabanında `author_id` dolu kalıyor. Yani
/// tekillik kuralı, tek değerlendirme sınırı ve kötüye kullanım incelemesi
/// anonim kayıtta da işliyor.
class Review {
  const Review({
    required this.id,
    required this.rating,
    this.author,
    this.isAnonymous = false,
    this.comment,
    this.createdAt,
  });

  final String id;

  /// Değerlendirmeyi yazan. Backend `SafeUserDto` döndürüyor; Dart karşılığı
  /// [JobCreator] olarak zaten var, ikinci bir kopya çıkarılmadı.
  ///
  /// Anonim değerlendirmede `null` — sunucu alanı hiç doldurmuyor. Sahte bir
  /// "Anonim Kullanıcı" kaydı üretilmedi; olmayan bir kişiyi var göstermek
  /// her okuyan yerde ayıklanmak zorunda kalırdı.
  final JobCreator? author;

  /// Yazar gizli mi. [author] zaten `null` oluyor ama bayrak ayrıca
  /// taşınıyor: "yazar gizlendi" ile "yazar gelmedi" farklı şeyler.
  final bool isAnonymous;

  /// 1 ile 5 arası. Sunucu aralık dışını `400` ile reddediyor.
  final int rating;

  /// Yorum isteğe bağlı; yalnızca puan verilmiş olabilir.
  final String? comment;

  final DateTime? createdAt;

  /// Yorumu olan değerlendirme. Boş yorumlar listede satır kaplamamalı.
  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  /// Listede gösterilecek yazar adı.
  String get authorLabel => author?.fullName ?? 'Anonim';

  factory Review.fromJson(Map<String, dynamic> json) {
    final author = json['author'];

    return Review(
      id: '${json['id']}',
      author: author is Map<String, dynamic>
          ? JobCreator.fromJson(author)
          : null,
      isAnonymous: json['anonymous'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: switch (json['createdAt']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }
}

/// Sayfalı değerlendirme yanıtı.
class ReviewPage {
  const ReviewPage({
    this.reviews = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<Review> reviews;
  final int page;
  final int totalElements;
  final bool last;

  factory ReviewPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return ReviewPage(
      reviews: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(Review.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
