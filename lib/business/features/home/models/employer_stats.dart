/// Bir işverenin özet sayıları. `GET /users/{userId}/employer-stats`
/// yanıtındaki `EmployerStatsDto`.
///
/// Sayılar **kişiye** bağlı, şirkete değil: şirket adına açılan ilan da onu
/// açan kullanıcının hanesine yazılıyor. Şirketin birden çok yetkilisi varsa
/// her biri kendi sayısını görür.
class EmployerStats {
  const EmployerStats({
    required this.userId,
    this.jobsPosted = 0,
    this.completedJobs = 0,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.memberSince,
  });

  final String userId;

  /// Açılan toplam ilan sayısı; kapanmışlar da dâhil.
  final int jobsPosted;

  /// Tamamlanmış iş sayısı.
  final int completedJobs;

  /// Ortalama puan. Hiç değerlendirme yoksa backend `0` döndürüyor —
  /// [hasRating] bu ikisini ayırıyor.
  final double averageRating;

  final int reviewCount;

  /// Hesabın açıldığı an.
  final DateTime? memberSince;

  /// Puan gösterilebilir mi. Değerlendirmesi olmayan işverene "0.0" yazmak
  /// kötü puan almış gibi görünürdü.
  bool get hasRating => reviewCount > 0;

  factory EmployerStats.fromJson(Map<String, dynamic> json) {
    final memberSince = json['memberSince'];

    return EmployerStats(
      userId: '${json['userId']}',
      jobsPosted: (json['jobsPosted'] as num?)?.toInt() ?? 0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      memberSince: memberSince is String
          ? DateTime.tryParse(memberSince)?.toLocal()
          : null,
    );
  }
}
