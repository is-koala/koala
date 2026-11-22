import 'package:koala/employee/features/chat/models/chat_participant.dart';

enum ConversationKind {
  direct('DIRECT'),

  /// İlanın ekip sohbeti; ödemeyle kurulur, iş bitiminden 7 gün sonra kapanır.
  group('GROUP');

  const ConversationKind(this.code);

  final String code;

  /// Eksik değer [direct]: eski sunucunun bütün sohbetleri ikili.
  static ConversationKind fromCode(Object? value) {
    for (final kind in values) {
      if (kind.code == value) return kind;
    }
    return direct;
  }
}

/// İlana bağlı sohbet. Şirket üzerinden, ilandan bağımsız sohbet sunucuda yok.
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
    this.kind = ConversationKind.direct,
    this.participants = const [],
    this.closed = false,
  });

  final String id;

  final String jobId;

  final String jobTitle;

  final String counterpartId;

  final String name;

  final String avatar;

  final String? avatarUrl;

  final DateTime? lastMessageAt;

  /// Sunucu denormalize tutuyor; satır başına istek yok.
  final String? lastMessage;

  final int unreadCount;

  /// Presence ayrı uçtan toplu çekilip [copyWith] ile birleşiyor.
  final bool isOnline;

  final ConversationKind kind;

  /// Katılımcılar, ayrılanlar dâhil; gönderen adı ve "kimler gördü" buradan.
  final List<ChatParticipant> participants;

  /// Ayrılanlar hariç; listeden türetiliyor ki `copyWith` bayat bırakmasın.
  /// İkilide `0`.
  int get participantCount =>
      participants.where((participant) => !participant.left).length;

  /// Salt okunur mu (iptal/ret/iade ya da 7 gün geçti); gönderim `409`.
  final bool closed;

  bool get isGroup => kind == ConversationKind.group;

  String get participantLabel => '$participantCount katılımcı';

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

  /// `ConversationDto`'yu çevirir. Karşı taraf [currentUserId] olmayan taraf.
  /// **Grupta karşı taraf yok**: satır ilan başlığıyla çizilir; presence ve
  /// engel de kişiye bağlı, grupta yok.
  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final kind = ConversationKind.fromCode(json['kind']);
    final jobTitle = json['jobTitle'] as String? ?? '';
    final participants = json['participants'];
    final lastMessageAt = json['lastMessageAt'] as String?;

    final employer = json['employer'] as Map<String, dynamic>?;
    final worker = json['worker'] as Map<String, dynamic>?;
    final counterpart = kind == ConversationKind.group
        ? null
        : employer?['id'] == currentUserId
        ? worker
        : employer;

    final firstName = counterpart?['firstName'] as String? ?? '';
    final lastName = counterpart?['lastName'] as String? ?? '';
    final name = kind == ConversationKind.group
        ? jobTitle
        : '$firstName $lastName'.trim();

    return Conversation(
      id: '${json['id']}',
      jobId: json['jobId'] as String? ?? '',
      jobTitle: jobTitle,
      counterpartId: counterpart?['id'] == null ? '' : '${counterpart!['id']}',
      name: name,
      avatar: initialsOf(name),
      avatarUrl: counterpart?['profilePictureUrl'] as String?,
      lastMessageAt: lastMessageAt == null
          ? null
          : DateTime.tryParse(lastMessageAt),
      lastMessage: json['lastMessageBody'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      kind: kind,
      participants: participants is List
          ? participants
                .whereType<Map<String, dynamic>>()
                .map(ChatParticipant.fromJson)
                .toList()
          : const [],
      closed: json['closed'] == true,
    );
  }

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
    ConversationKind? kind,
    List<ChatParticipant>? participants,
    bool? closed,
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
      kind: kind ?? this.kind,
      participants: participants ?? this.participants,
      closed: closed ?? this.closed,
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
      'kind': kind.code,
      'participantCount': participantCount,
      'participants': [for (final p in participants) p.toJson()],
      'closed': closed,
    };
  }
}
