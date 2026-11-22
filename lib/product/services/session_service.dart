import 'package:flutter/foundation.dart';
import 'package:koala/product/models/session_detail.dart';
import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Açık oturum uçları (hesap düzeyinde).
class SessionService {
  SessionService._(this._apiClient);

  static final SessionService _instance = SessionService._(ApiClient());

  factory SessionService() => _instance;

  @visibleForTesting
  factory SessionService.withClient(ApiClient apiClient) {
    return SessionService._(apiClient);
  }

  final ApiClient _apiClient;

  /// İsteği atan oturum `current` ile işaretli.
  Future<List<UserSession>> fetchSessions() {
    return _apiClient.get<List<UserSession>>(
      ApiPaths.currentUserSessions,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(UserSession.fromJson)
                .toList()
          : const [],
    );
  }

  /// Oturum ayrıntısı. Başkasının ya da kapalı oturum `404`; eski sunucu da
  /// `404` veriyor ve ikisi ayrılmıyor.
  Future<SessionDetail> fetchDetail(String sessionId) {
    return _apiClient.get<SessionDetail>(
      ApiPaths.currentUserSession(sessionId),
      parse: (data) => SessionDetail.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Cihaza ad verir (`≤ 60`, boşsa `400`). Ad cihaza yazılıyor; ekrandaki ad
  /// oturum ayrıntısından geldiği için çağıran ayrıntıyı yeniden çeker.
  Future<void> renameDevice(String deviceId, String name) {
    return _apiClient.patch<void>(
      ApiPaths.currentUserDevice(deviceId),
      body: {'name': name},
      parse: (_) {},
    );
  }

  /// Başkasının oturumu `404`: kimlik sızmıyor.
  Future<void> revoke(String sessionId) {
    return _apiClient.delete<void>(
      ApiPaths.currentUserSession(sessionId),
      parse: (_) {},
    );
  }

  /// İsteği atan oturum **hariç** hepsini kapatır; kaç tane olduğunu döndürür.
  Future<int> revokeOthers() {
    return _apiClient.delete<int>(
      ApiPaths.currentUserSessions,
      parse: (data) => (data as num?)?.toInt() ?? 0,
    );
  }
}
