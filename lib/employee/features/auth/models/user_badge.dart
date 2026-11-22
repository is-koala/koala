import 'package:koala/product/constants/app_assets.dart';

enum BadgeFamily {
  gezgin('GEZGIN'),
  rating('RATING'),
  identity('IDENTITY'),
  punctuality('PUNCTUALITY'),
  other('OTHER');

  const BadgeFamily(this.code);

  final String code;

  static BadgeFamily fromCode(Object? value) {
    return BadgeFamily.values.firstWhere(
      (family) => family.code == value,
      orElse: () => BadgeFamily.other,
    );
  }
}

enum BadgeTier {
  bronze('BRONZE'),
  silver('SILVER'),
  gold('GOLD'),
  none('NONE');

  const BadgeTier(this.code);

  final String code;

  /// Kademesiz rozette `null`.
  String? get label => switch (this) {
    BadgeTier.bronze => 'Bronz',
    BadgeTier.silver => 'Gümüş',
    BadgeTier.gold => 'Altın',
    BadgeTier.none => null,
  };

  static BadgeTier fromCode(Object? value) {
    return BadgeTier.values.firstWhere(
      (tier) => tier.code == value,
      orElse: () => BadgeTier.none,
    );
  }
}

/// Kazanılmış rozet. Adı `Badge` değil: Material'inkiyle çakışıyor.
class UserBadge {
  const UserBadge({
    required this.code,
    required this.name,
    this.family = BadgeFamily.other,
    this.tier = BadgeTier.none,
    this.description,
    this.iconUrl,
    this.earnedAt,
  });

  final String code;
  final String name;
  final BadgeFamily family;
  final BadgeTier tier;
  final String? description;

  /// Önce [localAsset]'e bakılır; yoksa bu.
  final String? iconUrl;

  final DateTime? earnedAt;

  /// Uygulamada yalnız Gezgin altın/gümüş görseli var; diğerlerinde `null`,
  /// çağıran [iconUrl]'e düşer.
  String? get localAsset {
    if (family != BadgeFamily.gezgin) return null;

    return switch (tier) {
      BadgeTier.gold => AppAssets.badgeGold,
      BadgeTier.silver => AppAssets.badgeSilver,
      _ => null,
    };
  }

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    final earnedAt = json['earnedAt'];

    return UserBadge(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      family: BadgeFamily.fromCode(json['family']),
      tier: BadgeTier.fromCode(json['tier']),
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      earnedAt: earnedAt is String ? DateTime.tryParse(earnedAt) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'family': family.code,
      'tier': tier.code,
      'description': description,
      'iconUrl': iconUrl,
      'earnedAt': earnedAt?.toIso8601String(),
    };
  }
}
