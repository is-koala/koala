/// Engellenen kişinin herkese açık kimliği. Backend `SafeUserDto` karşılığı.
///
/// Projede bu sözleşmenin karşılığı olan bir model yoktu: [PublicProfile] çok
/// daha geniş (meslek, konum, özgeçmiş) ve `GET /users/{id}` üzerinden
/// geliyor. Engel listesi bunların hiçbirini döndürmüyor — yalnızca satırı
/// çizmeye yetecek kadarını.
class BlockedUser {
  const BlockedUser({
    required this.id,
    this.firstName,
    this.lastName,
    this.username,
    this.profilePictureUrl,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? username;

  /// Profil görseli. Sözleşmede var; "Engellediklerim" listesi satırı
  /// [SessionView] ve [ReportView] ile aynı ikon kutusuyla çizdiği için
  /// şimdilik hiçbir ekran okumuyor.
  final String? profilePictureUrl;

  /// Satırda görünen ad.
  ///
  /// Ad ve soyad gelmeyebiliyor (kimliği doğrulanmamış hesap); o durumda
  /// kullanıcı adı gösteriliyor. Hiçbiri yoksa satır boş kalmasın diye yer
  /// tutucu yazılıyor — kullanıcı kimi engellediğini en azından tarihten
  /// çıkarabilmeli.
  String get displayName {
    final fullName = [
      ?firstName,
      ?lastName,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');

    if (fullName.isNotEmpty) return fullName;

    final username = this.username?.trim();
    if (username != null && username.isNotEmpty) return '@$username';

    return 'Kullanıcı';
  }

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: '${json['id']}',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      username: json['username'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
    );
  }
}

/// Oturum sahibinin koyduğu tek bir engel. Backend `UserBlockDto` karşılığı.
///
/// Engel **iki yönlü**: kayıt yalnızca engelleyenin listesinde duruyor ama
/// sonucu iki tarafı da bağlıyor — engellenen kişi de artık yazamıyor
/// (`MessagingManager.java:294-298`).
class UserBlock {
  const UserBlock({
    required this.id,
    required this.blocked,
    this.reason,
    this.createdAt,
  });

  final String id;

  /// Engellenen kişi.
  final BlockedUser blocked;

  /// Engelleme gerekçesi; isteğe bağlı, sunucuda en fazla 512 karakter.
  ///
  /// Yalnızca moderasyon için tutuluyor, karşı taraf görmüyor.
  final String? reason;

  final DateTime? createdAt;

  factory UserBlock.fromJson(Map<String, dynamic> json) {
    final blocked = json['blocked'];

    return UserBlock(
      id: '${json['id']}',
      blocked: BlockedUser.fromJson(
        blocked is Map<String, dynamic> ? blocked : const {},
      ),
      reason: json['reason'] as String?,
      createdAt: switch (json['createdAt']) {
        final String text => DateTime.tryParse(text),
        _ => null,
      },
    );
  }
}
