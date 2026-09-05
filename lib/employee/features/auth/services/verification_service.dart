import 'package:flutter/foundation.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// `/verifications` uçlarının sarmalayıcısı.
///
/// `auth` altında duruyor çünkü doğrulama kaydını üreten uç de burada:
/// e-posta ya da telefon `PATCH /users/me` ile değiştirildiğinde sunucu
/// değeri yazmıyor, yeni adrese/numaraya 6 haneli bir kod gönderip bekleyen
/// doğrulamayı döndürüyor.
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

  /// Bekleyen doğrulamayı kullanıcının girdiği kodla onaylar.
  ///
  /// Başarılıysa yeni e-posta/telefon o anda uygulanıyor; çağıran taraf
  /// kullanıcıyı tazelemeli.
  ///
  /// Sunucunun hata haritası:
  /// - kod hatalı ya da süresi dolmuş → `400`, kullanıcı ekranda kalmalı
  /// - kayıt başkasına ait → `403`, kayıt yok → `404`; ikisinde de kod
  ///   girmenin anlamı kalmadığı için ekran kapanmalı
  /// - kayıt zaten doğrulanmış → sessizce `200`
  Future<void> confirm(String verificationId, String token) {
    return _apiClient.postWithoutData(
      ApiPaths.verificationConfirm(verificationId),
      body: {'token': token},
    );
  }
}
