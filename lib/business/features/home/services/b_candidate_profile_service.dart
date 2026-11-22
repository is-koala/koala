import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/b_candidate_profile.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Aday profilinin işveren tarafındaki okumaları; aynı yanıttaki tamamlanan iş,
/// puan ve rozetler de okunuyor.
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

  /// Tam adres dönmez; `cvUrl` yalnız başvurulan ilanın işverenine dolu.
  Future<BCandidateProfile> fetchProfile(String userId) {
    return _apiClient.get<BCandidateProfile>(
      ApiPaths.publicProfile(userId),
      parse: (data) =>
          BCandidateProfile.fromJson(data! as Map<String, dynamic>),
    );
  }

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
