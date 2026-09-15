import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/network/json_field.dart';

/// Oturumun açıldığı cihazın türü. Backend `DeviceType` karşılığı.
enum SessionDeviceType {
  ios('IOS', 'iPhone'),
  android('ANDROID', 'Android'),
  webBrowser('WEB_BROWSER', 'Tarayıcı'),
  other('OTHER', 'Diğer'),
  unknown('UNKNOWN', 'Bilinmeyen cihaz');

  const SessionDeviceType(this.code, this.displayName);

  final String code;
  final String displayName;

  static SessionDeviceType fromCode(Object? value) {
    return SessionDeviceType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => SessionDeviceType.unknown,
    );
  }
}

/// Cihaz türünün görsel karşılığı; liste satırı ve ayrıntı sayfası aynı
/// ikonu çiziyor (`JobCategoryStyle` kalıbı).
extension SessionDeviceTypeStyle on SessionDeviceType {
  AppIconData get icon => switch (this) {
    SessionDeviceType.ios || SessionDeviceType.android => AppIcons.mobile,
    SessionDeviceType.webBrowser => AppIcons.globe,
    SessionDeviceType.other || SessionDeviceType.unknown => AppIcons.shield,
  };
}

/// Hesaba açık bir oturum. Backend `SessionDto` karşılığı.
///
/// Mesai oturumuyla (`WorkSession`) karıştırılmasın: bu, kullanıcının
/// giriş yaptığı cihaz.
class UserSession {
  const UserSession({
    required this.id,
    required this.deviceType,
    required this.isCurrent,
    this.deviceId,
    this.deviceName,
    this.ipAddress,
    this.location,
    this.lastAccessedAt,
    this.refreshExpiresAt,
  });

  final String id;
  final String? deviceId;
  final SessionDeviceType deviceType;
  final String? deviceName;
  final String? ipAddress;

  /// Sunucunun IP'den çıkardığı yer. Boş gelebiliyor.
  final String? location;

  final DateTime? lastAccessedAt;
  final DateTime? refreshExpiresAt;

  /// İsteği atan oturum. Sunucu işaretliyor; kullanıcının kendi cihazını
  /// yanlışlıkla kapatmaması bu bayrağa bağlı.
  final bool isCurrent;

  /// Listede gösterilecek cihaz adı. Sunucu adı vermezse cihaz türü
  /// yazılıyor — boş satır bırakmaktan iyi.
  String get displayName {
    final name = deviceName;
    return name != null && name.trim().isNotEmpty
        ? name
        : deviceType.displayName;
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: '${json['id']}',
      deviceId: json['deviceId'] as String?,
      deviceType: SessionDeviceType.fromCode(json['deviceType']),
      deviceName: json['deviceName'] as String?,
      ipAddress: json['ipAddress'] as String?,
      location: json['location'] as String?,
      lastAccessedAt: JsonField.dateOrNull(json['lastAccessedAt']),
      refreshExpiresAt: JsonField.dateOrNull(json['refreshExpiresAt']),
      isCurrent: json['current'] as bool? ?? false,
    );
  }
}
