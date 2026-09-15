import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/json_field.dart';

/// Tek bir oturumun ayrıntısı. Backend `SessionDetailDto` karşılığı
/// (koala-backend#306, 0.9.28).
///
/// Listedeki [UserSession]'ın üstüne eklenenler: oluşturulma anı, kullanıcının
/// verdiği özel ad, toplam giriş sayısı ve son girişlerin geçmişi. Ortak
/// alanlar [session]'da duruyor — ayrıntı DTO'su liste DTO'sunun bir üst
/// kümesi, aynı sekiz alan ikinci kez okunmuyor. Eski sunucu bu ucu
/// tanımıyor (`404`); o hâlde liste satırı hiç açılmıyor, bu model
/// kurulmuyor.
class SessionDetail {
  const SessionDetail({
    required this.session,
    this.deviceCustomName,
    this.createdAt,
    this.logins = 0,
    this.loginHistory = const [],
  });

  /// Listedeki satırla aynı alanlar: kimlik, cihaz, IP, konum, zamanlar,
  /// "bu cihaz" bayrağı ve görünen ad.
  final UserSession session;

  /// Kullanıcının verdiği özel ad; yoksa `null`. Adlandırma kutusunu
  /// doldurmak için ayrı tutuluyor — [UserSession.deviceName] özel ad yokken
  /// türetilmiş adı taşıyor, onu kutuya koymak kullanıcıya "bunu siz
  /// yazdınız" derdi.
  final String? deviceCustomName;

  final DateTime? createdAt;

  /// Bu cihazdan yapılan toplam giriş sayısı.
  final int logins;

  /// Son girişler, yeniden eskiye (sunucu en çok 20 tane veriyor).
  final List<LoginHistoryEntry> loginHistory;

  factory SessionDetail.fromJson(Map<String, dynamic> json) {
    final history = json['loginHistory'];

    return SessionDetail(
      session: UserSession.fromJson(json),
      deviceCustomName: json['deviceCustomName'] as String?,
      createdAt: JsonField.dateOrNull(json['createdAt']),
      logins: (json['logins'] as num?)?.toInt() ?? 0,
      loginHistory: history is List
          ? history
                .whereType<Map<String, dynamic>>()
                .map(LoginHistoryEntry.fromJson)
                .toList()
          : const [],
    );
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
      at: JsonField.dateOrNull(json['at']),
      ipAddress: json['ipAddress'] as String?,
      location: json['location'] as String?,
      successful: json['success'] as bool? ?? false,
    );
  }
}
