import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:koala/product/network/api_config.dart';

/// Erişim ve yenileme token'ları. Yenileme token'ı 30 gün geçerli olduğu için
/// Keychain/Keystore'da; gizli olmayan oturum bayrağı prefs'te.
class TokenStorage {
  TokenStorage._internal()
    : _storage = const FlutterSecureStorage(),
      _apiOrigin = null;

  static final TokenStorage _instance = TokenStorage._internal();

  factory TokenStorage() => _instance;

  @visibleForTesting
  TokenStorage.withStorage(FlutterSecureStorage storage, {this._apiOrigin})
    : _storage = storage;

  final FlutterSecureStorage _storage;
  final String? _apiOrigin;

  static const String _accessTokenKey = 'koala_access_token';
  static const String _refreshTokenKey = 'koala_refresh_token';
  static const String _refreshExpiresAtKey = 'koala_refresh_expires_at';

  String get apiOrigin => _apiOrigin ?? ApiConfig.baseUrl;

  String _key(String name) => '${Uri.encodeComponent(apiOrigin)}:$name';

  Future<String?> readAccessToken() =>
      _storage.read(key: _key(_accessTokenKey));

  Future<String?> readRefreshToken() =>
      _storage.read(key: _key(_refreshTokenKey));

  /// Yoksa ya da bozuksa `null`.
  Future<DateTime?> readRefreshExpiresAt() async {
    final raw = await _storage.read(key: _key(_refreshExpiresAtKey));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    DateTime? refreshExpiresAt,
  }) async {
    await _storage.write(key: _key(_accessTokenKey), value: accessToken);
    await _storage.write(key: _key(_refreshTokenKey), value: refreshToken);
    if (refreshExpiresAt == null) {
      await _storage.delete(key: _key(_refreshExpiresAtKey));
    } else {
      await _storage.write(
        key: _key(_refreshExpiresAtKey),
        value: refreshExpiresAt.toIso8601String(),
      );
    }
  }

  /// `/auth/refresh-token` sonrası yenileme token'ı aynı kalıyor.
  Future<void> saveAccessToken(String accessToken) {
    return _storage.write(key: _key(_accessTokenKey), value: accessToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _key(_accessTokenKey));
    await _storage.delete(key: _key(_refreshTokenKey));
    await _storage.delete(key: _key(_refreshExpiresAtKey));
  }
}
