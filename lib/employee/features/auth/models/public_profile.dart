/// Bir kullanıcının herkese açık profili.
///
/// `GET /users/{userId}` yanıtındaki `PublicProfileDto`. [CurrentUser] ile
/// karıştırılmamalı: o oturum sahibinin tam kaydı, bu başkasının görebildiği
/// kadarı.
///
/// Sunucu bilerek kısıtlı döndürüyor:
/// - **Tam adres hiç gelmiyor**, yalnızca il ve ilçe.
/// - [cvUrl] ilişkiye bağlı — kişinin kendisi ya da o kişinin başvurduğu bir
///   ilanın işvereni görüyor, diğerlerinde `null`. İndirme yolu da ayrıca
///   sahiplik kontrolü yapıyor, yani adres sızsa bile dosya inmiyor.
/// - Uç oturum açmış kullanıcılara açık, anonime değil.
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
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? username;
  final String? profilePictureUrl;

  /// Kişinin mesleği; profil başlığında adın altında görünüyor.
  final String? jobTitle;

  /// "Hakkında" metni.
  final String? about;

  final String? cityName;
  final String? districtName;

  /// Özgeçmişin indirme adresi; yoksa ya da görme yetkisi yoksa `null`.
  final String? cvUrl;

  String get fullName => '$firstName $lastName'.trim();

  /// `Çankaya/Ankara`. İkisi de boşsa `null`.
  String? get locationLabel {
    final parts = [
      if (districtName != null && districtName!.isNotEmpty) districtName!,
      if (cityName != null && cityName!.isNotEmpty) cityName!,
    ];
    return parts.isEmpty ? null : parts.join('/');
  }

  /// Özgeçmiş görüntülenebilir mi.
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
    );
  }
}
