import 'package:koala/employee/features/auth/models/user_address.dart';

/// Şirketin hukuki türü. Backend `CompanyType` enum'ının birebir karşılığı.
///
/// Sunucu sekiz değer tanıyor; `employee/features/company_detail`'deki sahte
/// `CompanyType` yalnızca "bireysel/kurumsal" biliyor ve gerçek uca uymuyor.
enum BCompanyType {
  soleProprietorship('SOLE_PROPRIETORSHIP', 'Şahıs Şirketi'),
  limited('LIMITED', 'Limited Şirket'),
  corporation('CORPORATION', 'Anonim Şirket'),
  nonProfit('NON_PROFIT', 'Kâr Amacı Gütmeyen'),
  government('GOVERNMENT', 'Kamu Kurumu'),
  startup('STARTUP', 'Girişim'),
  agency('AGENCY', 'Ajans'),
  other('OTHER', 'Diğer');

  const BCompanyType(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan değerde [BCompanyType.other]; backend enum'a yeni bir tür
  /// eklerse uygulama patlamasın.
  static BCompanyType fromCode(Object? value) {
    return BCompanyType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => BCompanyType.other,
    );
  }
}

/// İşverenin şirketi. `GET /companies/{id}` yanıtındaki `CompanyDto`.
///
/// `employee/features/company_detail/models/company.dart` ile
/// karıştırılmamalı: o sahte şirket servisinin modeli ve alan adları
/// backend'inkiyle uyuşmuyor (`logo` ↔ `logoUrl`, `address.city` ↔
/// `address.cityName`, iki değerlik bir `CompanyType`). Şirket detay ekranı
/// da gerçek uca bağlandığında ikisi birleşecek; `b_` öneki o güne kadar iki
/// modeli ayırt etmek için.
class BCompany {
  const BCompany({
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
    this.followerCount = 0,
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

  final BCompanyType? type;
  final UserAddress? address;

  /// Şirketi takip eden kullanıcı sayısı.
  final int followerCount;

  /// Şirket onaylanmış mı. Onaysız şirket adına ilan yayınlanamıyor.
  ///
  /// TODO(backend): `CompanyDto` bu alanı döndürmüyor — `Company` entity'sinde
  /// `isApproved` var ama yanıta konmamış. Bilgi bugün `/users/me`'deki
  /// `CompanyMembershipDto.approved`'dan geliyor (o alan da şirketin onayını
  /// taşıyor, üyeliğinkini değil), o yüzden burası dışarıdan besleniyor.
  final bool isApproved;

  BCompany copyWith({bool? isApproved}) {
    return BCompany(
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
      followerCount: followerCount,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  factory BCompany.fromJson(Map<String, dynamic> json) {
    final address = json['address'];

    return BCompany(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      logoUrl: json['logoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      description: json['description'] as String?,
      taxNumber: json['taxNumber'] as String?,
      type: json['type'] == null ? null : BCompanyType.fromCode(json['type']),
      address: address is Map<String, dynamic>
          ? UserAddress.fromJson(address)
          : null,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      isApproved: json['isApproved'] as bool? ?? false,
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
    'isApproved': isApproved,
  };
}
