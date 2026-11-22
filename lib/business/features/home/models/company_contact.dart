import 'package:koala/employee/features/home/models/job_detail.dart';

enum CompanyContactRole {
  admin('ADMIN', 'Yönetici'),
  staff('STAFF', 'Çalışan');

  const CompanyContactRole(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan değer `null`: eski `OWNER`/`MANAGER` yetkili sanılmasın, rozet
  /// gizlenir.
  static CompanyContactRole? fromCode(Object? value) {
    for (final role in CompanyContactRole.values) {
      if (role.code == value) return role;
    }
    return null;
  }
}

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
