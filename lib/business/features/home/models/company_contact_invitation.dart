import 'package:koala/business/features/home/models/company_contact.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';

/// Davetin durumu. Backend `CompanyContactInvitationStatus` karşılığı.
enum CompanyContactInvitationStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  rejected('REJECTED');

  const CompanyContactInvitationStatus(this.code);

  final String code;

  static CompanyContactInvitationStatus fromCode(Object? value) {
    return CompanyContactInvitationStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => CompanyContactInvitationStatus.pending,
    );
  }
}

/// Şirket yetkili daveti. Backend `GetCompanyContactInvitationDto` karşılığı.
class CompanyContactInvitation {
  const CompanyContactInvitation({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.invitedBy,
    required this.invitedUser,
    required this.role,
    required this.status,
    this.invitedAt,
    this.answeredAt,
  });

  final String id;
  final String companyId;
  final String companyName;
  final JobCreator invitedBy;
  final JobCreator invitedUser;
  final CompanyContactRole role;
  final CompanyContactInvitationStatus status;
  final DateTime? invitedAt;
  final DateTime? answeredAt;

  bool get isPending => status == CompanyContactInvitationStatus.pending;

  factory CompanyContactInvitation.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final invitedBy = json['invitedBy'];
    final invitedUser = json['invitedUser'];

    return CompanyContactInvitation(
      id: '${json['id']}',
      companyId: company is Map<String, dynamic> ? '${company['id']}' : '',
      companyName: company is Map<String, dynamic>
          ? company['name'] as String? ?? ''
          : '',
      invitedBy: JobCreator.fromJson(
        invitedBy is Map<String, dynamic>
            ? invitedBy
            : const <String, dynamic>{},
      ),
      invitedUser: JobCreator.fromJson(
        invitedUser is Map<String, dynamic>
            ? invitedUser
            : const <String, dynamic>{},
      ),
      role:
          CompanyContactRole.fromCode(json['role']) ?? CompanyContactRole.staff,
      status: CompanyContactInvitationStatus.fromCode(json['status']),
      invitedAt: _parseDate(json['invitedAt']),
      answeredAt: _parseDate(json['answeredAt']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    return switch (value) {
      final String text => DateTime.tryParse(text),
      _ => null,
    };
  }
}
