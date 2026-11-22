/// İşverenin özet sayıları; şirkete değil **kişiye** bağlı.
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

  /// Kapanmışlar dâhil.
  final int jobsPosted;

  final int completedJobs;

  /// Değerlendirme yoksa `0`; [hasRating] ayırıyor.
  final double averageRating;

  final int reviewCount;

  final DateTime? memberSince;

  /// Değerlendirmesiz işverene "0.0" yazmak kötü puan gibi görünür.
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
