import 'package:koala/business/features/home/models/company_contact.dart';

/// `/users/me` yanıtındaki şirket üyeliği.
///
/// İş verenin hangi şirket adına ilan açabileceğini bu liste söylüyor.
class CompanyMembership {
  const CompanyMembership({
    required this.companyId,
    required this.companyName,
    required this.approved,
    this.role,
  });

  final String companyId;

  final String companyName;

  /// Şirket onaylanmış mı. Onaysız şirket için ilan açılamıyor.
  final bool approved;

  /// Kullanıcının şirketteki rolü. Backend `CompanyContactRole`: `ADMIN`
  /// veya `STAFF`. Düz metin tutuluyor çünkü `/users/me` bu alanı
  /// serbest bırakıyor; görünen ad [CompanyContactRole] üzerinden.
  final String? role;

  bool get isAdmin => role == CompanyContactRole.admin.code;

  factory CompanyMembership.fromJson(Map<String, dynamic> json) {
    return CompanyMembership(
      companyId: json['companyId'] as String,
      companyName: json['companyName'] as String? ?? '',
      approved: json['approved'] as bool? ?? false,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'approved': approved,
      'role': role,
    };
  }
}
