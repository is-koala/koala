import 'package:koala/employee/features/home/models/job_detail.dart';

/// Şirket yetkilisinin rolü. Backend `CompanyContactRole` karşılığı.
enum CompanyContactRole {
  admin('ADMIN', 'Yönetici'),
  staff('STAFF', 'Çalışan');

  const CompanyContactRole(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan değer `null`: eski `OWNER`/`MANAGER` belgelerini yetkili
  /// sanmamak için. Arayüz o zaman rozeti gizler.
  static CompanyContactRole? fromCode(Object? value) {
    for (final role in CompanyContactRole.values) {
      if (role.code == value) return role;
    }
    return null;
  }
}

/// Şirketin bir yetkilisi. Backend `CompanyContactDto` karşılığı.
class CompanyContact {
  const CompanyContact({
    required this.id,
    required this.user,
    required this.role,
  });

  final String id;
  final JobCreator user;
  final CompanyContactRole role;

  factory CompanyContact.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return CompanyContact(
      id: '${json['id']}',
      user: JobCreator.fromJson(
        user is Map<String, dynamic> ? user : const <String, dynamic>{},
      ),
      role:
          CompanyContactRole.fromCode(json['role']) ?? CompanyContactRole.staff,
    );
  }
}
