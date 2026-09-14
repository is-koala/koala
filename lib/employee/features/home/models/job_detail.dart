import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/models/canonical_address.dart';

/// İlanı açan kişi. Backend `SafeUserDto` karşılığı.
class JobCreator {
  const JobCreator({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.username,
    this.profilePictureUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? username;
  final String? profilePictureUrl;

  String get fullName => '$firstName $lastName'.trim();

  factory JobCreator.fromJson(Map<String, dynamic> json) {
    return JobCreator(
      id: '${json['id']}',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      username: json['username'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'username': username,
    'profilePictureUrl': profilePictureUrl,
  };
}

/// İlana bağlı şirket. Backend `OnlyCompanyDto` karşılığı.
///
/// `company_detail/models/company.dart` ile karıştırılmamalı: o sahte şirket
/// servisinin modeli ve alan adları farklı (`logo` ↔ `logoUrl`). Şirket detay
/// sayfası gerçek uca bağlandığında ikisi birleşecek.
class JobCompany {
  const JobCompany({
    required this.id,
    required this.name,
    this.logoUrl,
    this.email,
    this.phoneNumber,
    this.website,
    this.description,
    this.address,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? email;
  final String? phoneNumber;
  final String? website;
  final String? description;
  final CanonicalAddress? address;

  factory JobCompany.fromJson(Map<String, dynamic> json) {
    final address = json['address'];

    return JobCompany(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      description: json['description'] as String?,
      address: address is Map<String, dynamic>
          ? CanonicalAddress.fromJson(address)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logoUrl': logoUrl,
    'email': email,
    'phoneNumber': phoneNumber,
    'website': website,
    'description': description,
    'address': address?.toJson(),
  };
}

/// Bir iş ilanının tam hâli.
///
/// `GET /jobs/{jobId}` yanıtındaki `JobDetailDto`'nun karşılığı. Liste yanıtı
/// ([Job]) bu alanları taşımadığı için detay ekranı ilana dokunulduğunda ayrı
/// bir istek atıyor.
class JobDetail {
  const JobDetail({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.employerType,
    required this.salaryType,
    required this.price,
    required this.status,
    this.description,
    this.duties,
    this.sector,
    this.position,
    this.dressCode,
    this.minAge,
    this.maxAge,
    this.insuranceRequired = false,
    this.experienceRequired = false,
    this.startDateTime,
    this.endDateTime,
    this.address,
    this.addressPrecision = AddressPrecision.approximate,
    this.creator,
    this.company,
    this.createdAt,
    this.headcount,
    this.hiredCount = 0,
  });

  final String id;
  final String title;
  final JobCategory category;
  final JobType type;
  final JobEmployerType employerType;
  final SalaryType salaryType;
  final double price;
  final JobStatus status;

  final String? description;
  final String? duties;
  final String? sector;
  final String? position;
  final String? dressCode;

  /// Yaş aralığı. Backend `int` döndürüyor ve `0` "sınır yok" demek; burada
  /// `null`'a çevriliyor ki arayüz satırı hiç çizmesin.
  final int? minAge;
  final int? maxAge;

  final bool insuranceRequired;
  final bool experienceRequired;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final CanonicalAddress? address;

  /// [address] alanlarının hangi kesinlikte geldiği.
  ///
  /// `APPROXIMATE` yanıtta sunucu sokak, bina, kat, daire ve posta kodunu
  /// zaten siliyor, koordinatı da yuvarlıyor; yani bayrak bir sızıntıyı tek
  /// başına engellemiyor. Ekranda ne yaptığı ayrı ve önemli: kalan metni
  /// "Konum" diye sunmak, adresin bundan ibaret olduğunu ima ederdi.
  final AddressPrecision addressPrecision;

  final JobCreator? creator;
  final JobCompany? company;
  final DateTime? createdAt;

  /// Aranan kişi sayısı; sunucu göndermediyse `null` ve satır çizilmiyor.
  final int? headcount;

  /// Şimdiye kadar işe alınan kişi sayısı.
  final int hiredCount;

  /// Kartın ikinci satırı; [Job.subtitle] ile aynı kural.
  String get subtitle {
    if (position != null && position!.isNotEmpty) return position!;
    if (sector != null && sector!.isNotEmpty) return sector!;
    return category.displayName;
  }

  /// İlanı açan tarafın görünen adı: şirket varsa şirket, yoksa kişi.
  String? get employerName => company?.name ?? creator?.fullName;

  /// Adresin tek satırlık hâli: açık adres varsa o, yoksa ilçe/il.
  String? get addressLabel {
    final line = address?.displayAddress;
    if (line != null && line.isNotEmpty) return line;
    return address?.shortLabel;
  }

  factory JobDetail.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    final creator = json['creator'];
    final company = json['company'];

    return JobDetail(
      id: '${json['id']}',
      title: json['title'] as String? ?? '',
      category: JobCategory.fromJson(
        (json['category'] as Map<String, dynamic>?) ?? const {},
      ),
      type: JobType.fromCode(json['type']),
      employerType: JobEmployerType.fromCode(json['employerType']),
      salaryType: SalaryType.fromCode(json['salaryType']),
      price: (json['salary'] as num?)?.toDouble() ?? 0,
      status: JobStatus.fromCode(json['status']),
      description: json['description'] as String?,
      duties: json['duties'] as String?,
      sector: json['sector'] as String?,
      position: json['position'] as String?,
      dressCode: json['dressCode'] as String?,
      minAge: _ageOrNull(json['minAge']),
      maxAge: _ageOrNull(json['maxAge']),
      insuranceRequired: json['insuranceRequired'] as bool? ?? false,
      experienceRequired: json['experienceRequired'] as bool? ?? false,
      startDateTime: _parseDate(json['startDateTime']),
      endDateTime: _parseDate(json['endDateTime']),
      address: address is Map<String, dynamic>
          ? CanonicalAddress.fromJson(address)
          : null,
      addressPrecision: AddressPrecision.fromCode(json['addressPrecision']),
      creator: creator is Map<String, dynamic>
          ? JobCreator.fromJson(creator)
          : null,
      company: company is Map<String, dynamic>
          ? JobCompany.fromJson(company)
          : null,
      createdAt: _parseDate(json['createdAt']),
      headcount: (json['headcount'] as num?)?.toInt(),
      hiredCount: (json['hiredCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.toJson(),
    'type': type.code,
    'employerType': employerType.code,
    'salaryType': salaryType.code,
    'salary': price,
    'status': status.code,
    'description': description,
    'duties': duties,
    'sector': sector,
    'position': position,
    'dressCode': dressCode,
    'minAge': minAge,
    'maxAge': maxAge,
    'insuranceRequired': insuranceRequired,
    'experienceRequired': experienceRequired,
    'startDateTime': startDateTime?.toIso8601String(),
    'endDateTime': endDateTime?.toIso8601String(),
    'address': address?.toJson(),
    'addressPrecision': addressPrecision.code,
    'creator': creator?.toJson(),
    'company': company?.toJson(),
    'createdAt': createdAt?.toIso8601String(),
    'headcount': headcount,
    'hiredCount': hiredCount,
  };

  static int? _ageOrNull(Object? value) =>
      value is num && value > 0 ? value.toInt() : null;

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
