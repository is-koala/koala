import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/b_candidate_profile.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Aday profilinin işveren tarafındaki okumaları.
///
/// Çalışan tarafındaki `UserService.fetchPublicProfile` aynı ucu okuyor ama
/// yalnızca [BCandidateProfile.profile]'ı çıkarıyor; işveren ekranı aynı
/// yanıttaki tamamlanan iş sayısını, puan özetini ve rozetleri de istiyor.
/// Puan ve yorumlar için `ReviewService` olduğu gibi kullanılıyor; burada
/// yalnızca o servislerin taşımadığı iki okuma var.
class BCandidateProfileService {
  BCandidateProfileService._(this._apiClient);

  static final BCandidateProfileService _instance = BCandidateProfileService._(
    ApiClient(),
  );

  factory BCandidateProfileService() => _instance;

  @visibleForTesting
  factory BCandidateProfileService.withClient(ApiClient apiClient) {
    return BCandidateProfileService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Adayın herkese açık profili ve aynı yanıttaki özet alanlar.
  ///
  /// Uç oturum açmış kullanıcıya açık; tam adres dönmüyor, `cvUrl` yalnızca
  /// adayın başvurduğu ilanın işverenine doluyor.
  Future<BCandidateProfile> fetchProfile(String userId) {
    return _apiClient.get<BCandidateProfile>(
      ApiPaths.publicProfile(userId),
      parse: (data) =>
          BCandidateProfile.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Adayın kazandığı rozetler, düz liste. Hiç rozeti yoksa boş.
  Future<List<UserBadge>> fetchBadges(String userId) {
    return _apiClient.get<List<UserBadge>>(
      ApiPaths.userBadges(userId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(UserBadge.fromJson)
                .toList()
          : const [],
    );
  }
}
