import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/company_contact.dart';
import 'package:koala/business/features/home/models/company_contact_invitation.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';

/// Şirket yetkilileri ve davet uçları.
class CompanyContactService {
  CompanyContactService._(this._apiClient);

  static final CompanyContactService _instance = CompanyContactService._(
    ApiClient(),
  );

  factory CompanyContactService() => _instance;

  @visibleForTesting
  factory CompanyContactService.withClient(ApiClient apiClient) {
    return CompanyContactService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<List<CompanyContact>> fetchContacts(String companyId) {
    return _apiClient.get<List<CompanyContact>>(
      ApiPaths.companyContacts(companyId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(CompanyContact.fromJson)
                .toList()
          : const [],
    );
  }

  Future<void> inviteContact(
    String companyId, {
    required String email,
    required CompanyContactRole role,
  }) {
    return _apiClient.postWithoutData(
      ApiPaths.companyContactInvitations(companyId),
      body: {'email': email, 'role': role.code},
    );
  }

  Future<void> removeContact(String companyId, String userId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.companyContact(companyId, userId),
    );
  }

  Future<CompanyContactInvitation> fetchInvitation(String invitationId) {
    return _apiClient.get<CompanyContactInvitation>(
      ApiPaths.contactInvitation(invitationId),
      parse: (data) =>
          CompanyContactInvitation.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<CompanyContactInvitation> answerInvitation(
    String invitationId, {
    required bool accepted,
  }) {
    return _apiClient.post<CompanyContactInvitation>(
      ApiPaths.contactInvitation(invitationId),
      body: {'accepted': accepted},
      parse: (data) =>
          CompanyContactInvitation.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Sunucu kodunu kullanıcıya gösterilecek metne çevirir.
  ///
  /// Yönlendirme `errorCode` üzerinden: 404 hem "kullanıcı yok" hem
  /// "davet size ait değil" olabiliyor, 409 hem "zaten yetkili" hem
  /// "bekleyen davet" hem "son yönetici".
  static String messageFor(ApiException error) {
    switch (error.errorCode) {
      case 'USER_NOT_FOUND_BY_EMAIL':
        return 'Kullanıcı bulunamadı';
      case 'USER_ALREADY_A_CONTACT':
        return 'Bu kullanıcı zaten yetkili';
      case 'USER_MUST_VERIFY_IDENTITY':
        return 'Kullanıcı önce kimliğini doğrulamalı';
      case 'COMPANY_CONTACT_INVITATION_ALREADY_PENDING':
        return 'Bu kişiye zaten bekleyen bir davet var';
      case 'COMPANY_CONTACT_INVITATION_NOT_FOUND':
      case 'USER_NOT_ASSOCIATED_WITH_COMPANY':
        return 'Davet bulunamadı ya da size ait değil.';
      case 'INVITATION_ALREADY_ANSWERED':
        return 'Bu davet zaten cevaplanmış';
      case 'COMPANY_LAST_ADMIN_CANNOT_BE_REMOVED':
        return 'Son yönetici çıkarılamaz';
    }
    if (error.fieldErrors.isNotEmpty) return error.fieldErrors.first.message;
    return error.message;
  }
}
