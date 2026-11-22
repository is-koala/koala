import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/json_field.dart';

/// Tek oturumun ayrıntısı; ortak alanlar [session]'da. Eski sunucu ucu
/// tanımıyor, o zaman bu model kurulmaz.
class SessionDetail {
  const SessionDetail({
    required this.session,
    this.deviceCustomName,
    this.createdAt,
    this.logins = 0,
    this.loginHistory = const [],
  });

  final UserSession session;

  /// Kullanıcının verdiği ad; yoksa `null`. [UserSession.deviceName] türetilmiş
  /// adı taşıyor, onu kutuya koymak "bunu siz yazdınız" derdi.
  final String? deviceCustomName;

  final DateTime? createdAt;

  final int logins;

  /// Yeniden eskiye, en çok 20.
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

  /// Yanlış parola denemeleri de listede, kullanıcı hesabına kimin dokunduğunu
  /// görsün.
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
