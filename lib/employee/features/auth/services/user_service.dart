import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/profile_update_result.dart';
import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/models/canonical_address.dart';

/// `/users/me` uçları.
class UserService {
  UserService._(this._apiClient);

  static final UserService _instance = UserService._(ApiClient());

  factory UserService() => _instance;

  /// Testler ve [AuthService] aynı istemciyi paylaşsın diye.
  factory UserService.withClient(ApiClient apiClient) {
    return UserService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Uç yalnız başarı zarfı döndürüyor; ardından kullanıcı yeniden çekilmeli.
  Future<void> uploadProfilePicture(String filePath) {
    return _apiClient.putFileWithoutData(
      ApiPaths.currentUserProfilePicture,
      fieldName: 'image',
      filePath: filePath,
    );
  }

  Future<String> uploadCv(String filePath) {
    return _apiClient.putFile<String>(
      ApiPaths.currentUserCv,
      fieldName: 'file',
      filePath: filePath,
      parse: (data) => data! as String,
    );
  }

  Future<void> deleteCv() {
    return _apiClient.deleteWithoutData(ApiPaths.currentUserCv);
  }

  Future<CurrentUser> fetchCurrentUser() {
    return _apiClient.get<CurrentUser>(
      ApiPaths.currentUser,
      parse: (data) => CurrentUser.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Tam adres dönmez, `cvUrl` yalnız yetkiliye ([PublicProfile]).
  Future<PublicProfile> fetchPublicProfile(String userId) {
    return _apiClient.get<PublicProfile>(
      ApiPaths.publicProfile(userId),
      parse: (data) => PublicProfile.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Kısmi güncelleme: `null` alan gönderilmez; temizlemek için boş metin.
  /// - [email] / [phoneNumber] hemen yazılmaz; `pendingVerifications` doluysa
  ///   doğrulanana kadar eski değer geçerli.
  /// - Kimliği doğrulanmış kullanıcı ad, soyad ve doğum tarihini değiştiremez.
  Future<ProfileUpdateResult> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    DateTime? birthDate,
    Gender? gender,
    String? jobTitle,
    String? about,
    String? qualifications,
    String? interests,
    String? iban,
  }) {
    final body = <String, dynamic>{
      'firstName': ?firstName,
      'lastName': ?lastName,
      'phoneNumber': ?phoneNumber,
      'email': ?email,
      // İstek DTO'su `birthdate`, yanıt `birthDate`.
      if (birthDate != null) 'birthdate': birthDate.asLocalDate,
      'gender': ?gender?.code,
      'jobTitle': ?jobTitle,
      'about': ?about,
      'qualifications': ?qualifications,
      'interests': ?interests,
      // Ayrı IBAN ucu yok; yanıt maskeli döner.
      'iban': ?iban,
    };

    return _apiClient.patch<ProfileUpdateResult>(
      ApiPaths.currentUser,
      body: body,
      parse: (data) =>
          ProfileUpdateResult.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Parolayı değiştirir. Hataların hepsi `400` (belge `401` dese de); `401`'i
  /// oturum sonu sanma. **Başarıdan sonra bu cihaz dışındaki oturumlar
  /// kapanır**; yeniden giriş istenmemeli.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) {
    return _apiClient.putWithoutData(
      ApiPaths.currentUserPassword,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
    );
  }

  /// **Kart okunmadan önce** çağrılmalı; sonradan alınan sayı tekrar koruması
  /// sağlamaz. 8 bayt, base64, 10 dakika.
  Future<String> startIdentityChallenge() {
    return _apiClient.post<String>(
      ApiPaths.currentUserIdentityChallenge,
      parse: (data) => data! as String,
    );
  }

  /// Kimliği doğrular. Beş beyan alanı zorunlu; [evidence] bilerek isteğe
  /// bağlı: sunucuda çip doğrulaması kapalı, kanıtsız çağrı NFC'siz telefonda
  /// da çalışıyor. Başarıda kullanıcı tazelenmeli. [tcIdentityNumber] 11 hane,
  /// son hane çift.
  Future<void> verifyIdentity({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String tcIdentityNumber,
    required String tcDocumentNumber,
    ChipEvidence? evidence,
  }) {
    return _apiClient.postWithoutData(
      ApiPaths.currentUserIdentityVerification,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'birthDate': birthDate.asLocalDate,
        'tcIdentityNumber': tcIdentityNumber,
        'tcDocumentNumber': tcDocumentNumber,
        ...?evidence?.toJson(),
      },
    );
  }

  /// Toptan değiştirir; koordinat **zorunlu**.
  Future<CanonicalAddress> updateAddress(AddressWrite address) {
    return _apiClient.put<CanonicalAddress>(
      ApiPaths.currentUserAddress,
      body: address.toJson(),
      parse: (data) => CanonicalAddress.fromJson(data! as Map<String, dynamic>),
    );
  }
}
