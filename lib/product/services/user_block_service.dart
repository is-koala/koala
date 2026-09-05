import 'package:flutter/foundation.dart';
import 'package:koala/product/models/user_block.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Kullanıcı engelleme uçları.
///
/// Servis `product/` altında çünkü iki uygulama da kullanıyor: çalışan
/// sohbetteki işvereni, işveren de aday profilinden çalışanı engelleyebiliyor.
/// Uçlar hesap düzeyinde, tarafa göre değişmiyor.
///
/// Engelin sonucu **iki yönlü**: engelleyen de engellenen de artık
/// birbirine yazamıyor (`MessagingManager.java:294-298`).
class UserBlockService {
  UserBlockService._(this._apiClient);

  static final UserBlockService _instance = UserBlockService._(ApiClient());

  factory UserBlockService() => _instance;

  @visibleForTesting
  factory UserBlockService.withClient(ApiClient apiClient) {
    return UserBlockService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Sunucunun `BlockUserDto.reason` üzerindeki `@Size(max = 512)` sınırı.
  ///
  /// İstemcide de uygulanıyor: sınırı aşan gerekçe `400` ile geri dönerdi ve
  /// kullanıcı engellenmemiş olurdu — engelleme, gerekçenin uzunluğu yüzünden
  /// başarısız olmaması gereken bir işlem.
  static const int reasonLimit = 512;

  /// Bir kullanıcıyı engeller.
  ///
  /// Gövde **her hâlükârda** gönderiliyor: uç `@RequestBody @Valid` alıyor ve
  /// `required = false` demiyor, yani gerekçe boş olsa da gövdesiz istek
  /// `400` alırdı. Gerekçe yoksa gövde boş bir JSON nesnesi (`{}`) oluyor.
  ///
  /// Uç **idempotent**: aynı kişiyi ikinci kez engellemek yeni kayıt açmıyor
  /// ve hata da vermiyor (`MessagingManager.java:222-240`). Kendini
  /// engellemek `400`; arayüzde buna giden bir yol yok.
  ///
  /// [reason] isteğe bağlı ve yalnızca moderasyona kaydediliyor; karşı taraf
  /// görmüyor. Şu an hiçbir ekran doldurmuyor — engelleme sebebini
  /// moderasyona taşımak ayrı bir iş.
  Future<void> block(String userId, {String? reason}) {
    final trimmed = reason?.trim() ?? '';
    final capped = trimmed.length > reasonLimit
        ? trimmed.substring(0, reasonLimit)
        : trimmed;

    // Boş gerekçe gövdeye hiç konmuyor; `""` göndermek "yazdı ama boş
    // bıraktı" gibi kaydedilirdi. Gövdenin kendisi yine de gidiyor.
    final String? sanitized = capped.isEmpty ? null : capped;
    final body = <String, dynamic>{'reason': ?sanitized};

    return _apiClient.postWithoutData(ApiPaths.userBlock(userId), body: body);
  }

  /// Engeli kaldırır.
  ///
  /// Engellenmemiş birinin engelini kaldırmak sessizce geçiyor: sunucu kayıt
  /// yoksa da `200` döndürüyor, yani çağıranın önce listeye bakması
  /// gerekmiyor.
  Future<void> unblock(String userId) {
    return _apiClient.deleteWithoutData(ApiPaths.userBlock(userId));
  }

  /// Oturum sahibinin engellediği kullanıcılar.
  ///
  /// Uç **sayfalı değil**; sunucu düz bir `List<UserBlockDto>` döndürüyor, o
  /// yüzden sayfa parametresi de sonsuz kaydırma da yok.
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
