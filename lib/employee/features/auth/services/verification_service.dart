import 'package:flutter/foundation.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// `/verifications` uçları; e-posta/telefon değişince sunucu 6 haneli kod
/// gönderip bekliyor.
class VerificationService {
  VerificationService._(this._apiClient);

  static final VerificationService _instance = VerificationService._(
    ApiClient(),
  );

  factory VerificationService() => _instance;

  @visibleForTesting
  factory VerificationService.withClient(ApiClient apiClient) {
    return VerificationService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Kodla onaylar; başarıda değer uygulanır, kullanıcı tazelenmeli.
  /// - hatalı ya da süresi dolmuş → `400`, ekranda kalınır
  /// - başkasının (`403`) ya da olmayan (`404`) kayıt → ekran kapanır
  /// - zaten doğrulanmış → sessizce `200`
  Future<void> confirm(String verificationId, String token) {
    return _apiClient.postWithoutData(
      ApiPaths.verificationConfirm(verificationId),
      body: {'token': token},
    );
  }
}
