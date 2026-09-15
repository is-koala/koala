import 'package:koala/product/models/user_session.dart';

/// Tek bir oturumun ayrıntısı. Backend `SessionDetailDto` karşılığı
/// (koala-backend#306, 0.9.28).
///
/// Listedeki [UserSession]'dan fazlası: oluşturulma anı, toplam giriş sayısı
/// ve son girişlerin geçmişi. Eski sunucu bu ucu tanımıyor (`404`); o hâlde
/// liste satırı hiç açılmıyor, bu model kurulmuyor.
class SessionDetail {
  const SessionDetail({
    required this.id,
    required this.deviceType,
    required this.isCurrent,
    this.deviceId,
    this.deviceName,
    this.deviceCustomName,
    this.ipAddress,
    this.location,
    this.createdAt,
    this.lastAccessedAt,
    this.refreshExpiresAt,
    this.logins = 0,
    this.loginHistory = const [],
  });

  final String id;

  /// Cihazın kimliği; adlandırma bu kimlikle yapılıyor
  /// (`PATCH /users/me/devices/{deviceId}`). Sunucu vermezse adlandırılamaz.
  final String? deviceId;

  final SessionDeviceType deviceType;

  /// Sunucunun gösterdiği ad: kullanıcı ad verdiyse o, vermediyse
  /// başlıklardan türetilen gerçek ad.
  final String? deviceName;

  /// Kullanıcının verdiği özel ad; yoksa `null`. Adlandırma kutusunu
  /// doldurmak için ayrı tutuluyor — [deviceName] özel ad yokken türetilmiş
  /// adı taşıyor, onu kutuya koymak kullanıcıya "bunu siz yazdınız" derdi.
  final String? deviceCustomName;

  final String? ipAddress;

  /// Sunucunun IP'den çıkardığı yaklaşık yer (`İstanbul, TR`). Boş
  /// gelebiliyor.
  final String? location;

  final DateTime? createdAt;
  final DateTime? lastAccessedAt;
  final DateTime? refreshExpiresAt;

  /// Bu cihazdan yapılan toplam giriş sayısı.
  final int logins;

  /// Son girişler, yeniden eskiye (sunucu en çok 20 tane veriyor).
  final List<LoginHistoryEntry> loginHistory;

  final bool isCurrent;

  /// Ekranda gösterilecek ad; sunucu ad vermezse cihaz türü.
  String get displayName {
    final name = deviceName;
    return name != null && name.trim().isNotEmpty
        ? name
        : deviceType.displayName;
  }

  factory SessionDetail.fromJson(Map<String, dynamic> json) {
    final history = json['loginHistory'];

    return SessionDetail(
      id: '${json['id']}',
      deviceId: json['deviceId'] as String?,
      deviceType: SessionDeviceType.fromCode(json['deviceType']),
      deviceName: json['deviceName'] as String?,
      deviceCustomName: json['deviceCustomName'] as String?,
      ipAddress: json['ipAddress'] as String?,
      location: json['location'] as String?,
      createdAt: _parseDate(json['createdAt']),
      lastAccessedAt: _parseDate(json['lastAccessedAt']),
      refreshExpiresAt: _parseDate(json['refreshExpiresAt']),
      logins: (json['logins'] as num?)?.toInt() ?? 0,
      loginHistory: history is List
          ? history
                .whereType<Map<String, dynamic>>()
                .map(LoginHistoryEntry.fromJson)
                .toList()
          : const [],
      isCurrent: json['current'] as bool? ?? false,
    );
  }

  static DateTime? _parseDate(Object? value) {
    return switch (value) {
      final String text => DateTime.tryParse(text),
      _ => null,
    };
  }
}

/// Giriş geçmişindeki tek satır. Backend `LoginHistoryEntryDto` karşılığı.
class LoginHistoryEntry {
  const LoginHistoryEntry({
    required this.successful,
    this.at,
    this.ipAddress,
    this.location,
  });

  final DateTime? at;
  final String? ipAddress;
  final String? location;

  /// Giriş başarılı mıydı. Sunucu alanı `success` diye yazıyor; yanlış
  /// parola denemeleri de listede, kullanıcı hesabına kimin dokunduğunu
  /// görsün diye.
  final bool successful;

  factory LoginHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LoginHistoryEntry(
      at: SessionDetail._parseDate(json['at']),
      ipAddress: json['ipAddress'] as String?,
      location: json['location'] as String?,
      successful: json['success'] as bool? ?? false,
    );
  }
}
