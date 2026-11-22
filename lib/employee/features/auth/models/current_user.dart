import 'package:koala/employee/features/auth/models/company_membership.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/product/models/canonical_address.dart';

enum Gender {
  male('MALE', 'Erkek'),
  female('FEMALE', 'Kadın'),
  notSpecified('NOT_SPECIFIED', 'Belirtilmemiş');

  const Gender(this.code, this.displayName);

  final String code;

  final String displayName;

  /// Tanınmayan ya da boş değerde [Gender.notSpecified].
  static Gender fromCode(Object? value) {
    return Gender.values.firstWhere(
      (gender) => gender.code == value,
      orElse: () => Gender.notSpecified,
    );
  }
}

/// `/users/me` yanıtı; hem oturum ([isEmployer]) hem profil okuyor.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profilePictureUrl,
    this.phoneNumber,
    this.birthDate,
    this.gender = Gender.notSpecified,
    this.tcIdentityNumber,
    this.jobTitle,
    this.about,
    this.qualifications,
    this.interests,
    this.maskedIban,
    this.cvUrl,
    this.experiences = const [],
    this.educations = const [],
    this.badges = const [],
    this.address,
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

  final DateTime? birthDate;
  final Gender gender;

  /// Kimlik doğrulanana kadar `null`.
  final String? tcIdentityNumber;

  final String? jobTitle;

  final String? about;

  final String? qualifications;

  final String? interests;

  /// `TR** **** 1234`; hesap yoksa `null`.
  final String? maskedIban;

  final String? cvUrl;

  /// Yeniden eskiye.
  final List<Experience> experiences;

  final List<Education> educations;

  /// Backend rozeti geri almıyor.
  final List<UserBadge> badges;

  final CanonicalAddress? address;

  /// Router hangi arayüzün açılacağına buna bakıyor.
  final bool isEmployer;

  final bool emailVerified;
  final bool phoneVerified;

  /// Ödeme akışının ön koşulu.
  final bool identityVerified;

  final List<String> roles;

  final List<CompanyMembership> companies;

  String get fullName => '$firstName $lastName';

  /// İlan açarken kullanılacak onaylı şirket; `null` "bireysel ilan" demek.
  CompanyMembership? get activeCompany {
    for (final company in companies) {
      if (company.approved) return company;
    }
    return null;
  }

  /// Profilde gösterilecek şirket; onay bekleyeni de kapsıyor, yoksa kullanıcı
  /// kurduğu şirketi göremez.
  CompanyMembership? get primaryCompany =>
      companies.isEmpty ? null : companies.first;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    final companies = json['companies'];
    final roles = json['roles'];
    final address = json['address'];
    final birthDate = json['birthDate'];

    return CurrentUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePictureUrl: json['profilePictureUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      birthDate: birthDate is String ? DateTime.tryParse(birthDate) : null,
      gender: Gender.fromCode(json['gender']),
      tcIdentityNumber: json['tcIdentityNumber'] as String?,
      jobTitle: json['jobTitle'] as String?,
      about: json['about'] as String?,
      qualifications: json['qualifications'] as String?,
      interests: json['interests'] as String?,
      maskedIban: json['maskedIban'] as String?,
      cvUrl: json['cvUrl'] as String?,
      experiences: _listOf(json['experiences'], Experience.fromJson),
      educations: _listOf(json['educations'], Education.fromJson),
      badges: _listOf(json['badges'], UserBadge.fromJson),
      address: address is Map<String, dynamic>
          ? CanonicalAddress.fromJson(address)
          : null,
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

  /// Alan gelmezse ya da tipi beklenmedikse boş liste.
  static List<T> _listOf<T>(
    Object? value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return value is List
        ? value.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : const [];
  }

  /// Backend `@JsonProperty("isEmployer")` ile sabit; iki uç aynı adı
  /// kullandığı için iki model de buradan okuyor.
  static bool readEmployerFlag(Map<String, dynamic> json) {
    final value = json['isEmployer'];
    if (value is! bool) {
      throw const FormatException('Hesap türü boolean olarak gelmelidir.');
    }
    return value;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender.code,
      'tcIdentityNumber': tcIdentityNumber,
      'jobTitle': jobTitle,
      'about': about,
      'qualifications': qualifications,
      'interests': interests,
      'maskedIban': maskedIban,
      'cvUrl': cvUrl,
      'experiences': experiences.map((e) => e.toJson()).toList(),
      'educations': educations.map((e) => e.toJson()).toList(),
      'badges': badges.map((b) => b.toJson()).toList(),
      'address': address?.toJson(),
      'isEmployer': isEmployer,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'identityVerified': identityVerified,
      'roles': roles,
      'companies': companies.map((company) => company.toJson()).toList(),
    };
  }
}
