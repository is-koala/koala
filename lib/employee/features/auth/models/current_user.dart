import 'package:koala/employee/features/auth/models/company_membership.dart';

/// `/users/me` yanıtının oturum için gereken kısmı.
///
/// Uç bundan fazlasını (doğum tarihi, cinsiyet, TC kimlik no, hakkında,
/// yetkinlikler, adres) da döndürüyor; profil ekranı bağlanırken o alanlar
/// profil feature'ının kendi modeline eklenecek.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profilePictureUrl,
    this.phoneNumber,
    this.isEmployer = false,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.identityVerified = false,
    this.roles = const [],
    this.companies = const [],
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePictureUrl;
  final String? phoneNumber;

  /// Kullanıcının iş veren olup olmadığı. Router hangi arayüzün açılacağına
  /// buna bakarak karar veriyor.
  final bool isEmployer;

  final bool emailVerified;
  final bool phoneVerified;

  /// Kimlik doğrulaması yapılmış mı. Ödeme akışının ön koşulu.
  final bool identityVerified;

  /// `ROLE_USER`, `ROLE_ADMIN` gibi yetki adları.
  final List<String> roles;

  /// Kullanıcının bağlı olduğu şirketler.
  final List<CompanyMembership> companies;

  String get fullName => '$firstName $lastName';

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    final companies = json['companies'];
    final roles = json['roles'];

    return CurrentUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePictureUrl: json['profilePictureUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      isEmployer: readEmployerFlag(json),
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      identityVerified: json['identityVerified'] as bool? ?? false,
      roles: roles is List ? roles.map((role) => '$role').toList() : const [],
      companies: companies is List
          ? companies
                .whereType<Map<String, dynamic>>()
                .map(CompanyMembership.fromJson)
                .toList()
          : const [],
    );
  }

  /// İş veren bayrağını okur.
  ///
  /// Anahtar adı backend'de `@JsonProperty("isEmployer")` ile sabitlendi;
  /// `/users/me` ve `/auth/verify-registration-token` aynı adı kullandığı
  /// için iki model de buradan okuyor.
  static bool readEmployerFlag(Map<String, dynamic> json) {
    final value = json['isEmployer'];
    return value is bool ? value : false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'phoneNumber': phoneNumber,
      'isEmployer': isEmployer,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'identityVerified': identityVerified,
      'roles': roles,
      'companies': companies.map((company) => company.toJson()).toList(),
    };
  }
}
