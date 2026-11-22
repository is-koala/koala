import 'package:flutter/foundation.dart';
import 'package:koala/product/features/account/models/notification_preference.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// `/users/me/notification-preferences` uçları.
class NotificationPreferenceService {
  NotificationPreferenceService._(this._apiClient);

  static final NotificationPreferenceService _instance =
      NotificationPreferenceService._(ApiClient());

  factory NotificationPreferenceService() => _instance;

  @visibleForTesting
  factory NotificationPreferenceService.withClient(ApiClient apiClient) {
    return NotificationPreferenceService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<List<NotificationPreference>> fetchAll() {
    return _apiClient.get<List<NotificationPreference>>(
      ApiPaths.currentUserNotificationPreferences,
      parse: _parseList,
    );
  }

  /// Yalnız [changes]'ı yazar, güncel tabloyu döndürür. İşlemsel kategoriyi
  /// kapatmak `400`.
  Future<List<NotificationPreference>> update(
    List<NotificationPreferenceWrite> changes,
  ) {
    return _apiClient.put<List<NotificationPreference>>(
      ApiPaths.currentUserNotificationPreferences,
      body: {
        'preferences': [for (final change in changes) change.toJson()],
      },
      parse: _parseList,
    );
  }

  static List<NotificationPreference> _parseList(Object? data) {
    return data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(NotificationPreference.fromJson)
              .toList()
        : const [];
  }
}
