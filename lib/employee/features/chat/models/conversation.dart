/// Bir ilan üzerinden yürüyen sohbet.
///
/// Backend'deki `ConversationDto`'nun karşılığı. Sohbet **ilana bağlı**:
/// `POST /conversations/jobs/{jobId}` ile açılıyor ve tarafları işveren ile
/// çalışan olarak sabit. Şirket üzerinden, ilandan bağımsız bir sohbet
/// kavramı sunucuda yok.
class Conversation {
  const Conversation({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.counterpartId,
    required this.name,
    required this.avatar,
    this.avatarUrl,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  final String id;

  /// Sohbetin açıldığı ilan.
  final String jobId;

  final String jobTitle;

  /// Karşı tarafın kullanıcı kimliği. Sohbette iki taraf var; oturumu açan
  /// kullanıcı hangisiyse diğeri karşı taraf oluyor.
  final String counterpartId;

  /// Karşı tarafın görünen adı.
  final String name;

  /// Görsel yoksa gösterilen baş harfler.
  final String avatar;

  final String? avatarUrl;

  final DateTime? lastMessageAt;

  /// Son mesajın metni. Sunucu bunu `ConversationDto` üzerinde denormalize
  /// tutuyor, yani liste satır başına ekstra istek atmıyor.
  final String? lastMessage;

  /// Okunmamış mesaj sayısı; sunucudan hazır geliyor.
  final int unreadCount;

  /// Karşı taraf çevrimiçi mi.
  ///
  /// `ConversationDto` bunu taşımıyor: presence ayrı bir uçtan
  /// (`POST /presence/lookup`) toplu olarak çekilip [copyWith] ile
  /// birleştiriliyor.
  final bool isOnline;

  /// Sohbet listesinde sağda görünen zaman etiketi.
  String get timeString {
    final lastMessageAt = this.lastMessageAt;
    if (lastMessageAt == null) return '';

    final difference = DateTime.now().difference(lastMessageAt);

    if (difference.inDays == 0) {
      final hour = lastMessageAt.hour.toString().padLeft(2, '0');
      final minute = lastMessageAt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (difference.inDays == 1) return 'Dün';
    if (difference.inDays < 7) return '${difference.inDays} gün önce';

    return '${lastMessageAt.day}/${lastMessageAt.month}/${lastMessageAt.year}';
  }

  /// `ConversationDto`'yu modele çevirir.
  ///
  /// Karşı taraf sunucudan hazır gelmiyor: iki katılımcıdan hangisi
  /// [currentUserId] değilse o alınıyor.
  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final employer = json['employer'] as Map<String, dynamic>?;
    final worker = json['worker'] as Map<String, dynamic>?;
    final counterpart = employer?['id'] == currentUserId ? worker : employer;

    final firstName = counterpart?['firstName'] as String? ?? '';
    final lastName = counterpart?['lastName'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    final lastMessageAt = json['lastMessageAt'] as String?;

    return Conversation(
      id: '${json['id']}',
      jobId: json['jobId'] as String? ?? '',
      jobTitle: json['jobTitle'] as String? ?? '',
      counterpartId: counterpart?['id'] == null ? '' : '${counterpart!['id']}',
      name: name,
      avatar: initialsOf(name),
      avatarUrl: counterpart?['profilePictureUrl'] as String?,
      lastMessageAt: lastMessageAt == null
          ? null
          : DateTime.tryParse(lastMessageAt),
      lastMessage: json['lastMessageBody'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Görsel yokken gösterilecek baş harf(ler).
  static String initialsOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Conversation copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? counterpartId,
    String? name,
    String? avatar,
    String? avatarUrl,
    DateTime? lastMessageAt,
    String? lastMessage,
    int? unreadCount,
    bool? isOnline,
  }) {
    return Conversation(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      counterpartId: counterpartId ?? this.counterpartId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'counterpartId': counterpartId,
      'name': name,
      'avatar': avatar,
      'avatarUrl': avatarUrl,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'isOnline': isOnline,
    };
  }
}
