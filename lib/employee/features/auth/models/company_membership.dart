import 'package:koala/business/features/home/models/company_contact.dart';

/// `/users/me`'deki şirket üyeliği; işveren hangi şirket adına ilan açabilir.
class CompanyMembership {
  const CompanyMembership({
    required this.companyId,
    required this.companyName,
    required this.approved,
    this.role,
  });

  final String companyId;

  final String companyName;

  /// Onaysız şirket için ilan açılamaz.
  final bool approved;

  /// `ADMIN` ya da `STAFF`; düz metin, `/users/me` alanı serbest bırakıyor.
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
