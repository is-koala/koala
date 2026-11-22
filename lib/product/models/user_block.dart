/// Engellenen kişinin herkese açık kimliği (`SafeUserDto`); yalnız satırı
/// çizmeye yetecek kadar.
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

  /// Sözleşmede var ama şimdilik hiçbir ekran okumuyor.
  final String? profilePictureUrl;

  /// Ad yoksa kullanıcı adı, o da yoksa yer tutucu.
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

/// Oturum sahibinin koyduğu engel; sonucu iki tarafı da bağlıyor.
class UserBlock {
  const UserBlock({
    required this.id,
    required this.blocked,
    this.reason,
    this.createdAt,
  });

  final String id;

  final BlockedUser blocked;

  /// En fazla 512 karakter; yalnız moderasyon görür.
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
