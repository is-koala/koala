import 'package:koala/employee/features/auth/models/user_address.dart';
import 'package:koala/employee/features/company_detail/models/company_image.dart';

/// Şirketin hukuki türü. Backend `CompanyType` enum'ının birebir karşılığı.
enum CompanyType {
  soleProprietorship('SOLE_PROPRIETORSHIP', 'Şahıs Şirketi'),
  limited('LIMITED', 'Limited Şirket'),
  corporation('CORPORATION', 'Anonim Şirket'),
  nonProfit('NON_PROFIT', 'Kâr Amacı Gütmeyen'),
  government('GOVERNMENT', 'Kamu Kurumu'),
  startup('STARTUP', 'Girişim'),
  agency('AGENCY', 'Ajans'),
  other('OTHER', 'Diğer');

  const CompanyType(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan değerde [CompanyType.other]; backend enum'a yeni bir tür
  /// eklerse uygulama patlamasın.
  static CompanyType fromCode(Object? value) {
    return CompanyType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => CompanyType.other,
    );
  }
}

/// Bir şirket. `GET /companies/{id}` yanıtındaki `CompanyDto`.
///
/// **İki uygulama da bunu kullanıyor.** Çalışan tarafı şirket detayını
/// okuyor, işveren tarafı kendi şirketini okuyup güncelliyor. Model çalışan
/// tarafında duruyor çünkü sohbette olduğu gibi paylaşılan alan modelleri
/// burada toplanıyor; işverene özel **yazma** uçları `b_company_service`'te
/// kalıyor.
class Company {
  const Company({
    required this.id,
    required this.name,
    this.email,
    this.logoUrl,
    this.phoneNumber,
    this.website,
    this.description,
    this.taxNumber,
    this.type,
    this.address,
    this.images = const [],
    this.followerCount = 0,
    this.isFollowing = false,
    this.isApproved = false,
  });

  final String id;
  final String name;
  final String? email;

  /// Logonun R2 bağlantısı; yüklenmemişse `null`.
  final String? logoUrl;

  final String? phoneNumber;
  final String? website;
  final String? description;

  /// Vergi numarası. Şirket kurulurken zorunlu, sonradan değiştirilemiyor.
  final String? taxNumber;

  final CompanyType? type;
  final UserAddress? address;

  /// Şirketin galerisi.
  ///
  /// Ayrı bir uç var (`GET /companies/{id}/images`) ama şirket detayı zaten
  /// görselleri gövdesinde taşıyor; ikinci bir istek atmaya gerek yok.
  final List<CompanyImage> images;

  /// Şirketi takip eden kullanıcı sayısı.
  final int followerCount;

  /// Oturum sahibi bu şirketi takip ediyor mu. Sunucudaki alan `following`.
  final bool isFollowing;

  /// Şirket onaylanmış mı. Onaysız şirket adına ilan yayınlanamıyor.
  ///
  /// Sunucudaki alan adı `approved`, `isApproved` değil — `/users/me`'deki
  /// `CompanyMembershipDto.approved` ile aynı kavram, API'de tek ad taşısın
  /// diye böyle. Dart tarafında ad `isApproved` kalıyor çünkü bir bayrağın
  /// okunuşu öyle.
  final bool isApproved;

  /// Kapak görseli; yoksa galerinin ilki, o da yoksa `null`.
  CompanyImage? get coverImage {
    for (final image in images) {
      if (image.isCover) return image;
    }
    return images.isEmpty ? null : images.first;
  }

  Company copyWith({bool? isApproved, bool? isFollowing, int? followerCount}) {
    return Company(
      id: id,
      name: name,
      email: email,
      logoUrl: logoUrl,
      phoneNumber: phoneNumber,
      website: website,
      description: description,
      taxNumber: taxNumber,
      type: type,
      address: address,
      images: images,
      followerCount: followerCount ?? this.followerCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    final images = json['images'];

    return Company(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      logoUrl: json['logoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      description: json['description'] as String?,
      taxNumber: json['taxNumber'] as String?,
      type: json['type'] == null ? null : CompanyType.fromCode(json['type']),
      address: address is Map<String, dynamic>
          ? UserAddress.fromJson(address)
          : null,
      images: images is List
          ? images
                .whereType<Map<String, dynamic>>()
                .map(CompanyImage.fromJson)
                .toList()
          : const [],
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['following'] as bool? ?? false,
      isApproved: json['approved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'logoUrl': logoUrl,
    'phoneNumber': phoneNumber,
    'website': website,
    'description': description,
    'taxNumber': taxNumber,
    'type': type?.code,
    'address': address?.toJson(),
    'followerCount': followerCount,
    'following': isFollowing,
    'approved': isApproved,
  };
}
