/// Bir kullanıcının çevrimiçi durumu.
///
/// `GET /users/{userId}/presence` ve toplu `POST /presence/lookup` yanıtındaki
/// `PresenceDto` karşılığı. Sohbet listesi tek tek sormak yerine toplu ucu
/// kullanıyor.
class Presence {
  const Presence({required this.userId, this.online = false, this.lastSeenAt});

  final String userId;
  final bool online;
  final DateTime? lastSeenAt;

  factory Presence.fromJson(Map<String, dynamic> json) {
    final lastSeenAt = json['lastSeenAt'];

    return Presence(
      userId: '${json['userId']}',
      online: json['online'] as bool? ?? false,
      lastSeenAt: lastSeenAt is String ? DateTime.tryParse(lastSeenAt) : null,
    );
  }
}
