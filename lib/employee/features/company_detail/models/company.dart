import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/gallery_image.dart';

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

  /// Tanınmayan değerde [CompanyType.other].
  static CompanyType fromCode(Object? value) {
    return CompanyType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => CompanyType.other,
    );
  }
}

/// Şirket (`CompanyDto`); iki uygulama kullanıyor. İşverene özel yazma uçları
/// `b_company_service`'te.
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

  final String? logoUrl;

  final String? phoneNumber;
  final String? website;
  final String? description;

  /// Kurulurken zorunlu, sonradan değişmez.
  final String? taxNumber;

  final CompanyType? type;
  final CanonicalAddress? address;

  /// Şirket detayı görselleri gövdesinde taşıyor; ayrı istek gerekmiyor.
  final List<GalleryImage> images;

  final int followerCount;

  /// Sunucudaki alan `following`.
  final bool isFollowing;

  /// Onaysız şirket adına ilan yayınlanamaz. Sunucuda alan `approved`.
  final bool isApproved;

  /// Kapak; yoksa galerinin ilki.
  GalleryImage? get coverImage {
    for (final image in images) {
      if (image.isCover) return image;
    }
    return images.isEmpty ? null : images.first;
  }

  /// [images] galeri uçları için: onlar `Company` değil liste döndürüyor.
  Company copyWith({
    bool? isApproved,
    bool? isFollowing,
    int? followerCount,
    List<GalleryImage>? images,
  }) {
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
      images: images ?? this.images,
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
          ? CanonicalAddress.fromJson(address)
          : null,
      images: images is List
          ? images
                .whereType<Map<String, dynamic>>()
                .map(GalleryImage.fromJson)
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
