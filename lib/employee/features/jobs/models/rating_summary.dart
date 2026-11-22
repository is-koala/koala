/// Puan özeti. Hiç değerlendirilmemişte uç `data: null` döndürüyor; sıfır özet
/// uydurulmuyor.
class RatingSummary {
  const RatingSummary({
    required this.userId,
    this.reviewCount = 0,
    this.averageRating = 0,
  });

  final String userId;

  final int reviewCount;

  final double averageRating;

  /// Değerlendirmesize "0.0" yazmak kötü puan gibi görünür.
  bool get hasRating => reviewCount > 0;

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      userId: '${json['userId']}',
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
    );
  }
}
