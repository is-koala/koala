/// Başkasının görebildiği profil (`PublicProfileDto`); oturum sahibinin tam
/// kaydı [CurrentUser]. Tam adres gelmez (il/ilçe); [cvUrl] yalnız kişinin
/// kendisine ya da başvurduğu ilanın işverenine dolu. Anonime kapalı.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.username,
    this.profilePictureUrl,
    this.jobTitle,
    this.about,
    this.cityName,
    this.districtName,
    this.cvUrl,
    this.reviewCount,
    this.averageRating,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? username;
  final String? profilePictureUrl;

  final String? jobTitle;

  final String? about;

  final String? cityName;
  final String? districtName;

  final String? cvUrl;

  /// Eski sunucuda `null`: "değerlendirme yok" ile "göndermedi" farklı,
  /// ikincide özet ayrı uçtan çekilir.
  final int? reviewCount;
  final double? averageRating;

  String get fullName => '$firstName $lastName'.trim();

  String? get locationLabel {
    final parts = [
      if (districtName != null && districtName!.isNotEmpty) districtName!,
      if (cityName != null && cityName!.isNotEmpty) cityName!,
    ];
    return parts.isEmpty ? null : parts.join('/');
  }

  bool get hasCv => cvUrl != null && cvUrl!.isNotEmpty;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      id: '${json['id']}',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      username: json['username'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      jobTitle: json['jobTitle'] as String?,
      about: json['about'] as String?,
      cityName: json['cityName'] as String?,
      districtName: json['districtName'] as String?,
      cvUrl: json['cvUrl'] as String?,
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      averageRating: _decimal(json['averageRating']),
    );
  }

  /// `BigDecimal` sayı ya da dize gelebiliyor; tanınmazsa `null`.
  static double? _decimal(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
}
