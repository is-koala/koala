import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Push token'ını sunucuya yazar ve siler; yalnız HTTP sözleşmesini bilir.
class PushTokenService {
  PushTokenService._(this._apiClient);

  static final PushTokenService _instance = PushTokenService._(ApiClient());

  factory PushTokenService() => _instance;

  factory PushTokenService.withClient(ApiClient apiClient) {
    return PushTokenService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<void> save(String token) {
    return _apiClient.putWithoutData(
      ApiPaths.currentUserPushToken,
      body: {'pushToken': token},
    );
  }

  Future<void> clear() {
    return _apiClient.deleteWithoutData(ApiPaths.currentUserPushToken);
  }
}
