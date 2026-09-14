import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';

/// Adayın herkese açık profili, işverenin ihtiyaç duyduğu özet alanlarla.
///
/// `GET /users/{userId}` tek istek; paylaşılan [PublicProfile] ve koala-
/// backend#282 ile aynı yanıta eklenen `completedJobCount`, `averageRating`,
/// `reviewCount`, `badges` alanları aynı JSON'dan birlikte okunuyor. Bu
/// alanlar [PublicProfile]'a eklenmedi: o model çalışan tarafına ait ve
/// işveren ekranı dışında okuyanı yok.
///
/// Alanların hepsi **opsiyonel**: eski sunucuda `null` kalıyor ve ekran
/// puanı/rozeti mevcut uçlardan (`/rating-summary`, `/badges`) çekiyor;
/// tamamlanan iş sayısının başka bir kaynağı yok, o satır o zaman çizilmiyor.
class BCandidateProfile {
  const BCandidateProfile({
    required this.profile,
    this.completedJobCount,
    this.ratingSummary,
    this.badges,
  });

  final PublicProfile profile;

  /// İşçi olarak tamamladığı iş sayısı; sunucu göndermiyorsa `null`.
  final int? completedJobCount;

  /// Profil yanıtındaki puan özeti; `reviewCount` alanı yoksa `null`.
  /// `/users/{id}/rating-summary` ile aynı kaynaktan geliyor.
  final RatingSummary? ratingSummary;

  /// Profil yanıtındaki rozetler; alan yoksa `null`, boş listeyse `[]`.
  /// "Rozeti yok" ile "sunucu göndermedi" farklı şeyler.
  final List<UserBadge>? badges;

  factory BCandidateProfile.fromJson(Map<String, dynamic> json) {
    final profile = PublicProfile.fromJson(json);
    final reviewCount = json['reviewCount'];
    final badges = json['badges'];

    return BCandidateProfile(
      profile: profile,
      completedJobCount: (json['completedJobCount'] as num?)?.toInt(),
      ratingSummary: reviewCount is num
          ? RatingSummary(
              userId: profile.id,
              reviewCount: reviewCount.toInt(),
              averageRating: _decimal(json['averageRating']),
            )
          : null,
      badges: badges is List ? _badges(badges) : null,
    );
  }

  static List<UserBadge> _badges(List<dynamic> data) =>
      data.whereType<Map<String, dynamic>>().map(UserBadge.fromJson).toList();

  /// `averageRating` sunucuda `BigDecimal`; JSON'da sayı ya da dize olarak
  /// gelebiliyor. İkisi de okunuyor, tanınmayan değer 0.
  static double _decimal(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text) ?? 0,
    _ => 0,
  };
}
