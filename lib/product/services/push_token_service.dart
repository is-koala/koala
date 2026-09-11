import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Cihaz push token'ını sunucuya yazar ve siler.
///
/// Kaynağı (FCM/APNs) [PushTokenSource] sağlar; bu servis yalnız HTTP
/// sözleşmesini bilir. #29 platform kurulumu bitmeden kaynak boş döner.
class PushTokenService {
  PushTokenService._(this._apiClient);

  static final PushTokenService _instance = PushTokenService._(ApiClient());

  factory PushTokenService() => _instance;

  /// Verilen istemciyle kurulu örnek.
  ///
  /// Testlerde sahte sunucuya bağlamak için, [AuthService] içinde de aynı
  /// istemciyi paylaşmak için kullanılıyor.
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
