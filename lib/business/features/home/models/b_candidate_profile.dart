import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';

/// Adayın profili, işverenin istediği özet alanlarla (`GET /users/{userId}`).
/// Alanlar opsiyonel: eski sunucuda `null` kalıyor, ekran puan/rozeti ayrı
/// uçlardan çekiyor.
class BCandidateProfile {
  const BCandidateProfile({
    required this.profile,
    this.completedJobCount,
    this.ratingSummary,
    this.badges,
  });

  final PublicProfile profile;

  final int? completedJobCount;

  /// `reviewCount` yoksa `null`.
  final RatingSummary? ratingSummary;

  /// "Rozeti yok" (`[]`) ile "sunucu göndermedi" (`null`) farklı.
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

  /// `BigDecimal` sayı ya da dize gelebiliyor; tanınmayan değer 0.
  static double _decimal(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text) ?? 0,
    _ => 0,
  };
}
