import 'package:flutter/foundation.dart';
import 'package:koala/product/models/session_detail.dart';
import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Açık oturum uçları.
///
/// Hesap düzeyinde bir şey, uygulamaya özel değil — iki taraf da aynı
/// listeyi görüyor.
class SessionService {
  SessionService._(this._apiClient);

  static final SessionService _instance = SessionService._(ApiClient());

  factory SessionService() => _instance;

  @visibleForTesting
  factory SessionService.withClient(ApiClient apiClient) {
    return SessionService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Hesabın açık oturumları. İsteği atan oturum `current` ile işaretli.
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

  /// Tek bir oturumun ayrıntısı: IP, konum, oluşturulma anı, giriş sayısı
  /// ve son girişler.
  ///
  /// Başkasının ya da kapatılmış oturum `404` — bilinmeyen kimlikle aynı,
  /// oturum kimliği sızmıyor. Ucu tanımayan eski sunucu da `404` veriyor;
  /// çağıran ikisini ayırt edemiyor ve etmiyor: ayrıntı yoksa satır
  /// açılmıyor.
  Future<SessionDetail> fetchDetail(String sessionId) {
    return _apiClient.get<SessionDetail>(
      ApiPaths.currentUserSession(sessionId),
      parse: (data) => SessionDetail.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Cihaza özel ad verir (`≤ 60` karakter; boş ad `400`).
  ///
  /// Ad oturuma değil cihaza yazılıyor: aynı cihazın sonraki oturumları da
  /// bu adla listelenir. Dönen `DeviceDto` okunmuyor; çağıran ayrıntıyı
  /// yeniden çekiyor, çünkü ekranda gösterilen `deviceName` oturum
  /// ayrıntısından geliyor.
  Future<void> renameDevice(String deviceId, String name) {
    return _apiClient.patch<void>(
      ApiPaths.currentUserDevice(deviceId),
      body: {'name': name},
      parse: (_) {},
    );
  }

  /// Tek bir oturumu kapatır.
  ///
  /// Başkasının oturumunu kapatmaya çalışmak `404` — sunucu "yok" diyor,
  /// "yetkin yok" demiyor, yani başka hesabın oturum kimliği sızmıyor.
  Future<void> revoke(String sessionId) {
    return _apiClient.delete<void>(
      ApiPaths.currentUserSession(sessionId),
      parse: (_) {},
    );
  }

  /// İsteği atan oturum **hariç** hepsini kapatır ve kaç tanesinin
  /// kapandığını döndürür.
  ///
  /// Kullanıcı bu işlemden sonra kendi cihazında açık kalıyor; "diğer
  /// cihazlardan çık" demek, kendini de atmak değil.
  Future<int> revokeOthers() {
    return _apiClient.delete<int>(
      ApiPaths.currentUserSessions,
      parse: (data) => (data as num?)?.toInt() ?? 0,
    );
  }
}
