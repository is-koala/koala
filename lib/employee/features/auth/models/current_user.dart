import 'package:koala/employee/features/auth/models/company_membership.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/auth/models/user_address.dart';

/// Kullanıcının cinsiyeti. Backend `Gender` enum'ının birebir karşılığı.
enum Gender {
  male('MALE', 'Erkek'),
  female('FEMALE', 'Kadın'),
  notSpecified('NOT_SPECIFIED', 'Belirtilmemiş');

  const Gender(this.code, this.displayName);

  /// Backend'e gidip gelen değer.
  final String code;

  /// Arayüzde gösterilen Türkçe karşılık.
  final String displayName;

  /// Tanınmayan ya da boş değerde [Gender.notSpecified] döner; backend
  /// ileride yeni bir değer eklerse uygulama patlamasın.
  static Gender fromCode(Object? value) {
    return Gender.values.firstWhere(
      (gender) => gender.code == value,
      orElse: () => Gender.notSpecified,
    );
  }
}

/// `/users/me` yanıtının tamamı.
///
/// Hem oturum (router'ın baktığı [isEmployer]) hem profil ekranı bu modeli
/// okuyor: uç tek yanıt döndürdüğü için ikiye bölmenin anlamı yok.
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

  /// TC kimlik numarası. Kimlik doğrulaması yapılana kadar `null`.
  final String? tcIdentityNumber;

  /// Profil başlığında adın altında görünen ünvan.
  final String? jobTitle;

  /// Profildeki "Hakkımda" metni.
  final String? about;

  /// Kullanıcının yetkinlikleri; backend'de düz metin.
  final String? qualifications;

  /// İlgi alanları; backend'de düz metin.
  final String? interests;

  /// Maskelenmiş IBAN (`TR** **** 1234`). Banka hesabı tanımlı değilse null.
  final String? maskedIban;

  /// Yüklenmiş özgeçmişin bağlantısı; yoksa null.
  final String? cvUrl;

  /// İş deneyimleri, yeniden eskiye.
  final List<Experience> experiences;

  /// Öğrenim kayıtları.
  final List<Education> educations;

  /// Kazanılmış rozetler. Backend rozeti geri almıyor, liste yalnızca büyür.
  final List<UserBadge> badges;

  /// Kayıtlı adres. Profil başlığındaki konum satırı buradan çiziliyor.
  final UserAddress? address;

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

  /// İlan açarken kullanılacak şirket.
  ///
  /// Onaysız üyelik sayılmıyor: backend onaysız şirket adına ilan açtırmıyor.
  /// `null` dönmesi "bireysel ilan açılacak" demek, hata değil.
  CompanyMembership? get activeCompany {
    for (final company in companies) {
      if (company.approved) return company;
    }
    return null;
  }

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
          ? UserAddress.fromJson(address)
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

  /// Dizi alanlarını ayrıştırır. Alan hiç gelmezse ya da beklenmedik bir
  /// tipteyse boş liste dönüyor; profil ekranı bölümü çizmiyor.
  static List<T> _listOf<T>(
    Object? value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return value is List
        ? value.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : const [];
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
