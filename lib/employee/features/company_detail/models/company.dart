import 'package:koala/employee/features/company_detail/models/address.dart';
import 'package:koala/employee/features/company_detail/models/company_image.dart';

/// Şirket tiplerini temsil eden enum
enum CompanyType { individual, corporate }

/// CompanyType için extension
extension CompanyTypeExtension on CompanyType {
  String get displayName {
    switch (this) {
      case CompanyType.individual:
        return 'Bireysel';
      case CompanyType.corporate:
        return 'Kurumsal';
    }
  }
}

class Company {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final CompanyImage? logo;
  final String? website;
  final String? description;
  final Address? address;
  final String? taxNumber;
  final CompanyType? type;
  final bool isApproved;

  const Company({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.logo,
    this.website,
    this.description,
    this.address,
    this.taxNumber,
    this.type,
    required this.isApproved,
  });

  /// JSON'dan model oluşturma
  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      logo: json['logo'] != null
          ? CompanyImage.fromJson(json['logo'] as Map<String, dynamic>)
          : null,
      website: json['website'] as String?,
      description: json['description'] as String?,
      address: json['address'] != null
          ? Address.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      taxNumber: json['taxNumber'] as String?,
      type: json['type'] != null
          ? CompanyType.values.firstWhere(
              (e) => e.name == (json['type'] as String).toLowerCase(),
              orElse: () => CompanyType.individual,
            )
          : null,
      isApproved: json['isApproved'] as bool? ?? false,
    );
  }

  /// Model'den JSON oluşturma
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'logo': logo?.toJson(),
      'website': website,
      'description': description,
      'address': address?.toJson(),
      'taxNumber': taxNumber,
      'type': type?.name,
      'isApproved': isApproved,
    };
  }
}
