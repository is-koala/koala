import 'package:flutter/foundation.dart';
import 'package:koala/product/models/user_block.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Engelleme uçları. Engel **iki yönlü**: iki taraf da birbirine yazamaz.
class UserBlockService {
  UserBlockService._(this._apiClient);

  static final UserBlockService _instance = UserBlockService._(ApiClient());

  factory UserBlockService() => _instance;

  @visibleForTesting
  factory UserBlockService.withClient(ApiClient apiClient) {
    return UserBlockService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Sunucunun `@Size(max = 512)` sınırı; aşan gerekçe engellemeyi düşürmesin.
  static const int reasonLimit = 512;

  /// Engeller. Gövde boş da olsa gönderiliyor (`{}`): uç gövdesiz isteğe `400`
  /// veriyor. İdempotent. [reason] yalnız moderasyona gidiyor.
  Future<void> block(String userId, {String? reason}) {
    final trimmed = reason?.trim() ?? '';
    final capped = trimmed.length > reasonLimit
        ? trimmed.substring(0, reasonLimit)
        : trimmed;

    // Boş gerekçe gövdeye konmuyor; gövdenin kendisi yine gidiyor.
    final String? sanitized = capped.isEmpty ? null : capped;
    final body = <String, dynamic>{'reason': ?sanitized};

    return _apiClient.postWithoutData(ApiPaths.userBlock(userId), body: body);
  }

  /// Engellenmemiş birinde de sessizce geçer.
  Future<void> unblock(String userId) {
    return _apiClient.deleteWithoutData(ApiPaths.userBlock(userId));
  }

  /// Sayfalı değil.
  Future<List<UserBlock>> fetchMyBlocks() {
    return _apiClient.get<List<UserBlock>>(
      ApiPaths.userBlocks,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(UserBlock.fromJson)
                .toList()
          : const [],
    );
  }
}
