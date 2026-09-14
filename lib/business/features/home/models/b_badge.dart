import 'package:koala/product/network/json_field.dart';

/// Bir kullanıcının kazandığı rozet.
///
/// `GET /users/{userId}/badges` yanıtındaki `BadgeDto` karşılığı; aynı liste
/// koala-backend#282 ile `PublicProfileDto.badges` içinde de geliyor.
/// Kazanılan rozet geri alınmıyor, o yüzden [earnedAt] tek zaman damgası.
class BBadge {
  const BBadge({
    required this.code,
    required this.name,
    this.family,
    this.tier,
    this.description,
    this.iconUrl,
    this.earnedAt,
  });

  final String code;

  /// Backend `BadgeFamily` kodu (`GEZGIN`, `RATING`, `IDENTITY`,
  /// `PUNCTUALITY`, `OTHER`), olduğu gibi. Ekran aileye göre karar vermiyor.
  final String? family;

  /// Backend `BadgeTier` kodu; `NONE` kademesiz rozet demek.
  final String? tier;

  /// Kullanıcıya gösterilen ad; sunucu Türkçe döndürüyor.
  final String name;

  final String? description;

  /// Rozet görseli; sunucu yüklememişse `null` ve genel ikon çiziliyor.
  final String? iconUrl;

  final DateTime? earnedAt;

  /// Kademe etiketi: "Bronz", "Gümüş", "Altın". Kademesiz rozette `null`.
  String? get tierLabel => switch (tier) {
    'BRONZE' => 'Bronz',
    'SILVER' => 'Gümüş',
    'GOLD' => 'Altın',
    _ => null,
  };

  factory BBadge.fromJson(Map<String, dynamic> json) {
    return BBadge(
      code: '${json['code']}',
      name: json['name'] as String? ?? '',
      family: json['family'] as String?,
      tier: json['tier'] as String?,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      earnedAt: JsonField.dateOrNull(json['earnedAt']),
    );
  }

  /// Düz JSON listesinden rozetler; liste değilse boş.
  static List<BBadge> listFromJson(Object? data) => data is List
      ? data.whereType<Map<String, dynamic>>().map(BBadge.fromJson).toList()
      : const [];
}
