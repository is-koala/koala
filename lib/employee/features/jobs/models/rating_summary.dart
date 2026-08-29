/// Bir kişinin aldığı puanların özeti.
///
/// Backend `RatingSummaryDto` karşılığı. Ortalama her istekte yeniden
/// hesaplanmıyor, değerlendirme geldikçe biriktiriliyor.
///
/// Hiç değerlendirilmemiş kullanıcı için uç `data: null` döndürüyor; servis
/// bunu `null` olarak geçiriyor, burada sıfır bir özet uydurulmuyor.
class RatingSummary {
  const RatingSummary({
    required this.userId,
    this.reviewCount = 0,
    this.averageRating = 0,
  });

  final String userId;

  final int reviewCount;

  final double averageRating;

  /// Puan gösterilebilir mi.
  ///
  /// Değerlendirmesi olmayan kişiye "0.0" yazmak onu kötü puanlı gibi
  /// gösterirdi; `EmployerStats.hasRating` ile aynı ayrım.
  bool get hasRating => reviewCount > 0;

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      userId: '${json['userId']}',
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
    );
  }
}
